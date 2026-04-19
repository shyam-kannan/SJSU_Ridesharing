"""
main.py – RShareForm Embedding Service (port 3010)
---------------------------------------------------
Exposes:
  POST /train                    – kick off background training job
  GET  /train/status/{job_id}    – poll job progress
  POST /match                    – rank driver candidates for a rider
  GET  /health                   – liveness check
"""

from __future__ import annotations

import os
import logging
from typing import List, Optional, Dict, Any

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv

from app import trainer
from app import matcher

load_dotenv()
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger(__name__)

DATA_DIR  = os.getenv("DATA_DIR",  "data/nyc_taxi")
MODEL_DIR = os.getenv("MODEL_DIR", "models")

app = FastAPI(title="RShareForm Embedding Service", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Lazy-loaded model cache (loaded once after training completes)
_model_cache: Optional[Dict[str, Any]] = None


def _get_model():
    """Return (hin, w2v_model), loading from disk if needed."""
    global _model_cache
    if _model_cache is not None:
        return _model_cache["hin"], _model_cache["model"]

    if not trainer.is_model_ready(MODEL_DIR):
        return None, None

    hin, model = trainer.load_model(MODEL_DIR)
    _model_cache = {"hin": hin, "model": model}
    logger.info("Model loaded into memory cache.")
    return hin, model


# ─────────────────────────────────────────────────────────────────────────────
# Request / Response schemas
# ─────────────────────────────────────────────────────────────────────────────

class TrainRequest(BaseModel):
    data_dir:  Optional[str] = None  # override DATA_DIR env
    model_dir: Optional[str] = None  # override MODEL_DIR env


class TrainResponse(BaseModel):
    job_id: str
    status: str
    message: str


class DriverCandidate(BaseModel):
    trip_id:         str
    driver_id:       str
    origin_lat:      float
    origin_lng:      float
    destination_lat: float
    destination_lng: float
    departure_time:  str   # ISO 8601


class MatchRequest(BaseModel):
    rider_origin_lat:  float
    rider_origin_lng:  float
    rider_dest_lat:    float
    rider_dest_lng:    float
    rider_hour:        int           # 0-23
    candidates:        List[DriverCandidate]


class RankedCandidate(BaseModel):
    trip_id:    str
    driver_id:  str
    similarity: float


class MatchResponse(BaseModel):
    ranked:       List[RankedCandidate]
    model_used:   bool   # False = model not ready, caller should use PostGIS only


# ─────────────────────────────────────────────────────────────────────────────
# Endpoints
# ─────────────────────────────────────────────────────────────────────────────

@app.get("/health")
def health():
    return {
        "status": "success",
        "service": "embedding-service",
        "model_ready": trainer.is_model_ready(MODEL_DIR),
        "active_jobs": len(trainer.job_store),
    }


@app.post("/train", response_model=TrainResponse)
def start_train(req: TrainRequest = TrainRequest()):
    global _model_cache
    _model_cache = None   # invalidate cache so new model is loaded after training

    data_dir  = req.data_dir  or DATA_DIR
    model_dir = req.model_dir or MODEL_DIR

    if not os.path.isdir(data_dir):
        raise HTTPException(
            status_code=400,
            detail=f"data_dir '{data_dir}' does not exist. "
                   f"Place NYC taxi parquet files there first."
        )

    job_id = trainer.start_training(data_dir, model_dir)
    logger.info(f"Training job {job_id} started.")
    return TrainResponse(
        job_id=job_id,
        status="queued",
        message="Training started in background. Poll /train/status/{job_id} for progress."
    )


@app.get("/train/status/{job_id}")
def train_status(job_id: str):
    status = trainer.get_job_status(job_id)
    if status is None:
        raise HTTPException(status_code=404, detail=f"Job '{job_id}' not found.")
    return {"job_id": job_id, **status}


@app.post("/match", response_model=MatchResponse)
def match_drivers(req: MatchRequest):
    hin, model = _get_model()

    if model is None or hin is None:
        # Graceful degradation: return candidates unsorted with similarity=0
        logger.warning("Model not ready – returning unranked candidates.")
        ranked = [
            RankedCandidate(trip_id=c.trip_id, driver_id=c.driver_id, similarity=0.0)
            for c in req.candidates
        ]
        return MatchResponse(ranked=ranked, model_used=False)

    raw_candidates = [c.model_dump() for c in req.candidates]
    ranked_raw = matcher.rank_drivers(
        model=model,
        hin=hin,
        rider_origin_lat=req.rider_origin_lat,
        rider_origin_lng=req.rider_origin_lng,
        rider_dest_lat=req.rider_dest_lat,
        rider_dest_lng=req.rider_dest_lng,
        rider_hour=req.rider_hour,
        candidates=raw_candidates,
    )

    if not ranked_raw:
        # Embedding failed (OOV) – fall back gracefully
        ranked = [
            RankedCandidate(trip_id=c.trip_id, driver_id=c.driver_id, similarity=0.0)
            for c in req.candidates
        ]
        return MatchResponse(ranked=ranked, model_used=False)

    ranked = [
        RankedCandidate(
            trip_id=r["trip_id"],
            driver_id=r["driver_id"],
            similarity=r.get("similarity", 0.0),
        )
        for r in ranked_raw
    ]
    return MatchResponse(ranked=ranked, model_used=True)


if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("EMBEDDING_SERVICE_PORT", "3010"))
    uvicorn.run(app, host="0.0.0.0", port=port)
