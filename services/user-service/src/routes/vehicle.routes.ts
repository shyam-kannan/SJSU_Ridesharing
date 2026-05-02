import express, { Request, Response } from 'express';
import axios from 'axios';

const router = express.Router();

// ── In-memory cache ───────────────────────────────────────────────────────────

interface CacheEntry<T> {
  data: T;
  expiresAt: number;
}

const cache = new Map<string, CacheEntry<unknown>>();
const CACHE_TTL_MS = 24 * 60 * 60 * 1000; // 24 hours

function getCache<T>(key: string): T | null {
  const entry = cache.get(key);
  if (!entry || Date.now() > entry.expiresAt) {
    cache.delete(key);
    return null;
  }
  return entry.data as T;
}

function setCache<T>(key: string, data: T): void {
  cache.set(key, { data, expiresAt: Date.now() + CACHE_TTL_MS });
}

// ── In-memory rate limiter: 30 req / minute / IP ──────────────────────────────

const rateLimitMap = new Map<string, { count: number; resetAt: number }>();
const RATE_WINDOW_MS = 60_000;
const RATE_MAX = 30;

function rateLimiter(req: Request, res: Response, next: express.NextFunction): void {
  const ip =
    (req.headers['x-forwarded-for'] as string | undefined)?.split(',')[0].trim() ??
    req.ip ??
    'unknown';

  const now = Date.now();
  let entry = rateLimitMap.get(ip);
  if (!entry || now > entry.resetAt) {
    entry = { count: 0, resetAt: now + RATE_WINDOW_MS };
    rateLimitMap.set(ip, entry);
  }
  entry.count += 1;

  if (entry.count > RATE_MAX) {
    res.status(429).json({ status: 'error', message: 'Too many requests, please try again later' });
    return;
  }
  next();
}

// ── External API base URLs ────────────────────────────────────────────────────

const NHTSA_BASE = 'https://vpic.nhtsa.dot.gov/api/vehicles';
const DOE_BASE   = 'https://www.fueleconomy.gov/ws/rest';
const WIKIPEDIA_API = 'https://en.wikipedia.org/w/api.php';

// ── Title-case helper (converts "HONDA" → "Honda", "GENERAL MOTORS" → "General Motors") ──

function toTitleCase(str: string): string {
  return str.toLowerCase().replace(/\b\w/g, (c) => c.toUpperCase());
}

// ── Seating inference (NHTSA does not reliably expose seats by make/model without VIN) ──

const SEATING_MAP: Record<string, number> = {
  // Full-size SUVs / vans (8-9)
  suburban: 9, tahoe: 9, yukon: 9, sequoia: 8, expedition: 8, navigator: 8,
  armada: 8, sienna: 8, odyssey: 8, pacifica: 7, carnival: 8,
  // Mid-size SUVs (7)
  highlander: 7, pilot: 8, pathfinder: 7, '4runner': 7, explorer: 7,
  traverse: 7, enclave: 7, acadia: 7, durango: 7, ascent: 7,
  // Crossovers / compact SUVs (5)
  rav4: 5, 'cr-v': 5, crv: 5, rogue: 5, escape: 5, equinox: 5,
  tiguan: 5, 'cx-5': 5, cx5: 5, forester: 5, outback: 5, tucson: 5,
  sportage: 5, hrv: 5, 'hr-v': 5, qashqai: 5, juke: 5, kicks: 5,
  compass: 5, cherokee: 5, trailblazer: 5, trax: 5, encore: 5,
  // Sedans (5)
  camry: 5, accord: 5, civic: 5, corolla: 5, altima: 5, sentra: 5,
  malibu: 5, fusion: 5, sonata: 5, elantra: 5, jetta: 5, passat: 5,
  optima: 5, k5: 5, forte: 5, legacy: 5, impreza: 5, mazda3: 5,
  model3: 5, 'model 3': 5, models: 5, 'model s': 5,
  // Sports / coupes (4)
  mustang: 4, camaro: 4, challenger: 4, '86': 4, brz: 4, supra: 4,
  // 2-seaters
  corvette: 2, miata: 2, 'mx-5': 2, mx5: 2, boxster: 2, cayman: 2,
  viper: 2, solstice: 2, sky: 2,
  // Pickups (5 seats — crew cab default)
  'f-150': 5, f150: 5, silverado: 5, 'ram 1500': 5, ram1500: 5,
  tacoma: 5, tundra: 5, ranger: 5, colorado: 5, ridgeline: 5,
  frontier: 5, titan: 5, maverick: 5,
};

