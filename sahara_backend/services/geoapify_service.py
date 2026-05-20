"""
SAHARA AI — Geoapify Service
Finds nearest hospitals/emergency services and calculates routes.
"""

import os
import httpx
from typing import List, Dict

GEOAPIFY_KEY = os.getenv("GEOAPIFY_API_KEY", "")

CITY_COORDS = {
    # Metros
    "karachi":    (24.8607, 67.0011),
    "lahore":     (31.5204, 74.3587),
    "islamabad":  (33.6938, 73.0652),
    "rawalpindi": (33.5651, 73.0169),
    "peshawar":   (34.0151, 71.5249),
    "quetta":     (30.1798, 66.9750),
    "multan":     (30.1575, 71.5249),
    "faisalabad": (31.4504, 73.1350),
    "hyderabad":  (25.3960, 68.3578),
    "sialkot":    (32.4945, 74.5229),
    # Sindh
    "sukkur":     (27.7136, 68.8420),
    "larkana":    (27.5590, 68.2123),
    "dadu":       (26.7320, 67.7770),
    "mirpur khas": (25.5276, 69.0143),
    "nawabshah":  (26.2442, 68.4100),
    "shikarpur":  (27.9556, 68.6383),
    "jacobabad":  (28.2828, 68.4376),
    "thatta":     (24.7468, 67.9237),
    "badin":      (24.6562, 68.8378),
    "tharparkar": (24.8050, 70.0750),
    # KPK
    "mardan":     (34.1989, 72.0231),
    "mingora":    (34.7796, 72.3617),
    "abbottabad": (34.1463, 73.2117),
    "mansehra":   (34.3398, 73.1981),
    "kohat":      (33.5870, 71.4432),
    "bannu":      (32.9889, 70.6011),
    "dera ismail khan": (31.8313, 70.9020),
    "chitral":    (35.8514, 71.7886),
    # Balochistan
    "gwadar":     (25.1264, 62.3225),
    "turbat":     (26.0031, 63.0544),
    "khuzdar":    (27.8120, 66.6160),
    "chaman":     (30.9221, 66.4525),
    # AJK / GB
    "muzaffarabad": (34.3700, 73.4710),
    "mirpur":     (33.1478, 73.7517),
    "gilgit":     (35.9221, 74.3087),
    "skardu":     (35.3017, 75.6311),
    # Punjab
    "gujranwala": (32.1877, 74.1945),
    "gujrat":     (32.5731, 74.0750),
    "sargodha":   (32.0836, 72.6711),
    "sahiwal":    (30.6682, 73.1114),
    "bahawalpur": (29.3956, 71.6836),
    "sheikhupura": (31.7167, 73.9850),
    "kasur":      (31.1156, 74.4500),
    "okara":      (30.8138, 73.4534),
    "rahim yar khan": (28.4202, 70.2952),
    "dera ghazi khan": (30.0489, 70.6455),
}


async def find_nearest_hospitals(city: str, lat: float = None, lon: float = None, limit: int = 5) -> List[Dict]:
    """Find nearest hospitals/clinics using Geoapify Places API."""
    if not GEOAPIFY_KEY:
        return _mock_hospitals(city)

    if lat is None or lon is None:
        coords = CITY_COORDS.get(city.lower())
        if not coords:
            return _mock_hospitals(city)
        lat, lon = coords

    try:
        async with httpx.AsyncClient(timeout=8.0) as client:
            resp = await client.get(
                "https://api.geoapify.com/v2/places",
                params={
                    "categories": "healthcare.hospital,healthcare.clinic,healthcare.emergency",
                    "filter":     f"circle:{lon},{lat},10000",
                    "bias":       f"proximity:{lon},{lat}",
                    "limit":      limit,
                    "apiKey":     GEOAPIFY_KEY,
                }
            )
            resp.raise_for_status()
            data = resp.json()

        hospitals = []
        for f in data.get("features", []):
            p = f.get("properties", {})
            g = f.get("geometry", {}).get("coordinates", [lon, lat])
            hospitals.append({
                "name":     p.get("name", "Hospital"),
                "address":  p.get("formatted", p.get("address_line2", "")),
                "lat":      g[1],
                "lon":      g[0],
                "type":     p.get("categories", ["hospital"])[0].split(".")[-1],
                "distance_km": round(p.get("distance", 0) / 1000, 2),
            })
        return hospitals if hospitals else _mock_hospitals(city)

    except Exception as e:
        print(f"[GEOAPIFY] Hospital search failed: {e}")
        return _mock_hospitals(city)


