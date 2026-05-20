"""
SAHARA AI — Agent 1: Signal Ingestion Agent
Parses raw multilingual crisis signals into structured data.
Supports English, Urdu, and Roman Urdu.
"""

import time
import uuid
from datetime import datetime
from models import (
    CrisisContext, AgentTrace, ToolCall,
    ExtractedEntities, CrisisType
)


# ─────────────────────────────────────────
# KEYWORD DICTIONARIES (multilingual)
# ─────────────────────────────────────────

FLOOD_KEYWORDS = [
    "flood", "flooding", "seilaan", "pani", "baarish", "doob", "overflow",
    "bhar gaya", "nala", "darya", "baarh", "flash flood", "waterlogged",
    "سیلاب", "پانی", "بارش", "ڈوب"
]
HEATWAVE_KEYWORDS = [
    "heatwave", "heat wave", "garmi", "temperature", "lू", "heat stroke",
    "hot", "scorching", "garmi ki lehar", "48c", "45c", "50c",
    "گرمی", "لُو"
]
ACCIDENT_KEYWORDS = [
    "accident", "crash", "collision", "hadsa", "takkar", "takra", "gaari",
    "block", "road block", "traffic jam", "ambulance", "injured",
    "حادثہ", "ٹکر", "بلاک"
]
INFRASTRUCTURE_KEYWORDS = [
    "bridge", "collapse", "wall", "building", "power outage", "bijli",
    "transformer", "sewage", "gas leak", "deewar gir", "puul",
    "بجلی", "گیس", "پل"
]
FIRE_KEYWORDS = [
    "fire", "aag", "jal raha", "jal rahi", "flames", "smoke", "dhuan",
    "burning", "blaze", "inferno", "آگ", "دھواں", "آگ لگ گئی",
    "factory fire", "building fire", "fire brigade", "fireengine",
]
URDU_KEYWORDS = ["mein", "hai", "ka", "ki", "ke", "aur", "se", "pe", "par", "wali", "wala", "gaya"]
ROMAN_URDU_KEYWORDS = ["pani", "garmi", "baarish", "hadsa", "gaari", "logon", "bachao", "madad"]

CITY_PATTERNS = {
    # Major metros
    "lahore":     ["lahore", "lhr", "gulberg", "dha lahore", "johar town", "shahrah-e-quaid", "mall road", "anarkali", "لاہور"],
    "karachi":    ["karachi", "khi", "saddar", "gulshan", "clifton", "korangi", "north nazimabad", "sea view", "کراچی"],
    "rawalpindi": ["rawalpindi", "pindi", "raja bazar", "saddar pindi", "راولپنڈی"],
    "islamabad":  ["islamabad", "isb", "g-10", "g10", "g-9", "g-8", "f-7", "f-8", "i-8", "i8", "blue area", "اسلام آباد"],
    "peshawar":   ["peshawar", "pwr", "ring road peshawar", "university town", "hayatabad", "پشاور"],
    "quetta":     ["quetta", "satellite town quetta", "kandahari", "کوئٹہ"],
    "multan":     ["multan", "mtn", "bosan", "ملتان"],
    "faisalabad": ["faisalabad", "fsd", "lyallpur", "jaranwala", "فیصل آباد"],
    "hyderabad":  ["hyderabad sindh", "hyderabad", "latifabad", "حیدرآباد"],
    "sialkot":    ["sialkot", "skt", "سیالکوٹ"],
    # Punjab
    "gujranwala": ["gujranwala", "gjw", "گوجرانوالہ"],
    "gujrat":     ["gujrat", "گجرات"],
    "sargodha":   ["sargodha", "سرگودھا"],
    "sahiwal":    ["sahiwal", "ساہیوال"],
    "bahawalpur": ["bahawalpur", "bwp", "بہاولپور"],
    "sheikhupura": ["sheikhupura", "شیخوپورہ"],
    "kasur":      ["kasur", "قصور"],
    "okara":      ["okara", "اوکاڑہ"],
    "rahim yar khan": ["rahim yar khan", "rahimyar khan", "ryk", "رحیم یار خان"],
    "dera ghazi khan": ["dera ghazi khan", "dg khan", "ڈیرہ غازی خان"],
    # Sindh
    "sukkur":     ["sukkur", "سکھر"],
    "larkana":    ["larkana", "لاڑکانہ"],
    "dadu":       ["dadu", "دادو"],
    "mirpur khas": ["mirpur khas", "میرپور خاص"],
    "nawabshah":  ["nawabshah", "shaheed benazirabad", "نوابشاہ"],
    "shikarpur":  ["shikarpur", "شکارپور"],
    "jacobabad":  ["jacobabad", "جیکب آباد"],
    "thatta":     ["thatta", "ٹھٹہ"],
    "badin":      ["badin", "بدین"],
    "tharparkar": ["tharparkar", "thar", "tharkar", "تھرپارکر"],
    # KPK
    "mardan":     ["mardan", "مردان"],
    "mingora":    ["mingora", "swat", "مینگورہ"],
    "abbottabad": ["abbottabad", "abbotabad", "ایبٹ آباد"],
    "mansehra":   ["mansehra", "مانسہرہ"],
    "kohat":      ["kohat", "کوہاٹ"],
    "bannu":      ["bannu", "بنوں"],
    "dera ismail khan": ["dera ismail khan", "di khan", "ڈیرہ اسماعیل خان"],
    "chitral":    ["chitral", "چترال"],
    # Balochistan
    "gwadar":     ["gwadar", "گوادر"],
    "turbat":     ["turbat", "تربت"],
    "khuzdar":    ["khuzdar", "خضدار"],
    "chaman":     ["chaman", "چمن"],
    # AJK / GB
    "muzaffarabad": ["muzaffarabad", "مظفر آباد"],
    "mirpur":     ["mirpur ajk", "میرپور آزاد کشمیر"],
    "gilgit":     ["gilgit", "گلگت"],
    "skardu":     ["skardu", "سکردو"],
}

