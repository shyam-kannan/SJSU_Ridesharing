from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import psycopg2
import os
from dotenv import load_dotenv
from typing import List

load_dotenv()

app = FastAPI(title="Grouping Service", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

DATABASE_URL = os.getenv("DATABASE_URL")

def get_db_connection():
    return psycopg2.connect(DATABASE_URL)


class TripMatchRequest(BaseModel):
    rider_id: str
    origin_lat: float
    origin_lng: float
    destination_lat: float
    destination_lng: float
    departure_time: str
    seats_needed: int = 1


class TripMatch(BaseModel):
    trip_id: str
    score: float
    distance_to_origin: float
    distance_to_destination: float
    available_seats: int


class TripMatchResponse(BaseModel):
    matches: List[TripMatch]


"""
TODO: ADVANCED ML MODEL INTEGRATION POINT

This is a simple distance-based matching algorithm. To integrate ML-based grouping:

1. Replace calculate_score() with your ML model's similarity score
2. Consider additional features:
   - User preferences (music, temperature, conversation level)
   - Historical compatibility scores between users
   - Driver ratings and driving style
   - Pickup time flexibility
   - Route overlap percentage
   - Social graph (mutual friends, same classes)
   - Demographic compatibility

Example ML Integration:

def predict_compatibility(rider_profile, driver_profile, trip_features):
    response = requests.post('http://ml-grouping-service/predict', json={
        'rider_features': extract_rider_features(rider_profile),
        'driver_features': extract_driver_features(driver_profile),
        'trip_features': trip_features,
        'temporal_features': extract_time_features(departure_time)
    })
    return response.json()['compatibility_score']

Then use this score in place of the simple distance calculation below.
"""


def calculate_simple_score(dist_origin: float, dist_dest: float, seats_match: bool) -> float:
    """
    Simple scoring based on distance proximity
    TODO: Replace with ML model prediction (see comment above)
    """
    # Normalize distances (assuming max search radius of 5000m)
    origin_score = max(0, 1 - (dist_origin / 5000))
    dest_score = max(0, 1 - (dist_dest / 5000))

    # Average of origin and destination proximity
    base_score = (origin_score + dest_score) / 2

    # Boost if seats match
    if seats_match:
        base_score *= 1.5

    return round(base_score, 3)


@app.get("/health")
def health_check():
    return {
        "status": "success",
        "message": "Grouping Service is running",
        "algorithm": "simple_distance_based",
        "ml_ready": False,  # Set to True when ML model is integrated
    }


@app.post("/group/match", response_model=TripMatchResponse)
async def match_trips(request: TripMatchRequest):
    """
    Find matching trips for a rider using simple geospatial scoring
    TODO: Replace with ML-based compatibility prediction (see code comments)
    """
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # Find trips near origin (within 5km) with available seats
        query = """
        SELECT
            t.trip_id,
            t.seats_available,
            ST_Distance(
                t.origin_point::geography,
                ST_SetSRID(ST_MakePoint(%s, %s), 4326)::geography
            ) as dist_to_origin,
            ST_Distance(
                t.destination_point::geography,
                ST_SetSRID(ST_MakePoint(%s, %s), 4326)::geography
            ) as dist_to_dest
        FROM trips t
        WHERE
            t.status = 'active'
            AND t.seats_available >= %s
            AND ST_DWithin(
                t.origin_point::geography,
                ST_SetSRID(ST_MakePoint(%s, %s), 4326)::geography,
                5000
            )
        ORDER BY dist_to_origin
        LIMIT 50
        """

        cursor.execute(query, (
            request.origin_lng, request.origin_lat,  # For origin distance
            request.destination_lng, request.destination_lat,  # For dest distance
            request.seats_needed,  # Seats filter
            request.origin_lng, request.origin_lat,  # For ST_DWithin
        ))

        rows = cursor.fetchall()
        matches = []

        for row in rows:
            trip_id, seats_available, dist_origin, dist_dest = row

            # Calculate simple score
            # TODO: Replace with ML model (see comment at top of file)
            score = calculate_simple_score(
                dist_origin,
                dist_dest,
                seats_available >= request.seats_needed
            )

            matches.append(TripMatch(
                trip_id=trip_id,
                score=score,
                distance_to_origin=round(dist_origin, 2),
                distance_to_destination=round(dist_dest, 2),
                available_seats=seats_available
            ))

        # Sort by score (highest first) and return top 10
        matches.sort(key=lambda x: x.score, reverse=True)
        top_matches = matches[:10]

        cursor.close()
        conn.close()

        return TripMatchResponse(matches=top_matches)

    except Exception as e:
        print(f"❌ Matching error: {e}")
        raise HTTPException(status_code=500, detail="Failed to match trips")


if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("GROUPING_SERVICE_PORT", "8001"))
    uvicorn.run(app, host="0.0.0.0", port=port)