async def get_route(from_lat: float, from_lon: float, to_lat: float, to_lon: float, mode: str = "drive") -> Dict:
    """Calculate route between two points using Geoapify Routing API."""
    if not GEOAPIFY_KEY:
        return _mock_route(from_lat, from_lon, to_lat, to_lon)

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(
                "https://api.geoapify.com/v1/routing",
                params={
                    "waypoints": f"{from_lat},{from_lon}|{to_lat},{to_lon}",
                    "mode":      mode,
                    "apiKey":    GEOAPIFY_KEY,
                }
            )
            resp.raise_for_status()
            data = resp.json()

        features = data.get("features", [])
        if not features:
            return _mock_route(from_lat, from_lon, to_lat, to_lon)

        props = features[0].get("properties", {})
        legs  = props.get("legs", [{}])
        geom  = features[0].get("geometry", {})

        distance_km = round(sum(l.get("distance", 0) for l in legs) / 1000, 2)
        time_min    = round(sum(l.get("time", 0) for l in legs) / 60, 1)

        # Extract polyline coordinates
        coords = []
        if geom.get("type") == "MultiLineString":
            for line in geom.get("coordinates", []):
                coords.extend([{"lat": c[1], "lon": c[0]} for c in line])
        elif geom.get("type") == "LineString":
            coords = [{"lat": c[1], "lon": c[0]} for c in geom.get("coordinates", [])]

        return {
            "distance_km": distance_km,
            "time_minutes": time_min,
            "polyline":    coords[:50],  # limit for frontend
            "mode":        mode,
        }

    except Exception as e:
        print(f"[GEOAPIFY] Routing failed: {e}")
        return _mock_route(from_lat, from_lon, to_lat, to_lon)


async def find_nearest_facilities(category: str, lat: float, lon: float, limit: int = 3) -> List[Dict]:
    """Find nearest facilities of a given Geoapify category."""
    if not GEOAPIFY_KEY:
        return []
    try:
        async with httpx.AsyncClient(timeout=8.0) as client:
            resp = await client.get(
                "https://api.geoapify.com/v2/places",
                params={
                    "categories": category,
                    "filter":     f"circle:{lon},{lat},15000",
                    "bias":       f"proximity:{lon},{lat}",
                    "limit":      limit,
                    "apiKey":     GEOAPIFY_KEY,
                }
            )
            resp.raise_for_status()
            data = resp.json()

        out = []
        for f in data.get("features", []):
            p = f.get("properties", {})
            g = f.get("geometry", {}).get("coordinates", [lon, lat])
            out.append({
                "name":        p.get("name", category.split(".")[-1].title()),
                "address":     p.get("formatted", p.get("address_line2", "")),
                "lat":         g[1],
                "lon":         g[0],
                "category":    category.split(".")[-1],
                "distance_km": round(p.get("distance", 0) / 1000, 2),
            })
        return out
    except Exception:
        return []


async def get_crisis_context(city: str, crisis_type: str, lat: float = None, lon: float = None) -> Dict:
    """Full crisis context: hospitals + shelters + police + fire stations + routes."""
    import asyncio

    coords = CITY_COORDS.get(city.lower(), (33.6938, 73.0652))
    clat, clon = (lat or coords[0], lon or coords[1])

    # Parallel fetch of all facility types
    hospitals_task = find_nearest_hospitals(city, clat, clon, limit=3)
    shelters_task  = find_nearest_facilities("building.school,leisure.community_centre", clat, clon, limit=3)
    police_task    = find_nearest_facilities("service.police", clat, clon, limit=2)
    fire_task      = find_nearest_facilities("emergency.fire_station,service.vehicle.fuel", clat, clon, limit=2)

    hospitals, shelters, police, fire = await asyncio.gather(
        hospitals_task, shelters_task, police_task, fire_task
    )

    # Fallback shelters if Geoapify returns nothing
    if not shelters:
        shelters = _mock_shelters(city, clat, clon)
    if not police:
        police = _mock_police(city, clat, clon)
    if not fire:
        fire = _mock_fire(city, clat, clon)

    # Calculate routes from crisis point to nearest 2 hospitals + nearest shelter
    routes = []
    for h in hospitals[:2]:
        route = await get_route(clat, clon, h["lat"], h["lon"])
        route["destination"] = h["name"]
        route["destination_type"] = "hospital"
        route["destination_address"] = h["address"]
        routes.append(route)
    if shelters:
        s = shelters[0]
        route = await get_route(clat, clon, s["lat"], s["lon"])
        route["destination"] = s["name"]
        route["destination_type"] = "shelter"
        route["destination_address"] = s["address"]
        routes.append(route)

    return {
        "crisis_location":     {"lat": clat, "lon": clon, "city": city},
        "nearest_hospitals":   hospitals,
        "nearest_shelters":    shelters,
        "nearest_police":      police,
        "nearest_fire_stations": fire,
        "emergency_routes":    routes,
        "city_coords":         {"lat": clat, "lon": clon},
    }


