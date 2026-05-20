"""
SAHARA AI — Live Pakistani News Service
Fetches real news from Pakistani outlets via RSS/XML feeds.
No API key required — RSS is public and free.
Filters articles for crisis-relevant content.
"""

import asyncio
import xml.etree.ElementTree as ET
from datetime import datetime
from typing import List, Dict, Any
import httpx
import re

# ─── Pakistani News RSS Feeds (all free, no key) ────────────────
NEWS_FEEDS = [
    {"name": "Dawn News",        "url": "https://www.dawn.com/feeds/home",           "source": "news_agency"},
    {"name": "Geo TV",           "url": "https://www.geo.tv/rss/1/top-stories",      "source": "news_agency"},
    {"name": "Express Tribune",  "url": "https://tribune.com.pk/feed",               "source": "news_agency"},
    {"name": "ARY News",         "url": "https://arynews.tv/feed/",                  "source": "news_agency"},
    {"name": "The News",         "url": "https://www.thenews.com.pk/rss/1/16",       "source": "news_agency"},
]

# ─── Crisis keyword banks ────────────────────────────────────────
CRISIS_KEYWORDS = {
    "FLOODING":            ["flood", "flooding", "inundation", "waterlogged", "pani bhar", "baarish",
                            "heavy rain", "downpour", "sewage overflow", "drain burst", "nullah overflow",
                            "سیلاب", "بارش", "پانی"],
    "HEATWAVE":            ["heatwave", "heat wave", "scorching", "temperature", "heat stroke", "lу",
                            "extreme heat", "hot weather", "garmi", "گرمی", "لُو"],
    "TRAFFIC_ACCIDENT":    ["accident", "crash", "collision", "road accident", "fatal accident",
                            "car accident", "bus accident", "motorway", "hadsa", "حادثہ"],
    "INFRASTRUCTURE":      ["power outage", "load shedding", "electricity breakdown", "gas shortage",
                            "bridge collapse", "building collapse", "road damaged", "بجلی", "گیس"],
    "FIRE":                ["fire", "blaze", "inferno", "arson", "factory fire", "building fire",
                            "wildfire", "aag", "آگ", "آتشزدگی"],
    "EARTHQUAKE":          ["earthquake", "tremor", "seismic", "quake", "زلزلہ"],
}

ALL_CRISIS_KEYWORDS = [kw for kws in CRISIS_KEYWORDS.values() for kw in kws]

# City mention patterns
PAKISTAN_CITIES = {
    "islamabad": ["islamabad", "isb", "rawalpindi", "pindi", "g-10", "f-7", "i-8", "اسلام آباد"],
    "karachi":   ["karachi", "khi", "saddar", "clifton", "gulshan", "کراچی"],
    "lahore":    ["lahore", "lhr", "gulberg", "dha lahore", "canal road", "لاہور"],
    "peshawar":  ["peshawar", "pesh", "پشاور"],
    "quetta":    ["quetta", "کوئٹہ"],
    "multan":    ["multan", "ملتان"],
    "faisalabad":["faisalabad", "fsd", "فیصل آباد"],
}


def _detect_city(text: str) -> str:
    """Extract the most likely city from text."""
    text_lower = text.lower()
    for city, patterns in PAKISTAN_CITIES.items():
        if any(p in text_lower for p in patterns):
            return city.title() + ", Pakistan"
    return "Pakistan"


def _detect_crisis_type(text: str) -> str:
    """Classify the crisis type from text."""
    text_lower = text.lower()
    for crisis_type, keywords in CRISIS_KEYWORDS.items():
        if any(kw in text_lower for kw in keywords):
            return crisis_type
    return None


def _clean_html(text: str) -> str:
    """Strip HTML tags from text."""
    return re.sub(r"<[^>]+>", "", text or "").strip()


