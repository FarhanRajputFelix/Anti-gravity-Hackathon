"""
SAHARA AI — Mock Data
Realistic Pakistani crisis scenarios and simulated API responses.
"""

from typing import Dict, Any, List

# ─────────────────────────────────────────
# PRESET DEMO SCENARIOS
# ─────────────────────────────────────────

DEMO_SCENARIOS = {
    "islamabad_flood": {
        "text": "G-10 mein pani bhar gaya hai, gaariyan phans gayi hain aur logon ke ghar zabardast baarish ki wajah se doob rahe hain. Rescue ki zaroorat hai!",
        "source": "citizen_report",
        "location_hint": "G-10, Islamabad",
        "description": "Islamabad Urban Flooding — G-10 Sector",
    },
    "karachi_heatwave": {
        "text": "Severe heatwave warning for Karachi. Temperature reaching 48°C. Multiple heat stroke cases reported near Saddar area. Hospitals running out of beds.",
        "source": "weather_api",
        "location_hint": "Saddar, Karachi",
        "description": "Karachi Extreme Heatwave",
    },
    "lahore_accident": {
        "text": "Bada accident hua hai Shahrah-e-Quaid-e-Azam pe. Teen gaariyan takra gayi hain, road completely block hai. Ambulance aur traffic police chahiye.",
        "source": "social_media",
        "location_hint": "Shahrah-e-Quaid-e-Azam, Lahore",
        "description": "Lahore Major Traffic Accident",
    },
}

# ─────────────────────────────────────────
# MOCK WEATHER API RESPONSES
# ─────────────────────────────────────────

MOCK_WEATHER_DATA: Dict[str, Any] = {
    "islamabad": {
        "available": True,
        "temperature_c": 28,
        "humidity_pct": 92,
        "rainfall_mm_last_3h": 87.3,
        "alert": "HEAVY_RAIN",
        "alert_description": "Severe thunderstorm with flash flood warning issued by PMD",
        "wind_speed_kmh": 45,
    },
    "karachi": {
        "available": True,
        "temperature_c": 48,
        "humidity_pct": 35,
        "rainfall_mm_last_3h": 0,
        "alert": "EXTREME_HEAT",
        "alert_description": "Red heat advisory — feels like 52°C with heat index",
        "wind_speed_kmh": 12,
    },
    "lahore": {
        "available": True,
        "temperature_c": 34,
        "humidity_pct": 55,
        "rainfall_mm_last_3h": 2.1,
        "alert": "NONE",
        "alert_description": "No weather emergency. Partly cloudy.",
        "wind_speed_kmh": 18,
    },
}

# ─────────────────────────────────────────
# MOCK TRAFFIC API RESPONSES
# ─────────────────────────────────────────

MOCK_TRAFFIC_DATA: Dict[str, Any] = {
    "islamabad": {
        "available": True,
        "congestion_index": 87,  # 0-100
        "incident_reports": 14,
        "blocked_roads": ["Srinagar Highway", "G-10 Markaz Road", "Murree Road near G-9"],
        "avg_speed_kmh": 8,
        "normal_avg_speed_kmh": 45,
        "status": "SEVERE_CONGESTION",
    },
    "karachi": {
        "available": True,
        "congestion_index": 72,
        "incident_reports": 8,
        "blocked_roads": ["Shahrah-e-Faisal (partial)", "M.A. Jinnah Road"],
        "avg_speed_kmh": 14,
        "normal_avg_speed_kmh": 40,
        "status": "HIGH_CONGESTION",
    },
    "lahore": {
        "available": False,  # Simulates API failure for fallback demo
        "error": "Traffic API endpoint timeout after 30s",
        "congestion_index": None,
        "incident_reports": None,
        "blocked_roads": [],
        "status": "API_UNAVAILABLE",
    },
}

# Historical fallback traffic patterns
HISTORICAL_TRAFFIC_PATTERNS: Dict[str, Any] = {
    "lahore": {
        "typical_congestion_Shahrah-e-Quaid-e-Azam": 65,
        "typical_incident_rate_per_week": 12,
        "peak_hours": ["08:00-10:00", "17:00-20:00"],
        "note": "Historical data from last 90 days — accuracy ±15%",
    }
}

# ─────────────────────────────────────────
# MOCK SOCIAL MEDIA / CITIZEN REPORTS
# ─────────────────────────────────────────

