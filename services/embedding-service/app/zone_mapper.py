"""
zone_mapper.py
--------------
Maps Bay Area lat/lng coordinates to 16×16 grid zone IDs (256 zones total),
which are then mapped to NYC taxi zone IDs (1–265) so the HIN built from NYC
taxi parquet data is compatible with Bay Area trip requests at inference time.

Bay Area bounding box used:
  lat: 36.90 – 37.92   (SJSU south to North Bay)
  lng: -122.55 – -121.55  (West Bay to East Bay)
"""

from __future__ import annotations
import math
from typing import Tuple

# Bay Area bounding box
_LAT_MIN = 36.90
_LAT_MAX = 37.92
_LNG_MIN = -122.55
_LNG_MAX = -121.55

# Grid dimensions: 16 rows × 16 cols = 256 zones
_GRID_ROWS = 16
_GRID_COLS = 16

# NYC taxi dataset has zones 1–265.  We remap our 256 Bay Area zones to 1–256
# (a contiguous subset), leaving NYC zones 257–265 unused so zone IDs never
# collide with real NYC zones above 256.
_NYC_OFFSET = 1   # bay area zone 0 → nyc zone 1


def _clamp(value: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, value))


def latlon_to_zone(lat: float, lng: float) -> int:
    """
    Convert a (lat, lng) coordinate inside the Bay Area bounding box to an
    integer zone ID in [1, 256].  Points outside the bounding box are clamped.

    Returns
    -------
    int
        Zone ID in [1, 256].
    """
    lat = _clamp(lat, _LAT_MIN, _LAT_MAX)
    lng = _clamp(lng, _LNG_MIN, _LNG_MAX)

    row = int((lat - _LAT_MIN) / (_LAT_MAX - _LAT_MIN) * _GRID_ROWS)
    col = int((lng - _LNG_MIN) / (_LNG_MAX - _LNG_MIN) * _GRID_COLS)

    row = min(row, _GRID_ROWS - 1)
    col = min(col, _GRID_COLS - 1)

    zone_index = row * _GRID_COLS + col   # 0–255
    return zone_index + _NYC_OFFSET       # 1–256


def zone_to_latlon_center(zone_id: int) -> Tuple[float, float]:
    """
    Return the (lat, lng) center of the grid cell corresponding to zone_id.
    Useful for debugging / visualisation.
    """
    zone_index = zone_id - _NYC_OFFSET    # back to 0-based
    row = zone_index // _GRID_COLS
    col = zone_index % _GRID_COLS

    lat = _LAT_MIN + (row + 0.5) / _GRID_ROWS * (_LAT_MAX - _LAT_MIN)
    lng = _LNG_MIN + (col + 0.5) / _GRID_COLS * (_LNG_MAX - _LNG_MIN)
    return lat, lng


def nyc_to_bay_zone(nyc_zone_id: int) -> int:
    """
    For zones that come directly from NYC taxi data (already in [1, 265]),
    clamp them into the [1, 256] range so they map cleanly to Bay Area cells.
    """
    return max(1, min(nyc_zone_id, _GRID_ROWS * _GRID_COLS))