def _parse_rss(xml_text: str, feed_name: str, source_type: str) -> List[Dict[str, Any]]:
    """Parse RSS XML and return crisis-relevant news items."""
    items = []
    try:
        root = ET.fromstring(xml_text)
    except ET.ParseError:
        return items

    for item in root.iter("item"):
        title = _clean_html(item.findtext("title") or "")
        description = _clean_html(item.findtext("description") or "")
        link = item.findtext("link") or ""
        pub_date = item.findtext("pubDate") or datetime.utcnow().isoformat()

        full_text = f"{title}. {description}"

        # Only include crisis-relevant items
        crisis_type = _detect_crisis_type(full_text)
        if not crisis_type:
            continue

        # Build a natural-language signal from the headline
        signal_text = title if len(title) > 20 else f"{title}. {description[:150]}"
        city_hint = _detect_city(full_text)

        items.append({
            "id":           f"news_{hash(title) % 100000:05d}",
            "text":         signal_text[:280],
            "source":       source_type,
            "origin":       feed_name,
            "crisis_type":  crisis_type,
            "city":         city_hint,
            "location_hint":city_hint,
            "link":         link,
            "timestamp":    datetime.utcnow().isoformat(),
            "language":     "english",
            "is_real":      True,
        })

    return items[:5]   # max 5 items per feed to avoid flooding the queue


async def fetch_news_signals(max_items: int = 20) -> List[Dict[str, Any]]:
    """
    Fetch live crisis news from all Pakistani RSS feeds in parallel.
    Returns up to max_items crisis-relevant news items.
    """
    all_items: List[Dict[str, Any]] = []

    async def _fetch_feed(feed: dict):
        try:
            async with httpx.AsyncClient(timeout=8.0, follow_redirects=True,
                                          headers={"User-Agent": "SAHARA-AI/2.0 crisis-monitor"}) as client:
                resp = await client.get(feed["url"])
                if resp.status_code == 200:
                    return _parse_rss(resp.text, feed["name"], feed["source"])
        except Exception:
            pass
        return []

    results = await asyncio.gather(*[_fetch_feed(f) for f in NEWS_FEEDS], return_exceptions=True)
    for batch in results:
        if isinstance(batch, list):
            all_items.extend(batch)

    # Deduplicate by text similarity (simple)
    seen = set()
    unique = []
    for item in all_items:
        key = item["text"][:60].lower().strip()
        if key not in seen:
            seen.add(key)
            unique.append(item)

    return unique[:max_items]


async def fetch_weather_signals() -> List[Dict[str, Any]]:
    """
    Generate weather-sourced signals from real OpenWeatherMap data.
    Returns signals only when weather conditions are crisis-level.
    """
    from services.weather_service import get_all_city_weather

    signals = []
    weather_map = await get_all_city_weather()

    for city, w in weather_map.items():
        if not w.get("available"):
            continue
        alert = w.get("alert", "NONE")
        if alert == "NONE":
            continue

        temp = w.get("temperature_c", 30)
        rain = w.get("rainfall_mm_last_3h", 0)
        desc = w.get("alert_description", "")
        source_name = w.get("source", "weather_api")

        # Build human-readable signal text
        if alert == "HEAVY_RAIN":
            text = f"Weather alert for {city.title()}: {desc} Rainfall {rain}mm in last 3 hours. Flash flood advisory active."
            crisis_type = "FLOODING"
        elif alert == "EXTREME_HEAT":
            text = f"Heatwave alert for {city.title()}: {desc} Temperature {temp}°C. Authorities urge public to stay indoors."
            crisis_type = "HEATWAVE"
        elif alert == "STORM":
            text = f"Storm warning for {city.title()}: {desc} Infrastructure damage possible."
            crisis_type = "INFRASTRUCTURE"
        else:
            continue

        signals.append({
            "id":           f"wx_{city}_{int(datetime.utcnow().timestamp())}",
            "text":         text,
            "source":       "weather_api",
            "origin":       source_name,
            "crisis_type":  crisis_type,
            "city":         city.title() + ", Pakistan",
            "location_hint": city.title() + ", Pakistan",
            "timestamp":    datetime.utcnow().isoformat(),
            "language":     "english",
            "is_real":      True,
            "weather_data": w,
        })

    return signals


async def get_all_live_signals(max_items: int = 25) -> List[Dict[str, Any]]:
    """Combine news + weather signals into a single live feed."""
    news_task    = asyncio.create_task(fetch_news_signals(max_items))
    weather_task = asyncio.create_task(fetch_weather_signals())

    news_signals, weather_signals = await asyncio.gather(news_task, weather_task)

    # Weather signals go first (most reliable)
    combined = weather_signals + news_signals
    return combined[:max_items]