RECENT_SIGNAL_FEED: List[Dict[str, Any]] = [
    {
        "id": "sig_001",
        "text": "G-10 mein pani bhar gaya hai, gaariyan phans gayi hain",
        "source": "citizen_report",
        "city": "islamabad",
        "timestamp": "2026-05-15T08:10:00Z",
        "language": "roman_urdu",
    },
    {
        "id": "sig_002",
        "text": "Karachi mein garmi se logon ka bura haal hai. 3 log hospital mein daakhil.",
        "source": "social_media",
        "city": "karachi",
        "timestamp": "2026-05-15T08:05:00Z",
        "language": "roman_urdu",
    },
    {
        "id": "sig_003",
        "text": "Accident on Shahrah-e-Quaid-e-Azam blocking all lanes",
        "source": "traffic_api",
        "city": "lahore",
        "timestamp": "2026-05-15T07:58:00Z",
        "language": "english",
    },
    {
        "id": "sig_004",
        "text": "PMD issues flash flood warning for Rawalpindi/Islamabad region",
        "source": "weather_api",
        "city": "islamabad",
        "timestamp": "2026-05-15T07:45:00Z",
        "language": "english",
    },
    {
        "id": "sig_005",
        "text": "اسلام آباد میں جی ٹین سیکٹر میں سیلاب کا خدشہ، شہری محفوظ مقامات پر منتقل ہوں",
        "source": "news_agency",
        "city": "islamabad",
        "timestamp": "2026-05-15T07:30:00Z",
        "language": "urdu",
    },
]

# ─────────────────────────────────────────
# LOCATION COORDINATES (for map overlay)
# ─────────────────────────────────────────

LOCATION_COORDS: Dict[str, Dict[str, float]] = {
    "islamabad": {"lat": 33.6844, "lng": 73.0479},
    "karachi": {"lat": 24.8607, "lng": 67.0011},
    "lahore": {"lat": 31.5204, "lng": 74.3587},
    "G-10": {"lat": 33.6938, "lng": 73.0145},
    "Saddar": {"lat": 24.8608, "lng": 67.0104},
    "Shahrah-e-Quaid-e-Azam": {"lat": 31.5563, "lng": 74.3194},
}

# Crisis-specific map data
MAP_CRISIS_DATA: Dict[str, Any] = {
    "islamabad_flood": {
        "center": {"lat": 33.6938, "lng": 73.0145},
        "crisis_markers": [
            {"lat": 33.6938, "lng": 73.0145, "type": "FLOOD", "severity": "CRITICAL", "label": "G-10 Flood Zone"},
            {"lat": 33.7086, "lng": 73.0478, "type": "FLOOD", "severity": "HIGH", "label": "Srinagar Hwy Overflow"},
        ],
        "blocked_roads": [
            {"start": {"lat": 33.6938, "lng": 73.0145}, "end": {"lat": 33.7050, "lng": 73.0290}, "label": "G-10 Markaz Rd"},
        ],
        "reroute_paths": [
            {"path": [{"lat": 33.6938, "lng": 73.0145}, {"lat": 33.6800, "lng": 73.0000}, {"lat": 33.6750, "lng": 72.9900}], "label": "Alt Route via I-8"},
        ],
        "emergency_dispatch": [
            {"from": {"lat": 33.7200, "lng": 73.0600}, "to": {"lat": 33.6938, "lng": 73.0145}, "unit": "Rescue 1151"},
        ],
        "alert_zone": {"center": {"lat": 33.6938, "lng": 73.0145}, "radius_m": 2500},
    },
    "karachi_heatwave": {
        "center": {"lat": 24.8608, "lng": 67.0104},
        "crisis_markers": [
            {"lat": 24.8608, "lng": 67.0104, "type": "HEATWAVE", "severity": "CRITICAL", "label": "Saddar Heat Zone"},
            {"lat": 24.8950, "lng": 67.0280, "type": "HEATWAVE", "severity": "HIGH", "label": "Gulshan Hospital Overflow"},
        ],
        "blocked_roads": [],
        "reroute_paths": [],
        "emergency_dispatch": [
            {"from": {"lat": 24.9056, "lng": 67.0822}, "to": {"lat": 24.8608, "lng": 67.0104}, "unit": "Edhi Ambulance #24"},
        ],
        "alert_zone": {"center": {"lat": 24.8607, "lng": 67.0011}, "radius_m": 8000},
    },
    "lahore_accident": {
        "center": {"lat": 31.5563, "lng": 74.3194},
        "crisis_markers": [
            {"lat": 31.5563, "lng": 74.3194, "type": "ACCIDENT", "severity": "HIGH", "label": "Multi-vehicle Collision"},
        ],
        "blocked_roads": [
            {"start": {"lat": 31.5550, "lng": 74.3180}, "end": {"lat": 31.5580, "lng": 74.3210}, "label": "Shahrah-e-Quaid-e-Azam"},
        ],
        "reroute_paths": [
            {"path": [{"lat": 31.5550, "lng": 74.3180}, {"lat": 31.5480, "lng": 74.3100}, {"lat": 31.5400, "lng": 74.3050}], "label": "Alt Route via Canal Rd"},
        ],
        "emergency_dispatch": [
            {"from": {"lat": 31.5800, "lng": 74.3400}, "to": {"lat": 31.5563, "lng": 74.3194}, "unit": "Rescue 1122"},
        ],
        "alert_zone": {"center": {"lat": 31.5563, "lng": 74.3194}, "radius_m": 1200},
    },
}
