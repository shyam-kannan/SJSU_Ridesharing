"""
hin_builder.py
--------------
Builds a Heterogeneous Information Network (HIN) from NYC Yellow Taxi parquet
files following Tang et al. 2020 (RShareForm).

Node types
----------
U – pseudo-user cluster  (K-Means k=500 on pickup/dropoff/hour)
L – location zone        (NYC taxi zone IDs, clamped to 1-256 for Bay Area)
T – time bin             (hour 0-23)
A – activity type        (pickup=0, dropoff=1)

Meta-paths supported
--------------------
ULU   – two users share a location
ULTU  – two users share location+time         (primary matching signal)
ULTLU – two users share location+time, intermediate location
ULLTLU– full route context with both L nodes

The HIN is stored as an adjacency dict so random_walk.py can traverse it
without loading the entire parquet dataset at inference time.
"""

from __future__ import annotations

import os
import glob
import pickle
import logging
from collections import defaultdict
from typing import Dict, List, Tuple

import numpy as np
import pandas as pd
from sklearn.cluster import KMeans
from sklearn.preprocessing import StandardScaler

from app.zone_mapper import nyc_to_bay_zone

logger = logging.getLogger(__name__)

# ─────────────────────────────────────────────────────────────────────────────
# Constants (from Tang et al. 2020)
# ─────────────────────────────────────────────────────────────────────────────
K_CLUSTERS = 500           # pseudo-user clusters
MAX_ROWS_PER_FILE = 500_000  # cap to keep memory reasonable
REQUIRED_COLS = [
    "PULocationID", "DOLocationID",
    "tpep_pickup_datetime",
]

# ─────────────────────────────────────────────────────────────────────────────
# Node ID helpers  (prefix + integer → unique string)
# ─────────────────────────────────────────────────────────────────────────────

def uid(cluster_id: int) -> str:
    return f"U{cluster_id}"

def lid(zone_id: int) -> str:
    return f"L{zone_id}"

def tid(hour: int) -> str:
    return f"T{hour}"

def aid(activity: int) -> str:
    return f"A{activity}"   # A0=pickup, A1=dropoff


# ─────────────────────────────────────────────────────────────────────────────
# Data loading
# ─────────────────────────────────────────────────────────────────────────────

def _load_parquet_files(data_dir: str) -> pd.DataFrame:
    """Load all parquet files from data_dir into a single DataFrame."""
    files = sorted(glob.glob(os.path.join(data_dir, "*.parquet")))
    if not files:
        raise FileNotFoundError(f"No parquet files found in {data_dir}")

    frames: List[pd.DataFrame] = []
    for f in files:
        logger.info(f"Loading {f} …")
        df = pd.read_parquet(f, columns=REQUIRED_COLS)
        df = df.dropna(subset=REQUIRED_COLS)
        # Keep valid NYC zone IDs only
        df = df[(df["PULocationID"] >= 1) & (df["PULocationID"] <= 265)]
        df = df[(df["DOLocationID"] >= 1) & (df["DOLocationID"] <= 265)]
        frames.append(df.head(MAX_ROWS_PER_FILE))

    merged = pd.concat(frames, ignore_index=True)
    logger.info(f"Loaded {len(merged):,} rows from {len(files)} file(s).")
    return merged


# ─────────────────────────────────────────────────────────────────────────────
# Pseudo-user clustering
# ─────────────────────────────────────────────────────────────────────────────

def _build_user_clusters(df: pd.DataFrame) -> Tuple[KMeans, StandardScaler, np.ndarray, "pd.Index"]:
    """
    K-Means (k=500) on (PULocationID, DOLocationID, hour_bin) features
    to create pseudo-user nodes, following Tang et al. 2020 §3.2.

    Returns the fitted KMeans, scaler, cluster labels, and the index of rows
    that survived datetime parsing (so callers can align labels with the
    original DataFrame).
    """
    df = df.copy()
    df["hour"] = pd.to_datetime(df["tpep_pickup_datetime"], errors='coerce').dt.hour
    df = df.dropna(subset=["hour"])
    df["hour"] = df["hour"].astype(int)

    features = df[["PULocationID", "DOLocationID", "hour"]].astype(float).values

    scaler = StandardScaler()
    features_scaled = scaler.fit_transform(features)

    num_samples = len(features_scaled)
    actual_clusters = min(K_CLUSTERS, num_samples)

    if actual_clusters < 1:
        raise ValueError("No valid data samples found for clustering.")

    logger.info(f"Fitting K-Means (k={actual_clusters}) on {num_samples:,} samples …")
    kmeans = KMeans(n_clusters=actual_clusters, n_init=10, random_state=42)
    labels = kmeans.fit_predict(features_scaled)

    return kmeans, scaler, labels, df.index


# ─────────────────────────────────────────────────────────────────────────────
# HIN construction
# ─────────────────────────────────────────────────────────────────────────────

def build_hin(data_dir: str) -> Dict:
    """
    Build the full HIN and return a dict with:
      - 'adj':     adjacency list  {node_id: [neighbor_node_id, ...]}
      - 'kmeans':  fitted KMeans model
      - 'scaler':  fitted StandardScaler
      - 'meta_paths': list of supported meta-path names
    """
    df = _load_parquet_files(data_dir)
    kmeans, scaler, labels, valid_index = _build_user_clusters(df)

    # Restrict to the rows that survived datetime parsing in _build_user_clusters,
    # then assign cluster labels by position (labels is a plain numpy array).
    df = df.loc[valid_index].copy()
    df["cluster"] = labels
    df["hour"] = pd.to_datetime(df["tpep_pickup_datetime"], errors='coerce').dt.hour
    df = df.dropna(subset=["hour"])
    df["hour"] = df["hour"].astype(int)
    df["pu_zone"] = df["PULocationID"].apply(nyc_to_bay_zone)
    df["do_zone"] = df["DOLocationID"].apply(nyc_to_bay_zone)

    # Adjacency list: use sets to avoid duplicates, then convert to sorted lists
    adj: Dict[str, set] = defaultdict(set)

    logger.info("Building HIN adjacency from trip rows …")
    for row in df[["cluster", "pu_zone", "do_zone", "hour"]].itertuples(index=False):
        u = uid(row.cluster)
        pu = lid(row.pu_zone)
        do = lid(row.do_zone)
        t  = tid(row.hour)
        a0 = aid(0)   # pickup activity
        a1 = aid(1)   # dropoff activity

        # U ↔ L (pickup)
        adj[u].add(pu);  adj[pu].add(u)
        # L ↔ T
        adj[pu].add(t);  adj[t].add(pu)
        # L ↔ A (pickup activity)
        adj[pu].add(a0); adj[a0].add(pu)
        # U ↔ L (dropoff)
        adj[u].add(do);  adj[do].add(u)
        # L ↔ A (dropoff activity)
        adj[do].add(a1); adj[a1].add(do)
        # L ↔ T (dropoff time)
        adj[do].add(t);  adj[t].add(do)

    # Convert sets to sorted lists for reproducibility
    adj_final: Dict[str, List[str]] = {k: sorted(v) for k, v in adj.items()}

    logger.info(f"HIN built: {len(adj_final)} nodes total.")

    return {
        "adj": adj_final,
        "kmeans": kmeans,
        "scaler": scaler,
        "meta_paths": ["ULU", "ULTU", "ULTLU", "ULLTLU"],
    }


def save_hin(hin: Dict, path: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        pickle.dump(hin, f, protocol=4)
    logger.info(f"HIN saved to {path}")


def load_hin(path: str) -> Dict:
    with open(path, "rb") as f:
        return pickle.load(f)
