"""
SAHARA AI — USGS Earthquake Real-Time Feed
Public API, no key required. Pulls earthquakes >M3.0 in last 24h from the Pakistan region.
"""

import httpx
from datetime import datetime
from typing import List, Dict

# Pakistan + surrounding seismically active region (roughly)
PK_MIN_LAT, PK_MAX_LAT = 23.0, 38.0
PK_MIN_LON, PK_MAX_LON = 60.0, 80.0


async def get_recent_earthquakes(min_magnitude: float = 2.5, limit: int = 15) -> List[Dict]:
    """Fetch recent earthquakes from USGS — real public data, no key needed."""
    try:
        async with httpx.AsyncClient(timeout=8.0) as client:
            resp = await client.get(
                "https://earthquake.usgs.gov/fdsnws/event/1/query",
                params={
                    "format":       "geojson",
                    "starttime":    "NOW-7days",
                    "minmagnitude": min_magnitude,
                    "minlatitude":  PK_MIN_LAT,
                    "maxlatitude":  PK_MAX_LAT,
                    "minlongitude": PK_MIN_LON,
                    "maxlongitude": PK_MAX_LON,
                    "limit":        limit,
                    "orderby":      "time",
                }
            )
            resp.raise_for_status()
            data = resp.json()

        out = []
        for feature in data.get("features", []):
            p = feature.get("properties", {})
            g = feature.get("geometry", {}).get("coordinates", [0, 0, 0])
            mag = p.get("mag", 0)
            place = p.get("place", "Unknown")
            ts = p.get("time", 0)
            # Severity from magnitude
            if mag >= 6.0:
                severity = "CRITICAL"
            elif mag >= 5.0:
                severity = "HIGH"
            elif mag >= 4.0:
                severity = "MEDIUM"
            else:
                severity = "LOW"
            out.append({
                "id":         feature.get("id"),
                "magnitude":  round(mag, 1),
                "place":      place,
                "time":       datetime.fromtimestamp(ts / 1000).isoformat() if ts else None,
                "lat":        g[1],
                "lon":        g[0],
                "depth_km":   round(g[2] if len(g) > 2 else 0, 1),
                "severity":   severity,
                "source":     "usgs_realtime",
                "text":       f"Magnitude {mag:.1f} earthquake near {place} (depth {g[2] if len(g) > 2 else '?'} km)",
                "url":        p.get("url", ""),
                "tsunami":    bool(p.get("tsunami", 0)),
                "felt":       p.get("felt"),
            })
        return out
    except Exception as e:
        print(f"[USGS] Earthquake fetch failed: {e}")
        return []