function inferSeats(model: string): number {
  const key = model.toLowerCase().trim();
  if (SEATING_MAP[key] !== undefined) return SEATING_MAP[key];

  // Keyword inference for unlisted models
  if (/suburban|expedition|sequoia|armada|navigator|tahoe|yukon/i.test(key)) return 8;
  if (/highlander|pilot|pathfinder|4runner|explorer|traverse|odyssey|sienna|pacifica|carnival/i.test(key)) return 7;
  if (/corvette|miata|mx-5|boxster|cayman|viper|solstice/i.test(key)) return 2;
  if (/mustang|camaro|challenger|86|brz|supra/i.test(key)) return 4;

  return 5; // Default: standard sedan/crossover
}

// ── GET /vehicles/makes ───────────────────────────────────────────────────────
// Returns deduplicated, sorted list of makes that have passenger car or MPV models.
// Calls NHTSA GetMakesForVehicleType for both types and merges results.
// Response cached 24h.

router.get('/makes', rateLimiter, async (req: Request, res: Response) => {
  const cacheKey = 'makes_v1';
  const cached = getCache<string[]>(cacheKey);
  if (cached) {
    return res.json({ makes: cached });
  }

  try {
    const [passengerResp, mpvResp] = await Promise.allSettled([
      axios.get(`${NHTSA_BASE}/GetMakesForVehicleType/Passenger%20Car?format=json`, { timeout: 10_000 }),
      axios.get(`${NHTSA_BASE}/GetMakesForVehicleType/Multipurpose%20Passenger%20Vehicle%20(MPV)?format=json`, { timeout: 10_000 }),
    ]);

    const makeSet = new Set<string>();

    for (const result of [passengerResp, mpvResp]) {
      if (result.status === 'fulfilled') {
        const results: Array<{ MakeName: string }> = result.value.data?.Results ?? [];
        for (const r of results) {
          const name = r.MakeName?.trim();
          // NHTSA returns ALL CAPS ("HONDA") — convert to title case for display
          if (name) makeSet.add(toTitleCase(name));
        }
      }
    }

    if (makeSet.size === 0) {
      return res.status(502).json({ status: 'error', message: 'Vehicle make lookup unavailable' });
    }

    const makes = Array.from(makeSet).sort((a, b) => a.localeCompare(b));
    setCache(cacheKey, makes);
    return res.json({ makes });
  } catch (err) {
    console.error('[vehicles/makes] Error:', (err as Error).message);
    return res.status(502).json({ status: 'error', message: 'Vehicle make lookup unavailable' });
  }
});

// ── GET /vehicles/models?make=Toyota&year=2022 ────────────────────────────────
// Returns sorted list of model names for a given make and year.
// Response cached 24h per make+year.