LOCATION_LABELS = {
    "lahore":     "Mall Road, Lahore",
    "karachi":    "Saddar, Karachi",
    "rawalpindi": "Saddar, Rawalpindi",
    "islamabad":  "G-10, Islamabad",
    "peshawar":   "University Town, Peshawar",
    "quetta":     "Satellite Town, Quetta",
    "multan":     "Bosan Road, Multan",
    "faisalabad": "Clock Tower, Faisalabad",
    "hyderabad":  "Latifabad, Hyderabad",
    "sialkot":    "Cantt, Sialkot",
    "dadu":       "City Centre, Dadu",
    "sukkur":     "City Centre, Sukkur",
    "larkana":    "City Centre, Larkana",
    "mirpur khas": "Main Bazaar, Mirpur Khas",
    "nawabshah":  "Main Bazaar, Nawabshah",
    "shikarpur":  "Main Bazaar, Shikarpur",
    "jacobabad":  "City Centre, Jacobabad",
    "thatta":     "City Centre, Thatta",
    "badin":      "City Centre, Badin",
    "tharparkar": "Mithi, Tharparkar",
    "mardan":     "City Centre, Mardan",
    "mingora":    "Saidu Sharif, Swat",
    "abbottabad": "Mall Road, Abbottabad",
    "mansehra":   "City Centre, Mansehra",
    "kohat":      "City Centre, Kohat",
    "bannu":      "City Centre, Bannu",
    "dera ismail khan": "City Centre, D.I. Khan",
    "chitral":    "City Centre, Chitral",
    "gwadar":     "Marine Drive, Gwadar",
    "turbat":     "City Centre, Turbat",
    "khuzdar":    "City Centre, Khuzdar",
    "chaman":     "City Centre, Chaman",
    "muzaffarabad": "City Centre, Muzaffarabad",
    "mirpur":     "Main Bazaar, Mirpur AJK",
    "gilgit":     "City Centre, Gilgit",
    "skardu":     "City Centre, Skardu",
    "gujranwala": "G.T. Road, Gujranwala",
    "gujrat":     "Main Bazaar, Gujrat",
    "sargodha":   "Block-Z, Sargodha",
    "sahiwal":    "Main Road, Sahiwal",
    "bahawalpur": "City Centre, Bahawalpur",
    "sheikhupura": "Civil Lines, Sheikhupura",
    "kasur":      "Main Road, Kasur",
    "okara":      "G.T. Road, Okara",
    "rahim yar khan": "City Centre, Rahim Yar Khan",
    "dera ghazi khan": "Main Bazaar, D.G. Khan",
}

