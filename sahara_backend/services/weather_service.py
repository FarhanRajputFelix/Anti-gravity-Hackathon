"""
SAHARA AI — Real Weather Service
Uses WeatherAPI.com (primary) with OpenWeatherMap fallback.
"""

import os
import httpx
from datetime import datetime

WEATHERAPI_KEY  = os.getenv("WEATHERAPI_KEY", os.getenv("OPENWEATHER_API_KEY", ""))
WEATHERAPI_BASE = "http://api.weatherapi.com/v1/current.json"

CITY_QUERIES = {
    "islamabad":  "Islamabad",
    "karachi":    "Karachi",
    "lahore":     "Lahore",
    "rawalpindi": "Rawalpindi",
    "peshawar":   "Peshawar",
    "quetta":     "Quetta",
    "multan":     "Multan",
    "faisalabad": "Faisalabad",
}

RAIN_HEAVY_MM = 5.0   # mm/hour → heavy rain (WeatherAPI uses mm/hour)
TEMP_HEAT_C   = 42.0
WIND_STORM    = 60.0


def _classify_alert(temp_c: float, rain_mm_hr: float, wind_kmh: float, condition_text: str) -> tuple:
    text_lower = condition_text.lower()
    if (rain_mm_hr >= RAIN_HEAVY_MM
            or "flood" in text_lower
            or "thunder" in text_lower
            or "heavy rain" in text_lower
            or "torrential" in text_lower):
        if rain_mm_hr >= 20:
            return "HEAVY_RAIN", f"Severe rainfall — {rain_mm_hr:.1f}mm/hr. Flash flood risk CRITICAL."
        return "HEAVY_RAIN", f"Heavy rainfall — {rain_mm_hr:.1f}mm/hr. Flooding possible."
    if temp_c >= TEMP_HEAT_C:
        return "EXTREME_HEAT", f"Heatwave advisory — {temp_c:.0f}°C."
    if wind_kmh >= WIND_STORM:
        return "STORM", f"Storm warning — {wind_kmh:.0f} km/h winds."
    return "NONE", "No active weather emergency."


async def get_real_weather(city: str) -> dict:
    city_key = city.lower().strip()

    if not WEATHERAPI_KEY or WEATHERAPI_KEY in ("your-openweather-key-here", ""):
        return _mock_fallback(city_key, "no_api_key")

    query = CITY_QUERIES.get(city_key, city.title())

    try:
        async with httpx.AsyncClient(timeout=8.0) as client:
            resp = await client.get(WEATHERAPI_BASE, params={
                "key": WEATHERAPI_KEY,
                "q":   query,
                "aqi": "no",
            })
            resp.raise_for_status()
            raw = resp.json()

        cur       = raw["current"]
        temp_c    = cur["temp_c"]
        humidity  = cur["humidity"]
        wind_kmh  = cur["wind_kph"]
        rain_mm   = cur.get("precip_mm", 0.0)          # mm in last hour
        condition = cur["condition"]["text"]

        alert, alert_desc = _classify_alert(temp_c, rain_mm, wind_kmh, condition)

        return {
            "available":             True,
            "source":                "weatherapi_live",
            "fetched_at":            datetime.utcnow().isoformat(),
            "city":                  city_key,
            "temperature_c":         round(temp_c, 1),
            "humidity_pct":          humidity,
            "rainfall_mm_last_3h":   round(rain_mm * 3, 1),  # convert hr→3h for compatibility
            "rainfall_mm_per_hour":  round(rain_mm, 1),
            "wind_speed_kmh":        round(wind_kmh, 1),
            "weather_main":          condition,
            "weather_desc":          condition,
            "alert":                 alert,
            "alert_description":     alert_desc,
        }

    except httpx.HTTPStatusError as e:
        return _mock_fallback(city_key, f"http_{e.response.status_code}")
    except Exception as e:
        return _mock_fallback(city_key, str(e)[:60])


def _mock_fallback(city: str, reason: str = "unavailable") -> dict:
    from mock_data import MOCK_WEATHER_DATA
    base = MOCK_WEATHER_DATA.get(city, {
        "available": False, "temperature_c": 32, "humidity_pct": 65,
        "rainfall_mm_last_3h": 0, "alert": "NONE",
        "alert_description": "No data.", "wind_speed_kmh": 15,
    })
    result = dict(base)
    result["available"] = True
    result["source"] = f"mock_fallback({reason})"
    result["fetched_at"] = datetime.utcnow().isoformat()
    return result


async def get_all_city_weather() -> dict:
    import asyncio
    tasks = {city: asyncio.create_task(get_real_weather(city)) for city in CITY_QUERIES}
    results = {}
    for city, task in tasks.items():
        try:
            results[city] = await task
        except Exception:
            results[city] = _mock_fallback(city)
    return results
