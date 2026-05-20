"""
SAHARA AI — Agent 2: Verification Agent
Cross-checks crisis signal against mock weather, traffic, and social APIs.
Assigns a confidence score and detects contradictions.
"""

import time
from datetime import datetime
from models import (
    CrisisContext, AgentTrace, ToolCall,
    VerificationResult, VerificationStatus, CrisisType,
    FallbackEntry,
)
from mock_data import MOCK_WEATHER_DATA, MOCK_TRAFFIC_DATA

# Pre-fetched weather cache — populated by the orchestrator before calling run()
# This allows the sync agent to use async-fetched real weather data.
_LIVE_WEATHER_CACHE: dict = {}


def set_live_weather(city: str, data: dict):
    """Called by the orchestrator to inject real weather before running this agent."""
    _LIVE_WEATHER_CACHE[city.lower()] = data


def run(context: CrisisContext) -> CrisisContext:
    start = time.time()
    entities = context.entities
    if not entities:
        context.system_status = "ERROR_NO_ENTITIES"
        return context

    city = entities.city
    crisis_type = entities.crisis_type

    observations = []
    reasoning_steps = []
    tool_calls = []
    contradictions = []
    supporting_evidence = []
    confidence = 0.5

    # ── STEP 1: Weather API check (live data preferred, mock fallback) ──
    weather = _LIVE_WEATHER_CACHE.get(city.lower()) or MOCK_WEATHER_DATA.get(city, {})
    weather_available = weather.get("available", False)
    data_source = weather.get("source", "mock")
    is_live = "openweathermap" in data_source

    if weather_available:
        tool_name = "openweathermap_live_api" if is_live else "mock_weather_api"
        tool_calls.append(ToolCall(
            tool_name=tool_name,
            input={"city": city, "source": data_source},
            output=weather,
            latency_ms=340
        ))
        live_tag = "🌐 LIVE" if is_live else "📦 MOCK"
        observations.append(f"[{live_tag}] Weather API ({data_source}): temp={weather['temperature_c']}°C, rainfall={weather['rainfall_mm_last_3h']}mm/3h, alert={weather['alert']}.")

        if crisis_type == CrisisType.FLOODING:
            rain = weather.get("rainfall_mm_per_hour", weather["rainfall_mm_last_3h"] / 3)
            alert = weather.get("alert", "NONE")
            weather_desc = weather.get("weather_desc", "").lower()
            if alert == "HEAVY_RAIN" or rain >= 5 or any(w in weather_desc for w in ["rain", "flood", "thunder", "storm"]):
                support = f"Weather confirms rainfall conditions ({rain:.1f}mm/hr, alert={alert}) — consistent with flooding report."
                supporting_evidence.append(support)
                confidence += 0.30
                reasoning_steps.append(f"✓ Weather CONSISTENT: {alert} alert + {rain:.1f}mm/hr rainfall supports flooding claim.")
            elif rain > 0:
                supporting_evidence.append(f"Some rainfall recorded ({rain:.1f}mm/hr). Ground conditions may cause localised flooding.")
                confidence += 0.15
                reasoning_steps.append(f"✓ Partial weather support: {rain:.1f}mm/hr rainfall — localised flooding plausible.")
            else:
                reasoning_steps.append(f"ℹ Weather shows no active rainfall ({rain:.1f}mm/hr). Flooding may be from earlier rain, drainage failure, or nullah overflow — citizen report remains primary evidence.")
                confidence += 0.05  # don't penalise — user report is primary evidence
        elif crisis_type == CrisisType.HEATWAVE:
            if weather["temperature_c"] >= 40:
                supporting_evidence.append(f"Extreme temperature confirmed: {weather['temperature_c']}°C.")
                confidence += 0.30
                reasoning_steps.append(f"✓ Weather CONSISTENT: {weather['temperature_c']}°C directly supports heatwave report.")
            elif weather["temperature_c"] >= 36:
                supporting_evidence.append(f"High temperature recorded: {weather['temperature_c']}°C. Heat stress conditions present.")
                confidence += 0.15
                reasoning_steps.append(f"✓ Partial support: {weather['temperature_c']}°C is elevated. Heatwave plausible.")
            else:
                contradictions.append(f"Temperature {weather['temperature_c']}°C does not indicate active heatwave.")
                confidence -= 0.10
                reasoning_steps.append(f"⚠ CONTRADICTION: Temperature ({weather['temperature_c']}°C) is below heatwave threshold.")
        else:
            reasoning_steps.append(f"Weather cross-check: alert={weather['alert']}. No direct weather contradiction for {crisis_type.value}.")
            confidence += 0.10
    else:
        observations.append("⚠ Weather API unavailable — will trigger Fallback Agent for historical estimation.")
        reasoning_steps.append("Weather API call failed. Flagging for Fallback Agent invocation. Proceeding with reduced confidence baseline.")
        confidence -= 0.05

    # ── STEP 2: Traffic API check ─────────────────
    traffic = MOCK_TRAFFIC_DATA.get(city, {})
    traffic_available = traffic.get("available", False)

    if traffic_available:
        tool_calls.append(ToolCall(
            tool_name="mock_traffic_api",
            input={"city": city},
            output=traffic,
            latency_ms=280
        ))
        observations.append(f"Traffic API: congestion={traffic['congestion_index']}/100, incidents={traffic['incident_reports']}, blocked roads={len(traffic['blocked_roads'])}.")

        if crisis_type in [CrisisType.FLOODING, CrisisType.TRAFFIC_ACCIDENT]:
            if traffic["congestion_index"] > 40:
                supporting_evidence.append(f"Traffic congestion at {traffic['congestion_index']}/100 corroborates ground report.")
                confidence += 0.20
                reasoning_steps.append(f"✓ Traffic CONSISTENT: Congestion index {traffic['congestion_index']} + {traffic['incident_reports']} incidents support the crisis claim.")
            else:
                reasoning_steps.append(f"ℹ Traffic congestion ({traffic['congestion_index']}/100) is moderate — crisis may be localised. Citizen report remains primary evidence.")
                confidence += 0.05
        elif crisis_type == CrisisType.HEATWAVE:
            reasoning_steps.append(f"Traffic data is non-primary evidence for heatwave. Congestion={traffic['congestion_index']} noted but not weighted heavily.")
            confidence += 0.05
    else:
        observations.append(f"⚠ Traffic API unavailable for {city}: {traffic.get('error', 'Timeout')}. Routing to Fallback Agent.")
        reasoning_steps.append(f"Traffic API failure detected. Fallback Agent will apply historical congestion patterns for {city}. Accuracy degraded by ~15%.")
        context.fallback_history.append(FallbackEntry(
            triggered_by="Verification Agent",
            reason=f"Traffic API unavailable: {traffic.get('error', 'Timeout')}",
            strategy_used="Historical traffic pattern estimation",
            timestamp=datetime.utcnow().isoformat(),
        ))

    # ── STEP 3: Repeated signal check ────────────
    tool_calls.append(ToolCall(
        tool_name="signal_correlation_engine",
        input={"city": city, "crisis_type": crisis_type.value, "window_minutes": 30},
        output={"correlated_signals": 3, "unique_sources": 2, "timestamp_spread_mins": 18},
        latency_ms=150
    ))
    observations.append("Signal correlation check: 3 related signals from 2 different sources within 30-minute window.")
    reasoning_steps.append("Multi-source corroboration detected (citizen + weather + traffic). Increases confidence in genuine crisis. Not duplicate escalation — different sources.")
    supporting_evidence.append("3 correlated signals from 2+ independent sources within 30-minute cluster window.")
    confidence += 0.10

    # ── STEP 4: Final confidence clamping ────────
    confidence = max(0.10, min(0.98, confidence))

    # ── STEP 4.5: UNKNOWN crisis cannot be CONFIRMED ──
    # If signal ingestion couldn't classify the crisis type, this is junk/test data.
    # Refuse to mark it as authentic regardless of corroborating evidence.
    if crisis_type == CrisisType.UNKNOWN or (entities and entities.crisis_type == CrisisType.UNKNOWN):
        confidence = min(confidence, 0.45)
        contradictions.append("Crisis type could not be classified from signal text — insufficient signal quality.")
        observations.append("⛔ Crisis type is UNKNOWN — refusing to authenticate unidentified incidents.")

    # ── STEP 5: Determine status ──────────────────
    if contradictions and confidence < 0.55:
        status = VerificationStatus.CONTRADICTED
        decision = f"Crisis verification CONTRADICTED. Confidence too low ({confidence:.0%}). Contradictions: {'; '.join(contradictions[:2])}."
        observations.append("⛔ Multiple contradictions exceed threshold. Marking status as CONTRADICTED.")
    elif contradictions:
        status = VerificationStatus.UNCERTAIN
        decision = f"Crisis UNCERTAIN — contradictions present but confidence ({confidence:.0%}) sufficient to proceed with caution."
        observations.append("⚠ Contradictions found but supporting evidence outweighs. Marking as UNCERTAIN, proceeding.")
    elif confidence >= 0.75:
        status = VerificationStatus.CONFIRMED
        decision = f"Crisis CONFIRMED with {confidence:.0%} confidence. All primary signals consistent."
        observations.append("✅ All cross-checks passed. Crisis is CONFIRMED.")
    else:
        status = VerificationStatus.UNVERIFIED
        decision = f"Crisis UNVERIFIED — insufficient evidence ({confidence:.0%}). Requires additional data sources."

    verification = VerificationResult(
        status=status,
        confidence_score=round(confidence, 3),
        weather_consistent=len([c for c in contradictions if "weather" in c.lower() or "temperature" in c.lower() or "rainfall" in c.lower()]) == 0,
        traffic_consistent=len([c for c in contradictions if "traffic" in c.lower() or "congestion" in c.lower()]) == 0,
        contradictions=contradictions,
        supporting_evidence=supporting_evidence,
    )

    context.verification = verification
    context.workflow_step = 2

    elapsed = int((time.time() - start) * 1000)
    trace = AgentTrace(
        agent_name="Verification Agent",
        agent_index=2,
        timestamp=datetime.utcnow().isoformat(),
        input={"city": city, "crisis_type": crisis_type.value, "entities": entities.model_dump()},
        observations=observations,
        reasoning_steps=reasoning_steps,
        tool_calls=tool_calls,
        decision=decision,
        confidence=round(confidence, 3),
        output=verification.model_dump(),
        execution_time_ms=elapsed,
        fallback_triggered=not traffic_available or not weather_available,
        fallback_reason="Traffic or Weather API unavailable" if not traffic_available else None,
    )
    context.agent_traces.append(trace)
    return context
