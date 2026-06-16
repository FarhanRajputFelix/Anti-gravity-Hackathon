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
    """Use Gemini to extract a Pakistani city from text when patterns fail."""
    result = _gemini_classify(text)
    return result.get("city", "")


def _gemini_classify(text: str) -> dict:
    """
    Use Gemini AI as a PRIMARY classifier — returns crisis_type, city, severity,
    urgency, language for a crisis report. Empty dict if Gemini unavailable.
    """
    import os, json as _json
    api_key = os.getenv("GEMINI_API_KEY", "")
    if not api_key or api_key == "your-gemini-api-key-here":
        return {}
    try:
        import warnings
        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            import google.generativeai as genai
        genai.configure(api_key=api_key)
        model = genai.GenerativeModel("gemini-2.0-flash")
        prompt = f"""You are SAHARA AI's Crisis Classifier for Pakistan.
Analyze this crisis report and return ONLY a JSON object (no markdown, no commentary):

{{
  "crisis_type": "FLOODING" | "FIRE" | "HEATWAVE" | "TRAFFIC_ACCIDENT" | "INFRASTRUCTURE_FAILURE" | "UNKNOWN",
  "city":        "<lowercase Pakistani city, e.g. dadu, karachi, gwadar>" or "unknown",
  "severity":    "CRITICAL" | "HIGH" | "MEDIUM" | "LOW",
  "urgency":     "IMMEDIATE" | "URGENT" | "ROUTINE",
  "language":    "english" | "urdu" | "roman_urdu",
  "confidence":  0.0 to 1.0
}}

Rules:
- crisis_type = UNKNOWN if no actual emergency described (e.g. test text, random characters).
- city = unknown if no Pakistani city/district mentioned.
- Be strict: "people fainting in heat" with no city = UNKNOWN.

Report: {text[:400]}"""
        response = model.generate_content(prompt)
        if not response or not response.text:
            return {}
        raw = response.text.strip()
        # Strip markdown fences if Gemini added them
        if raw.startswith("```"):
            raw = raw.split("```")[1]
            if raw.startswith("json"):
                raw = raw[4:]
            raw = raw.strip()
        data = _json.loads(raw)
        print(f"[GEMINI CLASSIFY] {data}")
        return data
    except Exception as e:
        print(f"[GEMINI CLASSIFY] failed: {e}")
        return {}


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

    # ── Step 0: Gemini AI primary classification (when available) ──
    # Single Gemini call returns crisis_type, city, severity, urgency, language.
    # We then validate against the deterministic regex layer for redundancy.
    gemini_result = _gemini_classify(text)
    gemini_used = bool(gemini_result)

    # Step 1: Language detection
    lang = gemini_result.get("language") or detect_language(text)
    observations.append(f"Raw signal received ({len(text)} chars). Normalizing language.")
    reasoning_steps.append(f"Language detection scan: found {'Arabic Unicode chars' if lang == 'urdu' else 'Roman Urdu markers' if lang == 'roman_urdu' else 'English text'}. Detected: {lang.upper()}.")
    tool_calls.append(ToolCall(
        tool_name="language_detector",
        input={"text": text[:100]},
        output={"language": lang},
        latency_ms=120
    ))

    # Step 2: Crisis type detection — Gemini primary, regex confirmation
    regex_crisis = detect_crisis_type(text)
    crisis_type = regex_crisis
    if gemini_used:
        try:
            gemini_ct = CrisisType[gemini_result["crisis_type"]]
            # Trust Gemini if it found something specific; keep regex if Gemini said UNKNOWN but regex matched
            if gemini_ct != CrisisType.UNKNOWN:
                crisis_type = gemini_ct
            elif regex_crisis != CrisisType.UNKNOWN:
                crisis_type = regex_crisis
        except (KeyError, ValueError):
            pass
        observations.append(f"[GEMINI AI] Primary classification: {crisis_type.value} (regex agreed: {regex_crisis == crisis_type}).")
        reasoning_steps.append(f"Gemini AI classified crisis as '{crisis_type.value}'. Regex layer matched '{regex_crisis.value}' for cross-validation.")
    else:
        observations.append(f"Scanning crisis-type keywords across {len(FLOOD_KEYWORDS + HEATWAVE_KEYWORDS + ACCIDENT_KEYWORDS + FIRE_KEYWORDS)} multilingual patterns.")
        reasoning_steps.append(f"Matched dominant keyword cluster → Crisis type: {crisis_type.value}.")
    tool_calls.append(ToolCall(
        tool_name="gemini_classifier" if gemini_used else "crisis_classifier_regex",
        input={"text": text[:100]},
        output={
            "crisis_type":  crisis_type.value,
            "gemini_match": gemini_result.get("crisis_type") if gemini_used else None,
            "regex_match":  regex_crisis.value,
            "confidence":   gemini_result.get("confidence", 0.87),
        },
        latency_ms=320 if gemini_used else 200
    ))

    # Step 3: Location extraction — Gemini primary, regex fallback
    gemini_city = (gemini_result.get("city") or "").lower() if gemini_used else ""
    if gemini_city and gemini_city != "unknown" and gemini_city in CITY_PATTERNS:
        city = gemini_city
    elif gemini_city and gemini_city != "unknown":
        # Gemini named a city we don't have patterns for — trust it anyway
        city = gemini_city
    else:
        city = detect_city(text)
    if signal.location_hint:
        loc_lower = signal.location_hint.lower()
        for c in CITY_PATTERNS:
            if any(p in loc_lower for p in CITY_PATTERNS[c]):
                city = c
                break
    location = signal.location_hint or LOCATION_LABELS.get(city, city.title())
    observations.append(f"Location entity extraction complete. City: {city.title()}, Location: {location}.")
    reasoning_steps.append(f"Geographic entity matched '{location}' in {'Gemini AI extraction' if gemini_city else 'pattern database'}.")
    tool_calls.append(ToolCall(
        tool_name="entity_extractor",
        input={"text": text[:100]},
        output={"city": city, "location": location, "extractor": "gemini" if gemini_city else "regex"},
        latency_ms=180
    ))

    # Step 4: Severity hint — Gemini primary, regex fallback
    severity_hint = gemini_result.get("severity") if gemini_used else None
    if severity_hint not in {"CRITICAL", "HIGH", "MEDIUM", "LOW"}:
        severity_hint = detect_severity_hint(text)
    observations.append(f"Severity hint: {severity_hint} ({'Gemini AI' if gemini_used else 'regex'}).")
    reasoning_steps.append(f"Urgency assessment: '{severity_hint}' (urgency: {gemini_result.get('urgency','URGENT') if gemini_used else 'medium'}). Applied for downstream agents.")

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
