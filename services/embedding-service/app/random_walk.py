"""
random_walk.py
--------------
Meta-path-guided random walks over the HIN for RShareForm (Tang et al. 2020).

Supported meta-paths (§3.3):
  ULU    – User → Location → User
  ULTU   – User → Location → Time → User          (primary signal)
  ULTLU  – User → Location → Time → Location → User
  ULLTLU – User → Location → Location → Time → Location → User

Walk parameters (from paper):
  walk_length  = 80
  walks_per_node = 10
"""

from __future__ import annotations

import random
import logging
from typing import Dict, List, Optional

logger = logging.getLogger(__name__)

# Node type is encoded as the first character of its ID string.
_NODE_TYPE = {
    "U": "U",
    "L": "L",
    "T": "T",
    "A": "A",
}

# Meta-path schemas: ordered list of node types the walk must follow.
_META_PATH_SCHEMAS: Dict[str, List[str]] = {
    "ULU":    ["U", "L", "U"],
    "ULTU":   ["U", "L", "T", "U"],
    "ULTLU":  ["U", "L", "T", "L", "U"],
    "ULLTLU": ["U", "L", "L", "T", "L", "U"],
}


def _node_type(node_id: str) -> str:
    return node_id[0] if node_id else ""


def _neighbors_of_type(
    adj: Dict[str, List[str]],
    node: str,
    target_type: str,
) -> List[str]:
    """Return all neighbors of `node` that have the target node type."""
    return [n for n in adj.get(node, []) if _node_type(n) == target_type]


def _single_walk(
    adj: Dict[str, List[str]],
    start_node: str,
    schema: List[str],
    walk_length: int,
) -> List[str]:
    """
    Generate one meta-path-constrained random walk of length `walk_length`
    starting at `start_node`, cycling through `schema`.

    The schema is repeated cyclically to fill `walk_length` steps.
    """
    walk = [start_node]
    schema_len = len(schema)
    step_in_schema = 1   # we're at schema[0], next step must be schema[1]

    for _ in range(walk_length - 1):
        current = walk[-1]
        target_type = schema[step_in_schema % schema_len]
        candidates = _neighbors_of_type(adj, current, target_type)
        if not candidates:
            break
        next_node = random.choice(candidates)
        walk.append(next_node)
        step_in_schema += 1

    return walk


def generate_walks(
    adj: Dict[str, List[str]],
    walk_length: int = 80,
    walks_per_node: int = 10,
    meta_paths: Optional[List[str]] = None,
    seed: int = 42,
) -> List[List[str]]:
    """
    Generate meta-path random walks over the HIN for all U-type nodes.

    Parameters
    ----------
    adj           : HIN adjacency dict {node_id: [neighbor_ids]}
    walk_length   : length of each walk (default 80)
    walks_per_node: number of walks per U-node per meta-path (default 10)
    meta_paths    : list of meta-path names to use (default: all 4)
    seed          : random seed for reproducibility

    Returns
    -------
    List of walks, each walk is a List[str] of node IDs.
    """
    random.seed(seed)
    if meta_paths is None:
        meta_paths = list(_META_PATH_SCHEMAS.keys())

    u_nodes = [n for n in adj if _node_type(n) == "U"]
    logger.info(f"Generating walks for {len(u_nodes)} U-nodes, "
                f"{walks_per_node} walks/node, {len(meta_paths)} meta-paths, "
                f"walk_length={walk_length} …")

    all_walks: List[List[str]] = []

    for mp_name in meta_paths:
        schema = _META_PATH_SCHEMAS.get(mp_name)
        if schema is None:
            logger.warning(f"Unknown meta-path '{mp_name}', skipping.")
            continue

        for node in u_nodes:
            for _ in range(walks_per_node):
                walk = _single_walk(adj, node, schema, walk_length)
                if len(walk) > 1:
                    all_walks.append(walk)

    logger.info(f"Generated {len(all_walks):,} walks total.")
    return all_walks