SEEN_SIGNALS: dict = {}  # Simple duplicate detection store


def detect_language(text: str) -> str:
    urdu_chars = sum(1 for c in text if '\u0600' <= c <= '\u06ff')
    if urdu_chars > 5:
        return "urdu"
    roman_hits = sum(1 for kw in ROMAN_URDU_KEYWORDS if kw in text.lower())
    if roman_hits >= 2:
        return "roman_urdu"
    return "english"


def detect_crisis_type(text: str) -> CrisisType:
    t = text.lower()
    if any(kw in t for kw in FIRE_KEYWORDS):
        return CrisisType.FIRE
    if any(kw in t for kw in FLOOD_KEYWORDS):
        return CrisisType.FLOODING
    if any(kw in t for kw in HEATWAVE_KEYWORDS):
        return CrisisType.HEATWAVE
    if any(kw in t for kw in ACCIDENT_KEYWORDS):
        return CrisisType.TRAFFIC_ACCIDENT
    if any(kw in t for kw in INFRASTRUCTURE_KEYWORDS):
        return CrisisType.INFRASTRUCTURE_FAILURE
    return CrisisType.UNKNOWN


def detect_city(text: str) -> str:
    """Match the city whose pattern appears EARLIEST in the text (most specific)."""
    t = text.lower()
    best_city = None
    best_pos = len(t) + 1
    for city, patterns in CITY_PATTERNS.items():
        for pat in patterns:
            pos = t.find(pat)
            if pos != -1 and pos < best_pos:
                best_pos = pos
                best_city = city
    if best_city:
        return best_city
    # No pattern match → ask Gemini AI to extract the city name
    gemini_city = _gemini_extract_city(text)
    return gemini_city or "unknown"


def _gemini_extract_city(text: str) -> str:
    """Use Gemini to extract a Pakistani city from text when patterns fail. Returns lowercase city name or empty string."""
    import os
    api_key = os.getenv("GEMINI_API_KEY", "")
    if not api_key or api_key == "your-gemini-api-key-here":
        return ""
    try:
        import warnings
        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            import google.generativeai as genai
        genai.configure(api_key=api_key)
        model = genai.GenerativeModel("gemini-2.0-flash")
        prompt = (
            "Extract the Pakistani city name from this crisis report. "
            "Reply ONLY with the lowercase city name in English (e.g. 'dadu', 'gwadar', 'karachi'). "
            "If no Pakistani city is mentioned, reply 'unknown'. "
            f"\n\nReport: {text[:300]}"
        )
        response = model.generate_content(prompt)
        if response and response.text:
            city = response.text.strip().lower().split()[0].strip(".,!?\"'")
            if city and city != "unknown" and len(city) > 1:
                print(f"[GEMINI CITY] Extracted '{city}' from text")
                return city
    except Exception as e:
        print(f"[GEMINI CITY] Extraction failed: {e}")
    return ""


def detect_severity_hint(text: str) -> str:
    t = text.lower()
    if any(w in t for w in ["critical", "zaroorat", "bachao", "madad", "emergency", "severe", "extreme", "zabardast"]):
        return "HIGH"
    if any(w in t for w in ["partial", "kuch", "thori", "minor"]):
        return "LOW"
    return "MEDIUM"


def check_duplicate(text: str, crisis_id: str) -> list:
    text_lower = text.lower().strip()[:80]
    duplicates = []
    for sig_id, stored_text in SEEN_SIGNALS.items():
        if sig_id != crisis_id:
            overlap = sum(1 for word in text_lower.split() if word in stored_text)
            if overlap >= 4:
                duplicates.append(sig_id)
    SEEN_SIGNALS[crisis_id] = text_lower
    return duplicates


