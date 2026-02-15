from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import googlemaps
import redis
import json
import hashlib
import os
from dotenv import load_dotenv

load_dotenv()

app = FastAPI(title="Routing Service", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize Google Maps client
GOOGLE_MAPS_API_KEY = os.getenv("GOOGLE_MAPS_API_KEY")
if not GOOGLE_MAPS_API_KEY:
    print("⚠️  GOOGLE_MAPS_API_KEY not set - routing will fail")
    gmaps = None
else:
    gmaps = googlemaps.Client(key=GOOGLE_MAPS_API_KEY)

# Initialize Redis client
REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379")
CACHE_TTL = int(os.getenv("ROUTE_CACHE_TTL", "3600"))  # 1 hour default

try:
    redis_client = redis.from_url(REDIS_URL, decode_responses=True)
    redis_client.ping()
    print(f"✅ Connected to Redis at {REDIS_URL}")
except Exception as e:
    print(f"⚠️  Redis connection failed: {e}")
    redis_client = None


class RouteRequest(BaseModel):
    origin: str
    destination: str


class RouteResponse(BaseModel):
    distance_meters: int
    distance_miles: float
    duration_seconds: int
    polyline: str | None = None


def get_cache_key(origin: str, destination: str) -> str:
    """Generate cache key from origin and destination"""
    key_str = f"route:{origin}:{destination}".lower()
    return hashlib.md5(key_str.encode()).hexdigest()


@app.get("/health")
def health_check():
    return {
        "status": "success",
        "message": "Routing Service is running",
        "google_maps_configured": GOOGLE_MAPS_API_KEY is not None,
        "redis_connected": redis_client is not None,
    }


@app.post("/route/calculate", response_model=RouteResponse)
async def calculate_route(request: RouteRequest):
    """
    Calculate route distance and duration using Google Maps Distance Matrix API
    Results are cached in Redis for 1 hour
    """
    if not gmaps:
        raise HTTPException(status_code=503, detail="Google Maps API not configured")

    # Check cache first
    cache_key = get_cache_key(request.origin, request.destination)

    if redis_client:
        try:
            cached = redis_client.get(cache_key)
            if cached:
                print(f"✅ Cache hit for route: {request.origin} → {request.destination}")
                return RouteResponse(**json.loads(cached))
        except Exception as e:
            print(f"⚠️  Redis get error: {e}")

    # Call Google Maps Distance Matrix API
    try:
        result = gmaps.distance_matrix(
            origins=[request.origin],
            destinations=[request.destination],
            mode="driving",
            units="metric",
        )

        if result["status"] != "OK":
            raise HTTPException(status_code=400, detail=f"Google Maps API error: {result['status']}")

        element = result["rows"][0]["elements"][0]

        if element["status"] != "OK":
            raise HTTPException(
                status_code=400,
                detail=f"Route not found: {element.get('status', 'UNKNOWN')}"
            )

        distance_meters = element["distance"]["value"]
        distance_miles = distance_meters * 0.000621371  # Convert to miles
        duration_seconds = element["duration"]["value"]

        # Get polyline (optional - requires Directions API for more detail)
        polyline = None

        response_data = {
            "distance_meters": distance_meters,
            "distance_miles": round(distance_miles, 2),
            "duration_seconds": duration_seconds,
            "polyline": polyline,
        }

        # Cache the result
        if redis_client:
            try:
                redis_client.setex(
                    cache_key,
                    CACHE_TTL,
                    json.dumps(response_data)
                )
                print(f"✅ Cached route: {request.origin} → {request.destination}")
            except Exception as e:
                print(f"⚠️  Redis set error: {e}")

        return RouteResponse(**response_data)

    except googlemaps.exceptions.ApiError as e:
        raise HTTPException(status_code=502, detail=f"Google Maps API error: {str(e)}")
    except Exception as e:
        print(f"❌ Route calculation error: {e}")
        raise HTTPException(status_code=500, detail="Failed to calculate route")


if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("ROUTING_SERVICE_PORT", "8002"))
    uvicorn.run(app, host="0.0.0.0", port=port)
