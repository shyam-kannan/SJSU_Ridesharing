import { Client } from 'pg';

function fail(message, details) {
  console.error(`DB CHECK FAILED: ${message}`);
  if (details) {
    console.error(details);
  }
  process.exit(1);
}

const connectionString = process.env.DATABASE_URL;
if (!connectionString) {
  fail('DATABASE_URL is not set. Export it before running this check.');
}

let parsed;
try {
  parsed = new URL(connectionString);
} catch (error) {
  fail('DATABASE_URL is not a valid URL.', error.message);
}

const hostname = parsed.hostname || '';
const isLocal = hostname === 'localhost' || hostname === '127.0.0.1';

const client = new Client({
  connectionString,
  // Supabase Postgres typically requires SSL; local Postgres usually does not.
  ssl: isLocal ? false : { rejectUnauthorized: false },
});

const requiredTables = [
  'users',
  'trips',
  'bookings',
  'payments',
  'ratings',
];

async function main() {
  const startedAt = Date.now();

  try {
    await client.connect();

    const ping = await client.query('SELECT NOW() AS now, current_database() AS db, current_user AS usr');
    const pingRow = ping.rows[0];

    const tableCheck = await client.query(
      `
      SELECT table_name
      FROM information_schema.tables
      WHERE table_schema = 'public'
      AND table_name = ANY($1::text[])
      ORDER BY table_name
      `,
      [requiredTables]
    );

    const existing = new Set(tableCheck.rows.map((r) => r.table_name));
    const missing = requiredTables.filter((t) => !existing.has(t));

    console.log('DB CHECK PASSED');
    console.log(`- Host: ${hostname}`);
    console.log(`- Database: ${pingRow.db}`);
    console.log(`- User: ${pingRow.usr}`);
    console.log(`- Server time: ${pingRow.now}`);
    console.log(`- Required tables present: ${requiredTables.length - missing.length}/${requiredTables.length}`);

    if (missing.length > 0) {
      console.warn(`- Missing tables: ${missing.join(', ')}`);
      console.warn('- If this is a fresh environment, run migrations.');
    }

    console.log(`- Duration: ${Date.now() - startedAt}ms`);
  } catch (error) {
    fail('Could not connect/query Postgres.', error.message);
  } finally {
    await client.end().catch(() => undefined);
  }
}

main();
