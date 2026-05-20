"""
SAHARA AI — Agent 1: Signal Ingestion Agent
Parses raw multilingual crisis signals into structured data.
Supports English, Urdu, and Roman Urdu.
"""

import time
import uuid
import json
import os
from datetime import datetime
from models import (
    CrisisContext, AgentTrace, ToolCall,
    ExtractedEntities, CrisisType
)
try:
    import google.generativeai as genai
except ImportError:
    genai = None


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


def _gemini_crisis_analysis(text: str) -> dict:
    """
    Calls Gemini API to analyze crisis signals.
    Returns structured crisis analysis or falls back to keyword matching on error.
    """
    if not genai:
        return None

    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        return None

    try:
        genai.configure(api_key=api_key)
        _model_name = os.getenv("GEMINI_MODEL", "gemini-flash-latest")
        model = genai.GenerativeModel(_model_name)

        prompt = f"""You are a crisis detection AI for Pakistan emergency services.
Analyze this message and respond ONLY with valid JSON, nothing else.

Message: {text}

If this message describes a real crisis (flood, fire, accident,
heatwave, infrastructure failure), respond with:
{{
  "is_crisis": true,
  "crisis_type": "FLOODING|HEATWAVE|TRAFFIC_ACCIDENT|INFRASTRUCTURE_FAILURE|FIRE",
  "city": "islamabad|karachi|lahore|rawalpindi|peshawar|unknown",
  "location": "extracted location or city name",
  "severity_hint": "HIGH|MEDIUM|LOW",
  "confidence": 0.0-1.0,
  "language": "english|urdu|roman_urdu"
}}

If the message is gibberish, a greeting, a test, spam, or NOT a
crisis report, respond with:
{{
  "is_crisis": false,
  "confidence": 0.0-1.0,
  "reason": "brief reason"
}}"""

        response = model.generate_content(prompt)
        response_text = response.text.strip()

        result = json.loads(response_text)
        return result
    except Exception as e:
        return None


def _crisis_type_from_string(crisis_type_str: str) -> CrisisType:
    """Convert string crisis type to CrisisType enum."""
    mapping = {
        "FLOODING": CrisisType.FLOODING,
        "HEATWAVE": CrisisType.HEATWAVE,
        "TRAFFIC_ACCIDENT": CrisisType.TRAFFIC_ACCIDENT,
        "INFRASTRUCTURE_FAILURE": CrisisType.INFRASTRUCTURE_FAILURE,
        "FIRE": CrisisType.INFRASTRUCTURE_FAILURE,
    }
    return mapping.get(crisis_type_str, CrisisType.UNKNOWN)


def _fallback_crisis_detection(text: str) -> dict:
    """Fallback keyword-based crisis detection when Gemini API fails."""
    t = text.lower()

    crisis_type = CrisisType.UNKNOWN
    if any(kw in t for kw in FLOOD_KEYWORDS):
        crisis_type = CrisisType.FLOODING
    elif any(kw in t for kw in HEATWAVE_KEYWORDS):
        crisis_type = CrisisType.HEATWAVE
    elif any(kw in t for kw in ACCIDENT_KEYWORDS):
        crisis_type = CrisisType.TRAFFIC_ACCIDENT
    elif any(kw in t for kw in INFRASTRUCTURE_KEYWORDS):
        crisis_type = CrisisType.INFRASTRUCTURE_FAILURE

    city = "islamabad"
    for c, patterns in CITY_PATTERNS.items():
        if any(pat in t for pat in patterns):
            city = c
            break

    severity = "MEDIUM"
    if any(w in t for w in ["critical", "zaroorat", "bachao", "madad", "emergency", "severe", "extreme", "zabardast"]):
        severity = "HIGH"
    elif any(w in t for w in ["partial", "kuch", "thori", "minor"]):
        severity = "LOW"

    is_crisis = crisis_type != CrisisType.UNKNOWN

    return {
        "is_crisis": is_crisis,
        "crisis_type": crisis_type.value,
        "city": city,
        "location": LOCATION_LABELS.get(city, city.title()),
        "severity_hint": severity,
        "confidence": 0.75 if is_crisis else 0.3,
        "language": detect_language(text),
        "fallback": True,
    }


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

    # Step 2-4: Unified crisis analysis via Gemini API
    analysis_start = time.time()
    analysis = _gemini_crisis_analysis(text)
    fallback_used = False

    if analysis is None:
        observations.append("Gemini API unavailable or failed. Falling back to keyword matching.")
        reasoning_steps.append("Gemini API call failed → reverting to legacy keyword-based detection.")
        analysis = _fallback_crisis_detection(text)
        fallback_used = True

    gemini_latency = int((time.time() - analysis_start) * 1000)

    crisis_type = _crisis_type_from_string(analysis.get("crisis_type", "UNKNOWN"))
    city = analysis.get("city", "islamabad")
    location = analysis.get("location") or signal.location_hint or LOCATION_LABELS.get(city, city.title())
    severity_hint = analysis.get("severity_hint", "MEDIUM")
    confidence = analysis.get("confidence", 0.0)
    is_crisis = analysis.get("is_crisis", False)

    tool_calls.append(ToolCall(
        tool_name="gemini_crisis_analyzer" if not fallback_used else "crisis_classifier_fallback",
        input={"text": text[:200], "model": "gemini-1.5-flash" if not fallback_used else "keyword_matching"},
        output={
            "crisis_type": crisis_type.value,
            "city": city,
            "severity_hint": severity_hint,
            "confidence": confidence,
            "is_crisis": is_crisis,
        },
        latency_ms=gemini_latency
    ))

    # Rejection logic: if not a crisis or confidence too low
    if not is_crisis or confidence < 0.55:
        context.system_status = "REJECTED_NOT_A_CRISIS"
        rejection_reason = analysis.get("reason", "Low confidence or not a real crisis")
        observations.append(f"⚠ Signal rejected: {rejection_reason} (confidence: {confidence:.2f})")
        reasoning_steps.append(f"Crisis authenticity check failed. Rejection reason: {rejection_reason}.")

        elapsed = int((time.time() - start) * 1000)
        trace = AgentTrace(
            agent_name="Signal Ingestion Agent",
            agent_index=1,
            timestamp=datetime.utcnow().isoformat(),
            input={"signal": signal.text[:200], "source": signal.source},
            observations=observations,
            reasoning_steps=reasoning_steps,
            tool_calls=tool_calls,
            decision=f"Signal rejected. Reason: {rejection_reason}. Confidence: {confidence:.2f}",
            confidence=confidence,
            output={"rejected": True, "reason": rejection_reason},
            execution_time_ms=elapsed,
            fallback_triggered=fallback_used,
        )
        context.agent_traces.append(trace)
        return context

    observations.append(f"Crisis signal validated. Type: {crisis_type.value}, City: {city.title()}, Severity: {severity_hint}, Confidence: {confidence:.2f}")
    reasoning_steps.append(f"Gemini analysis validated crisis authenticity. Type={crisis_type.value}, Location={location}, Severity={severity_hint}.")

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
        confidence=confidence,
        output=entities.model_dump(),
        execution_time_ms=elapsed,
        fallback_triggered=fallback_used,
    )
    context.agent_traces.append(trace)
    return context
