"""
trainer.py
----------
Orchestrates the full RShareForm training pipeline (Tang et al. 2020):

  1. Build the HIN from NYC taxi parquet files
  2. Generate meta-path random walks
  3. Train Word2Vec skip-gram (d=128, window=2, negative=5, epochs=10)
  4. Save the model + HIN to MODEL_DIR

Training runs in a background thread so the FastAPI process stays responsive.
Job status is tracked in a shared in-memory dict (job_store).
"""

from __future__ import annotations

import os
import pickle
import logging
import threading
import uuid
from datetime import datetime
from typing import Dict, Any

from gensim.models import Word2Vec

from app.hin_builder import build_hin, save_hin
from app.random_walk import generate_walks

logger = logging.getLogger(__name__)

# ─────────────────────────────────────────────────────────────────────────────
# Word2Vec hyper-parameters (Tang et al. 2020, §4.2)
# ─────────────────────────────────────────────────────────────────────────────
EMBEDDING_DIM   = 128   # d
WINDOW_SIZE     = 2     # context window
NEGATIVE_SAMPLES = 5    # k
EPOCHS          = 10
WORKERS         = 4

WALK_LENGTH     = 80
WALKS_PER_NODE  = 10

# ─────────────────────────────────────────────────────────────────────────────
# Job store  {job_id: {status, started_at, finished_at, error}}
# ─────────────────────────────────────────────────────────────────────────────
job_store: Dict[str, Dict[str, Any]] = {}

_lock = threading.Lock()


def _set_job(job_id: str, **kwargs: Any) -> None:
    with _lock:
        job_store.setdefault(job_id, {}).update(kwargs)


def _get_paths(model_dir: str) -> Dict[str, str]:
    return {
        "hin":   os.path.join(model_dir, "hin.pkl"),
        "model": os.path.join(model_dir, "rshareform.model"),
    }


# ─────────────────────────────────────────────────────────────────────────────
# Training worker (runs in background thread)
# ─────────────────────────────────────────────────────────────────────────────

def _train_worker(job_id: str, data_dir: str, model_dir: str) -> None:
    try:
        _set_job(job_id, status="building_hin", started_at=datetime.utcnow().isoformat())
        logger.info(f"[{job_id}] Building HIN from {data_dir} …")
        hin = build_hin(data_dir)

        _set_job(job_id, status="generating_walks")
        logger.info(f"[{job_id}] Generating meta-path random walks …")
        walks = generate_walks(
            adj=hin["adj"],
            walk_length=WALK_LENGTH,
            walks_per_node=WALKS_PER_NODE,
            meta_paths=hin["meta_paths"],
        )

        _set_job(job_id, status="training_word2vec")
        logger.info(f"[{job_id}] Training Word2Vec (d={EMBEDDING_DIM}, "
                    f"window={WINDOW_SIZE}, neg={NEGATIVE_SAMPLES}, epochs={EPOCHS}) …")
        model = Word2Vec(
            sentences=walks,
            vector_size=EMBEDDING_DIM,
            window=WINDOW_SIZE,
            negative=NEGATIVE_SAMPLES,
            sg=1,             # skip-gram
            workers=WORKERS,
            epochs=EPOCHS,
            seed=42,
            min_count=1,      # include all nodes
        )

        _set_job(job_id, status="saving")
        paths = _get_paths(model_dir)
        os.makedirs(model_dir, exist_ok=True)
        save_hin(hin, paths["hin"])
        model.save(paths["model"])
        logger.info(f"[{job_id}] Model saved to {paths['model']}")

        _set_job(job_id, status="done", finished_at=datetime.utcnow().isoformat(), error=None)
        logger.info(f"[{job_id}] Training complete.")

    except Exception as exc:
        logger.exception(f"[{job_id}] Training failed: {exc}")
        _set_job(job_id, status="error", finished_at=datetime.utcnow().isoformat(), error=str(exc))


# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────

def start_training(data_dir: str, model_dir: str) -> str:
    """Launch training in a background thread and return a job_id."""
    job_id = str(uuid.uuid4())
    _set_job(job_id, status="queued", started_at=None, finished_at=None, error=None)
    t = threading.Thread(target=_train_worker, args=(job_id, data_dir, model_dir), daemon=True)
    t.start()
    return job_id


def get_job_status(job_id: str) -> Dict[str, Any] | None:
    with _lock:
        return dict(job_store.get(job_id, {})) or None


def is_model_ready(model_dir: str) -> bool:
    paths = _get_paths(model_dir)
    return os.path.exists(paths["hin"]) and os.path.exists(paths["model"])


def load_model(model_dir: str):
    """Load and return (hin, Word2Vec model).  Raises if not trained yet."""
    paths = _get_paths(model_dir)
    if not is_model_ready(model_dir):
        raise RuntimeError("Model not trained yet. Call POST /train first.")
    with open(paths["hin"], "rb") as f:
        hin = pickle.load(f)
    model = Word2Vec.load(paths["model"])
    return hin, model