router.get('/models', rateLimiter, async (req: Request, res: Response) => {
  const { make, year } = req.query as { make?: string; year?: string };

  if (!make || !year) {
    return res.status(400).json({ status: 'error', message: 'make and year are required' });
  }

  const yearNum = parseInt(year, 10);
  if (isNaN(yearNum) || yearNum < 1980 || yearNum > new Date().getFullYear() + 1) {
    return res.status(400).json({ status: 'error', message: 'Invalid year' });
  }

  const cacheKey = `models_${make.toLowerCase()}_${yearNum}`;
  const cached = getCache<string[]>(cacheKey);
  if (cached) {
    return res.json({ models: cached });
  }

  try {
    const url = `${NHTSA_BASE}/getmodelsformakeyear/make/${encodeURIComponent(make)}/modelyear/${yearNum}?format=json`;
    const response = await axios.get(url, { timeout: 10_000 });
    const results: Array<{ Model_Name: string }> = response.data?.Results ?? [];

    const models = Array.from(
      new Set(results.map((r) => r.Model_Name?.trim()).filter(Boolean))
    ).sort((a, b) => a.localeCompare(b)) as string[];

    if (models.length === 0) {
      // Return empty gracefully — iOS will show "no models found"
      return res.json({ models: [] });
    }

    setCache(cacheKey, models);
    return res.json({ models });
  } catch (err) {
    console.error('[vehicles/models] Error:', (err as Error).message);
    return res.status(502).json({ status: 'error', message: 'Vehicle model lookup unavailable' });
  }
});

// ── GET /vehicles/specs?make=Toyota&model=Camry&year=2022 ─────────────────────
// Fetches MPG data from DOE Fuel Economy API and infers seating from lookup table.
// Returns trim list with city/highway/combined MPG plus default values.
// Response cached 24h per make+model+year.

router.get('/specs', rateLimiter, async (req: Request, res: Response) => {
  const { make, model, year } = req.query as { make?: string; model?: string; year?: string };

  if (!make || !model || !year) {
    return res.status(400).json({ status: 'error', message: 'make, model, and year are required' });
  }

  const yearNum = parseInt(year, 10);
  if (isNaN(yearNum)) {
    return res.status(400).json({ status: 'error', message: 'Invalid year' });
  }

  const cacheKey = `specs_${make.toLowerCase()}_${model.toLowerCase()}_${yearNum}`;
  const cached = getCache<unknown>(cacheKey);
  if (cached) {
    return res.json(cached);
  }

  // ── Step 1: Fetch trim options from DOE ──────────────────────────────────────
  let trims: Array<{
    id: string;
    trim_name: string;
    city_mpg: number | null;
    highway_mpg: number | null;
    combined_mpg: number | null;
  }> = [];
  let mpg_source: 'doe' | 'unavailable' = 'unavailable';

  try {
    // DOE API expects title-case make ("Honda", not "HONDA" or "honda")
    const doeMake = toTitleCase(make);
    const doeModel = toTitleCase(model);
    const optionsUrl = `${DOE_BASE}/vehicle/menu/options?year=${yearNum}&make=${encodeURIComponent(doeMake)}&model=${encodeURIComponent(doeModel)}`;
    const optionsResp = await axios.get(optionsUrl, {
      timeout: 10_000,
      headers: { Accept: 'application/json' },
    });

    // DOE returns { menuItem: [...] } or { menuItem: {} } (single item not in array)
    const raw = optionsResp.data;
    let items: Array<{ value: string; text: string }> = [];
    if (raw?.menuItem) {
      items = Array.isArray(raw.menuItem) ? raw.menuItem : [raw.menuItem];
    }

    if (items.length > 0) {
      // ── Step 2: Fetch MPG details for each trim (parallel, max 6) ─────────────
      const limited = items.slice(0, 6);
      const detailResults = await Promise.allSettled(
        limited.map(async (item) => {
          const detailResp = await axios.get(`${DOE_BASE}/vehicle/${item.value}`, {
            timeout: 10_000,
            headers: { Accept: 'application/json' },
          });
          const d = detailResp.data;
          const combinedMpg = Number(d.comb08) || null;
          return {
            id: String(item.value),
            trim_name: item.text,
            city_mpg:     Number(d.city08)    || null,
            highway_mpg:  Number(d.highway08) || null,
            combined_mpg: combinedMpg,
          };
        })
      );

      trims = detailResults
        .filter((r): r is PromiseFulfilledResult<typeof trims[0]> => r.status === 'fulfilled')
        .map((r) => r.value)
        .filter((t) => t.combined_mpg !== null);

      if (trims.length > 0) mpg_source = 'doe';
    }
  } catch (err) {
    console.warn('[vehicles/specs] DOE API error:', (err as Error).message);
  }

  // ── Step 3: Compute default_mpg as average across trims ──────────────────────
  const default_mpg: number | null =
    trims.length > 0
      ? Math.round(
          trims.reduce((sum, t) => sum + (t.combined_mpg ?? 0), 0) / trims.length
        )
      : null;

  // ── Step 4: Seating from inference table ────────────────────────────────────
  const seating_capacity = inferSeats(model);

  const result = {
    make,
    model,
    year: yearNum,
    seating_capacity,
    trims,
    default_mpg,
    default_seats: seating_capacity,
    mpg_source,
  };

  // Cache only if we have good data (don't cache empty/error states)
  if (trims.length > 0 || mpg_source === 'unavailable') {
    setCache(cacheKey, result);
  }

  return res.json(result);
});

