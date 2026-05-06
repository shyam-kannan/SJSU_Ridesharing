"""
train_local.py
--------------
Runs the full RShareForm training pipeline directly (no API server needed).
Produces models/hin.pkl and models/rshareform.model.

Usage (from services/embedding-service/):
  source venv/bin/activate
  python train_local.py
"""

import logging
import os
import sys
import time

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    stream=sys.stdout,
)
logger = logging.getLogger(__name__)

DATA_DIR  = os.getenv("DATA_DIR",  "data/nyc_taxi")
MODEL_DIR = os.getenv("MODEL_DIR", "models")

from app.hin_builder import build_hin, save_hin
from app.random_walk import generate_walks
from gensim.models import Word2Vec

EMBEDDING_DIM    = 128
WINDOW_SIZE      = 2
NEGATIVE_SAMPLES = 5
EPOCHS           = 10
WORKERS          = 4
WALK_LENGTH      = 80
WALKS_PER_NODE   = 10


def main():
    t0 = time.time()

    logger.info("=== Step 1/4: Building HIN ===")
    hin = build_hin(DATA_DIR)
    logger.info(f"HIN nodes: {len(hin['adj'])}")

    logger.info("=== Step 2/4: Generating meta-path random walks ===")
    walks = generate_walks(
        adj=hin["adj"],
        walk_length=WALK_LENGTH,
        walks_per_node=WALKS_PER_NODE,
        meta_paths=hin["meta_paths"],
    )
    logger.info(f"Total walks: {len(walks):,}")

    logger.info("=== Step 3/4: Training Word2Vec ===")
    model = Word2Vec(
        sentences=walks,
        vector_size=EMBEDDING_DIM,
        window=WINDOW_SIZE,
        negative=NEGATIVE_SAMPLES,
        sg=1,
        workers=WORKERS,
        epochs=EPOCHS,
        seed=42,
        min_count=1,
    )
    logger.info(f"Vocabulary size: {len(model.wv):,} nodes")

    logger.info("=== Step 4/4: Saving model ===")
    os.makedirs(MODEL_DIR, exist_ok=True)
    hin_path   = os.path.join(MODEL_DIR, "hin.pkl")
    model_path = os.path.join(MODEL_DIR, "rshareform.model")
    save_hin(hin, hin_path)
    model.save(model_path)

    elapsed = time.time() - t0
    logger.info(f"Done in {elapsed:.1f}s. Files:")
    logger.info(f"  {hin_path}   ({os.path.getsize(hin_path) / 1e6:.1f} MB)")
    logger.info(f"  {model_path} ({os.path.getsize(model_path) / 1e6:.1f} MB)")


if __name__ == "__main__":
    main()
