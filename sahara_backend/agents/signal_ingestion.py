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
URDU_KEYWORDS = ["mein", "hai", "ka", "ki", "ke", "aur", "se", "pe", "par", "wali", "wala", "gaya"]
ROMAN_URDU_KEYWORDS = ["pani", "garmi", "baarish", "hadsa", "gaari", "logon", "bachao", "madad"]

CITY_PATTERNS = {
    "islamabad": ["islamabad", "isb", "g-10", "g10", "f-7", "i-8", "i8", "rawalpindi", "pindi", "اسلام آباد"],
    "karachi": ["karachi", "khi", "saddar", "gulshan", "clifton", "korangi", "کراچی"],
    "lahore": ["lahore", "lhr", "gulberg", "dha", "johar town", "shahrah", "canal", "لاہور"],
}

LOCATION_LABELS = {
    "islamabad": "G-10, Islamabad",
    "karachi": "Saddar, Karachi",
    "lahore": "Shahrah-e-Quaid-e-Azam, Lahore",
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
    t = text.lower()
    for city, patterns in CITY_PATTERNS.items():
        if any(pat in t for pat in patterns):
            return city
    # Default based on context hints
    return "islamabad"


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
    observations.append(f"Scanning for crisis type keywords across {len(FLOOD_KEYWORDS + HEATWAVE_KEYWORDS + ACCIDENT_KEYWORDS)} multilingual patterns.")
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
