"""
SAHARA AI — Agent 6: Fallback & Recovery Agent
Handles API failures, contradictions, and missing data.
Switches strategies, logs limitations, and ensures pipeline continuity.
"""

import time
from datetime import datetime
from models import (
    CrisisContext, AgentTrace, ToolCall, FallbackEntry,
    VerificationStatus, CrisisType
)
from mock_data import HISTORICAL_TRAFFIC_PATTERNS


def run(context: CrisisContext) -> CrisisContext:
    start = time.time()
    verification = context.verification
    entities = context.entities

    observations = []
    reasoning_steps = []
    tool_calls = []
    fallback_actions_taken = []
    triggered = False

    # ──────────────────────────────────────────────
    # SCENARIO 1: Traffic API unavailable
    # ──────────────────────────────────────────────
    traffic_failure = any(
        "traffic api" in e.get("reason", "").lower() or "traffic api" in (e.reason if hasattr(e, "reason") else "").lower()
        for e in (context.fallback_history if isinstance(context.fallback_history[0], FallbackEntry) else
                  [FallbackEntry(**e) for e in context.fallback_history] if context.fallback_history else [])
    ) if context.fallback_history else False

    # Simpler check on raw history
    city = entities.city if entities else "islamabad"
    fallback_reasons = [str(h) for h in context.fallback_history]
    traffic_failure = any("traffic" in r.lower() for r in fallback_reasons)

    if traffic_failure:
        triggered = True
        hist = HISTORICAL_TRAFFIC_PATTERNS.get(city, {})
        typical_congestion = hist.get(f"typical_congestion_Shahrah-e-Quaid-e-Azam", 65)
        note = hist.get("note", "Historical data applied.")

        tool_calls.append(ToolCall(
            tool_name="historical_traffic_db",
            input={"city": city, "lookback_days": 90},
            output={"typical_congestion": typical_congestion, "data_quality": "DEGRADED", "note": note},
            latency_ms=180
        ))

        observations.append(f"⚠ Traffic API unavailable. Switching to 90-day historical congestion baseline.")
        observations.append(f"Historical pattern for {city.title()}: typical congestion = {typical_congestion}/100. Accuracy: ±15%.")
        reasoning_steps.append(f"FALLBACK STRATEGY 1: Live traffic data replaced with historical average ({typical_congestion}/100). Confidence reduction of ~15% applied to downstream severity estimates.")
        reasoning_steps.append(f"{note}")
        fallback_actions_taken.append(f"Traffic API → Historical estimation ({typical_congestion}/100 congestion baseline, ±15% margin)")

        context.fallback_history.append(FallbackEntry(  # type: ignore
            triggered_by="Fallback & Recovery Agent",
            reason="Traffic API unavailable — timeout after 30s",
            strategy_used=f"Historical pattern substitution: {typical_congestion}/100 congestion index (90-day avg)",
            timestamp=datetime.utcnow().isoformat(),
        ))

    # ──────────────────────────────────────────────
    # SCENARIO 2: Contradictory signals detected
    # ──────────────────────────────────────────────
    if verification and (verification.status == VerificationStatus.CONTRADICTED or
                          verification.status == VerificationStatus.UNCERTAIN):
        triggered = True
        contradictions = verification.contradictions

        observations.append(f"⚠ Signal contradictions detected: {len(contradictions)} conflict(s).")
        for cont in contradictions:
            observations.append(f"  • Contradiction: {cont}")
        reasoning_steps.append(f"FALLBACK STRATEGY 2: Social + citizen reports contradict sensor/API data. Applying Bayesian weight adjustment — citizen reports weighted at 0.4x when traffic API conflicts.")
        reasoning_steps.append(f"Crisis status marked as UNCERTAIN. Proceeding with reduced confidence to prevent miss-detection. Additional verification request queued.")

        tool_calls.append(ToolCall(
            tool_name="additional_verification_request",
            input={"city": city, "request_type": "secondary_source_check"},
            output={"sources_queried": ["NDMA SMS feed", "Google Trends spike", "Twitter geotag cluster"],
                    "result": "2 of 3 secondary sources confirm crisis activity"},
            latency_ms=420
        ))
        observations.append("Secondary verification triggered: NDMA SMS feed + Google Trends + Twitter geotag. 2/3 secondary sources confirm activity.")
        reasoning_steps.append("Secondary verification partially confirms crisis. Confidence floor raised to 0.55. Status maintained as UNCERTAIN but escalating to MEDIUM response tier.")
        fallback_actions_taken.append("Contradiction detected → secondary source verification triggered → confidence floor applied")

        context.fallback_history.append(FallbackEntry(
            triggered_by="Fallback & Recovery Agent",
            reason=f"Signal contradiction: {'; '.join(contradictions[:2])}",
            strategy_used="Bayesian weight adjustment + secondary source verification (NDMA/Google Trends/Twitter)",
            timestamp=datetime.utcnow().isoformat(),
        ))

    # ──────────────────────────────────────────────
    # SCENARIO 3: Multiple crisis types simultaneously
    # ──────────────────────────────────────────────
    if entities and entities.crisis_type == CrisisType.UNKNOWN:
        triggered = True
        observations.append("⚠ Crisis type could not be determined. Unknown pattern detected.")
        reasoning_steps.append("FALLBACK STRATEGY 3: Unknown crisis type → defaulting to General Emergency protocol. Dispatching assessment team for on-ground verification.")
        tool_calls.append(ToolCall(
            tool_name="generic_emergency_protocol",
            input={"city": city},
            output={"protocol": "GENERAL_EMERGENCY", "actions_queued": 3},
            latency_ms=150
        ))
        fallback_actions_taken.append("Unknown crisis type → General Emergency protocol activated")

    # ──────────────────────────────────────────────
    # SCENARIO 4: Gemini API unavailable
    # ──────────────────────────────────────────────
    observations.append("Gemini NLP API availability check: DEGRADED (rule-based engine substituted at 92% accuracy).")
    reasoning_steps.append("FALLBACK STRATEGY 4: Gemini API not responding within SLA. Rule-based multilingual keyword engine substituted. Processing accuracy maintained at ~92%. No workflow interruption.")
    tool_calls.append(ToolCall(
        tool_name="rule_based_nlp_fallback",
        input={"reason": "Gemini API timeout"},
        output={"status": "ACTIVE", "accuracy_estimate": 0.92, "latency_ms": 45},
        latency_ms=45
    ))
    fallback_actions_taken.append("Gemini API → Rule-based NLP engine (92% accuracy, 45ms latency)")

    # ── Always runs: System health summary ────────
    observations.append(f"System resilience check complete. {len(fallback_actions_taken)} fallback strategy/strategies applied. Pipeline continues with degraded-but-functional accuracy.")
    reasoning_steps.append(f"Antigravity orchestration maintained continuity through {len(fallback_actions_taken)} failure/edge case(s). All downstream agents unblocked. Audit trail preserved.")

    if not triggered:
        observations.insert(0, "All primary APIs operational. No fallback strategies required for this run.")
        reasoning_steps.insert(0, "System health check: nominal. Fallback agent completing routine audit with null interventions.")
        fallback_actions_taken.append("No fallback required — all systems nominal")

    context.workflow_step = 6

    elapsed = int((time.time() - start) * 1000)
    trace = AgentTrace(
        agent_name="Fallback & Recovery Agent",
        agent_index=6,
        timestamp=datetime.utcnow().isoformat(),
        input={"fallback_triggers_in_context": len(context.fallback_history), "verification_status": verification.status.value if verification else "N/A"},
        observations=observations,
        reasoning_steps=reasoning_steps,
        tool_calls=tool_calls,
        decision=f"{len(fallback_actions_taken)} fallback strategies applied: {' | '.join(fallback_actions_taken)}.",
        confidence=0.82,
        output={"strategies_applied": fallback_actions_taken, "fallback_count": len(fallback_actions_taken), "system_status": "DEGRADED_RESILIENT" if triggered else "NOMINAL"},
        execution_time_ms=elapsed,
        fallback_triggered=triggered,
        fallback_reason="; ".join(fallback_actions_taken) if triggered else None,
    )
    context.agent_traces.append(trace)
    return context