// ── GET /vehicles/photo?make=Honda&model=Civic+Si&year=2024 ──────────────────
// Fetches a representative vehicle photo from Wikipedia.
// Tries 3 progressive search strategies; returns { photo_url: string | null }.
// Cached 24h per make+model+year.

async function wikipediaThumbnail(title: string): Promise<string | null> {
  try {
    const url = `${WIKIPEDIA_API}?action=query&titles=${encodeURIComponent(title)}&prop=pageimages&format=json&pithumbsize=600`;
    const resp = await axios.get(url, { timeout: 8_000, headers: { 'User-Agent': 'LessGoApp/1.0' } });
    const pages = resp.data?.query?.pages ?? {};
    for (const page of Object.values(pages) as any[]) {
      if (page.thumbnail?.source) return page.thumbnail.source as string;
    }
  } catch {
    // fall through to next attempt
  }
  return null;
}

async function wikipediaSearch(query: string): Promise<string | null> {
  try {
    const searchUrl = `${WIKIPEDIA_API}?action=query&list=search&srsearch=${encodeURIComponent(query)}&format=json&srlimit=1`;
    const searchResp = await axios.get(searchUrl, { timeout: 8_000, headers: { 'User-Agent': 'LessGoApp/1.0' } });
    const hits: Array<{ title: string }> = searchResp.data?.query?.search ?? [];
    if (hits.length === 0) return null;
    return await wikipediaThumbnail(hits[0].title);
  } catch {
    return null;
  }
}

router.get('/photo', rateLimiter, async (req: Request, res: Response) => {
  const { make, model, year } = req.query as { make?: string; model?: string; year?: string };

  if (!make || !model) {
    return res.status(400).json({ status: 'error', message: 'make and model are required' });
  }

  const cacheKey = `photo_${(make + model + (year ?? '')).toLowerCase().replace(/\s+/g, '_')}`;
  const cached = getCache<{ photo_url: string | null }>(cacheKey);
  if (cached) return res.json(cached);

  const titleMake  = toTitleCase(make);
  const titleModel = toTitleCase(model);
  const yearStr    = year ?? '';

  // Attempt 1: "{year} {make} {model}" exact page
  let photoUrl: string | null = null;
  if (yearStr) {
    photoUrl = await wikipediaThumbnail(`${yearStr} ${titleMake} ${titleModel}`);
  }

  // Attempt 2: "{make} {model}" exact page
  if (!photoUrl) {
    photoUrl = await wikipediaThumbnail(`${titleMake} ${titleModel}`);
  }

  // Attempt 3: search "{make} {model} car"
  if (!photoUrl) {
    photoUrl = await wikipediaSearch(`${titleMake} ${titleModel} car`);
  }

  const result = { photo_url: photoUrl };
  setCache(cacheKey, result);
  return res.json(result);
});

export default router;