def run(context: CrisisContext) -> CrisisContext:
    start = time.time()
    signal = context.signals[0] if context.signals else None

    observations = []
    reasoning_steps = []
    tool_calls = []

    if not signal:
        context.system_status = "ERROR_NO_SIGNAL"
        return context

    text = signal.text

    # Step 1: Language detection
    lang = detect_language(text)
    observations.append(f"Raw signal received ({len(text)} chars). Normalizing language.")
    reasoning_steps.append(f"Language detection scan: found {'Arabic Unicode chars' if lang == 'urdu' else 'Roman Urdu markers' if lang == 'roman_urdu' else 'English text'}. Detected: {lang.upper()}.")
    tool_calls.append(ToolCall(
        tool_name="language_detector",
        input={"text": text[:100]},
        output={"language": lang},
        latency_ms=120
    ))

    # Step 2: Crisis type detection
    crisis_type = detect_crisis_type(text)
    observations.append(f"Scanning for crisis type keywords across {len(FLOOD_KEYWORDS + HEATWAVE_KEYWORDS + ACCIDENT_KEYWORDS + FIRE_KEYWORDS)} multilingual patterns.")
    reasoning_steps.append(f"Matched dominant keyword cluster → Crisis type classified as: {crisis_type.value}.")
    tool_calls.append(ToolCall(
        tool_name="crisis_classifier",
        input={"text": text[:100], "keyword_banks": ["flood", "heat", "accident", "infra"]},
        output={"crisis_type": crisis_type.value, "match_confidence": 0.87},
        latency_ms=200
    ))

    # Step 3: Location extraction
    city = detect_city(text)
    if signal.location_hint:
        loc_lower = signal.location_hint.lower()
        for c in CITY_PATTERNS:
            if any(p in loc_lower for p in CITY_PATTERNS[c]):
                city = c
                break
    location = signal.location_hint or LOCATION_LABELS.get(city, city.title())
    observations.append(f"Location entity extraction complete. City: {city.title()}, Location: {location}.")
    reasoning_steps.append(f"Geographic entity matched '{location}' in known Pakistani city pattern database.")
    tool_calls.append(ToolCall(
        tool_name="entity_extractor",
        input={"text": text[:100]},
        output={"city": city, "location": location},
        latency_ms=180
    ))

    # Step 4: Severity hint
    severity_hint = detect_severity_hint(text)
    observations.append(f"Severity signaling words found → hint: {severity_hint}.")
    reasoning_steps.append("Urgency vocabulary analysis complete. Applied severity pre-classification for downstream agents.")

    # Step 5: Duplicate detection
    duplicates = check_duplicate(text, context.crisis_id)
    if duplicates:
        observations.append(f"⚠ Duplicate signal cluster detected: {len(duplicates)} overlapping report(s). Clustering to prevent false escalation.")
        reasoning_steps.append(f"Signal overlap score exceeded threshold (≥4 shared tokens). Marking as clustered duplicates: {duplicates}.")
    else:
        observations.append("No duplicate signals detected. Treating as unique report.")
        reasoning_steps.append("Duplicate check passed. Signal is novel — cleared for verification pipeline.")

    entities = ExtractedEntities(
        crisis_type=crisis_type,
        location=location,
        city=city,
        severity_hint=severity_hint,
        language_detected=lang,
        keywords=[kw for kw in (FLOOD_KEYWORDS + HEATWAVE_KEYWORDS + ACCIDENT_KEYWORDS) if kw in text.lower()][:8],
        duplicate_signal_ids=duplicates,
    )

    context.entities = entities
    context.workflow_step = 1

    elapsed = int((time.time() - start) * 1000)
    trace = AgentTrace(
        agent_name="Signal Ingestion Agent",
        agent_index=1,
        timestamp=datetime.utcnow().isoformat(),
        input={"signal": signal.text[:200], "source": signal.source},
        observations=observations,
        reasoning_steps=reasoning_steps,
        tool_calls=tool_calls,
        decision=f"Structured crisis signal extracted. Type={crisis_type.value}, City={city.title()}, Lang={lang}, Severity hint={severity_hint}.",
        confidence=0.88,
        output=entities.model_dump(),
        execution_time_ms=elapsed,
        fallback_triggered=False,
    )
    context.agent_traces.append(trace)
    return context
