"""
matcher.py
----------
Inference: given a rider's (origin_zone, destination_zone, hour) and a list of
candidate driver trips, rank drivers by cosine similarity of their HIN embeddings
to the rider's embedding.

Falls back gracefully: if the model is not trained or a node is out-of-vocabulary,
returns an empty list so the caller (matching.service.ts) can use PostGIS proximity
as the sole ranking criterion.
"""

from __future__ import annotations

import logging
import math
from typing import List, Dict, Any, Optional

import numpy as np

from app.zone_mapper import latlon_to_zone

logger = logging.getLogger(__name__)


def _cosine(a: np.ndarray, b: np.ndarray) -> float:
    denom = np.linalg.norm(a) * np.linalg.norm(b)
    if denom == 0:
        return 0.0
    return float(np.dot(a, b) / denom)


def _get_embedding(model, node_id: str) -> Optional[np.ndarray]:
    """Return embedding vector for a node, or None if OOV."""
    try:
        return model.wv[node_id]
    except KeyError:
        return None


def _rider_embedding(
    model,
    hin: Dict,
    origin_zone: int,
    dest_zone: int,
    hour: int,
) -> Optional[np.ndarray]:
    """
    Derive a rider's embedding by averaging the embeddings of:
      - pickup location node  L{origin_zone}
      - dropoff location node L{dest_zone}
      - time node             T{hour}

    This mirrors the ULTU meta-path which is the primary matching signal
    (Tang et al. 2020 §4.3).
    """
    vecs = []
    for node_id in [f"L{origin_zone}", f"L{dest_zone}", f"T{hour}"]:
        vec = _get_embedding(model, node_id)
        if vec is not None:
            vecs.append(vec)

    if not vecs:
        return None
    return np.mean(vecs, axis=0)


def _driver_embedding(
    model,
    hin: Dict,
    origin_zone: int,
    dest_zone: int,
    hour: int,
) -> Optional[np.ndarray]:
    """
    Same averaging strategy for the driver.  At inference time we do not have
    the driver's cluster ID (that requires the training parquet), so we use the
    same L+T approach.
    """
    return _rider_embedding(model, hin, origin_zone, dest_zone, hour)


def rank_drivers(
    model,
    hin: Dict,
    rider_origin_lat: float,
    rider_origin_lng: float,
    rider_dest_lat: float,
    rider_dest_lng: float,
    rider_hour: int,
    candidates: List[Dict[str, Any]],
) -> List[Dict[str, Any]]:
    """
    Rank candidate driver trips by embedding similarity to the rider.

    Parameters
    ----------
    model          : loaded gensim Word2Vec model
    hin            : loaded HIN dict (from hin_builder.load_hin)
    rider_*        : rider's origin / destination coordinates and hour
    candidates     : list of dicts with keys:
                       trip_id, driver_id,
                       origin_lat, origin_lng,
                       destination_lat, destination_lng,
                       departure_time (ISO string)

    Returns
    -------
    Same list, sorted descending by 'similarity' field (added in place).
    Returns empty list on any failure so caller can fall back to PostGIS.
    """
    try:
        rider_o_zone = latlon_to_zone(rider_origin_lat, rider_origin_lng)
        rider_d_zone = latlon_to_zone(rider_dest_lat, rider_dest_lng)
        rider_vec    = _rider_embedding(model, hin, rider_o_zone, rider_d_zone, rider_hour)

        if rider_vec is None:
            logger.warning("Rider embedding unavailable (OOV zones), returning empty ranking.")
            return []

        results = []
        for c in candidates:
            try:
                import datetime
                dep = c.get("departure_time", "")
                if dep:
                    hour = int(dep[11:13]) if len(dep) >= 13 else rider_hour
                else:
                    hour = rider_hour

                d_o_zone = latlon_to_zone(c["origin_lat"], c["origin_lng"])
                d_d_zone = latlon_to_zone(c["destination_lat"], c["destination_lng"])
                d_vec    = _driver_embedding(model, hin, d_o_zone, d_d_zone, hour)

                similarity = _cosine(rider_vec, d_vec) if d_vec is not None else 0.0
                results.append({**c, "similarity": round(similarity, 4)})
            except Exception as inner_exc:
                logger.debug(f"Skipping candidate {c.get('trip_id')}: {inner_exc}")
                results.append({**c, "similarity": 0.0})

        results.sort(key=lambda x: x["similarity"], reverse=True)
        return results

    except Exception as exc:
        logger.error(f"rank_drivers failed: {exc}")
        return []
