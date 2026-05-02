from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import googlemaps
import redis
import json
import hashlib
import os
from typing import Optional, Union
from dotenv import load_dotenv
from app.secret_loader import load_mounted_secrets

load_dotenv()
load_mounted_secrets()

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
in_kubernetes = os.getenv("KUBERNETES_SERVICE_HOST") is not None
default_redis_url = "redis://redis:6379" if in_kubernetes else "redis://127.0.0.1:6379"
REDIS_URL = os.getenv("REDIS_URL", default_redis_url)
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
    polyline: Optional[str] = None


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

    # Call Google Maps Directions API
    try:
        # Clean inputs
        origin = request.origin.strip()
        destination = request.destination.strip()

        # Check for very close points (epsilon check)
        # If they look like coordinates, we can do a quick check
        is_coord = False
        try:
            o_lat, o_lng = map(float, origin.split(','))
            d_lat, d_lng = map(float, destination.split(','))
            is_coord = True
            # Rough distance check (~11 meters per 0.0001 degree)
            if abs(o_lat - d_lat) < 0.0001 and abs(o_lng - d_lng) < 0.0001:
                print(f"📍 Origin and destination are very close, returning zero route")
                return RouteResponse(
                    distance_meters=0,
                    distance_miles=0.0,
                    duration_seconds=0,
                    polyline=""
                )
        except:
            pass

        result = gmaps.directions(
            origin=origin,
            destination=destination,
            mode="driving",
            units="metric",
        )

        if not result:
            raise HTTPException(status_code=400, detail="Route not found")

        route = result[0]
        leg = route["legs"][0]

        distance_meters = leg["distance"]["value"]
        distance_miles = distance_meters * 0.000621371  # Convert to miles
        duration_seconds = leg["duration"]["value"]

        # Get polyline from Directions API (follows road)
        polyline = route.get("overview_polyline", {}).get("points")

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
                print(f"✅ Cached route: {origin} → {destination}")
            except Exception as e:
                print(f"⚠️  Redis set error: {e}")

        return RouteResponse(**response_data)

    except googlemaps.exceptions.ApiError as e:
        raise HTTPException(status_code=502, detail=f"Google Maps API error: {str(e)}")
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Route calculation error: {e}")
        raise HTTPException(status_code=500, detail="Failed to calculate route")


if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("ROUTING_SERVICE_PORT", "8002"))
    uvicorn.run(app, host="0.0.0.0", port=port)