def _mock_shelters(city: str, lat: float, lon: float) -> List[Dict]:
    return [
        {"name": f"{city.title()} Govt. Boys High School (Shelter)", "address": f"Main Road, {city}", "lat": lat + 0.012, "lon": lon - 0.009, "category": "shelter", "distance_km": 1.6},
        {"name": f"{city.title()} Community Centre", "address": f"Sector C, {city}", "lat": lat - 0.008, "lon": lon + 0.011, "category": "shelter", "distance_km": 1.2},
    ]


def _mock_police(city: str, lat: float, lon: float) -> List[Dict]:
    return [
        {"name": f"{city.title()} Police Station", "address": f"PS Main, {city}", "lat": lat + 0.005, "lon": lon + 0.007, "category": "police", "distance_km": 0.9},
    ]


def _mock_fire(city: str, lat: float, lon: float) -> List[Dict]:
    return [
        {"name": f"{city.title()} Rescue 1122 Fire Station", "address": f"Emergency Wing, {city}", "lat": lat - 0.006, "lon": lon - 0.004, "category": "fire_station", "distance_km": 0.8},
    ]


def _mock_hospitals(city: str) -> List[Dict]:
    hospitals_by_city = {
        "karachi":   [
            {"name": "Jinnah Postgraduate Medical Centre", "address": "Rafiqui H.J. Shaheed Road, Karachi", "lat": 24.8697, "lon": 67.0100, "type": "hospital", "distance_km": 1.2},
            {"name": "Aga Khan University Hospital",        "address": "Stadium Road, Karachi",              "lat": 24.8918, "lon": 67.0669, "type": "hospital", "distance_km": 2.8},
            {"name": "Civil Hospital Karachi",              "address": "Baba-e-Urdu Road, Karachi",          "lat": 24.8615, "lon": 67.0099, "type": "hospital", "distance_km": 0.9},
        ],
        "lahore":    [
            {"name": "Mayo Hospital",                        "address": "Nila Gumbad, Lahore",               "lat": 31.5642, "lon": 74.3180, "type": "hospital", "distance_km": 1.5},
            {"name": "Services Hospital Lahore",             "address": "Jail Road, Lahore",                 "lat": 31.5369, "lon": 74.3160, "type": "hospital", "distance_km": 2.1},
        ],
        "islamabad": [
            {"name": "Pakistan Institute of Medical Sciences","address": "G-8/3, Islamabad",                 "lat": 33.6938, "lon": 73.0145, "type": "hospital", "distance_km": 1.0},
            {"name": "Polyclinic Hospital",                  "address": "G-6/2, Islamabad",                 "lat": 33.7215, "lon": 73.0875, "type": "hospital", "distance_km": 1.8},
        ],
    }
    return hospitals_by_city.get(city.lower(), [
        {"name": "District Headquarters Hospital", "address": f"Main Road, {city}", "lat": CITY_COORDS.get(city.lower(), (33.6, 73.0))[0], "lon": CITY_COORDS.get(city.lower(), (33.6, 73.0))[1], "type": "hospital", "distance_km": 1.5},
    ])


def _mock_route(flat, flon, tlat, tlon) -> Dict:
    import math
    dist = round(math.sqrt((tlat - flat)**2 + (tlon - flon)**2) * 111, 2)
    return {
        "distance_km":  dist,
        "time_minutes": round(dist * 3, 1),
        "polyline":     [{"lat": flat, "lon": flon}, {"lat": tlat, "lon": tlon}],
        "mode":         "drive",
    }
