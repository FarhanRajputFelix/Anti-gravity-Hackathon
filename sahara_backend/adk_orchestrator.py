"""
SAHARA AI -- Google ADK (Antigravity) Orchestrator
Wraps the 6-agent crisis pipeline using Google Agent Development Kit v1.34+.

Architecture:
  - One LlmAgent ("SAHARA_ANTIGRAVITY_CIRO") powered by Gemini
  - 6 FunctionTools mapped to the 6 specialist agents
  - Runner + InMemorySessionService for session management
  - Shared CrisisContext passed between tools via module-level store
"""

import os
import json
import uuid
import asyncio
from typing import Optional, Tuple
from dotenv import load_dotenv
load_dotenv()

from google.adk.agents import Agent
from google.adk.runners import Runner
from google.adk.sessions import InMemorySessionService
from google.genai import types as genai_types

from models import CrisisContext, CrisisSignal
from agents import signal_ingestion, verification, severity_analysis
from agents import response_planning, execution_simulation, fallback_recovery

# Shared context store: crisis_id -> CrisisContext
# Tools write here; the caller retrieves the final context after the run.
_adk_contexts: dict = {}

# ── Tool 1: Signal Ingestion ─────────────────────────────────────────────────

def tool_ingest_signal(crisis_text: str, source: str, location_hint: str = "") -> dict:
    """
    Ingests a raw multilingual crisis signal (English/Urdu/Roman Urdu).
    Detects language, classifies crisis type, and extracts location entities.

    Args:
        crisis_text: Raw text of the crisis report
        source: Signal origin — citizen_report, weather_api, traffic_api, social_media
        location_hint: Optional location string to assist extraction

    Returns:
        crisis_id, crisis_type, location, language, keywords, confidence
    """
    signal = CrisisSignal(
        text=crisis_text,
        source=source,
        location_hint=location_hint or None,
    )
    context = CrisisContext(signals=[signal])
    _adk_contexts[context.crisis_id] = context

    context = signal_ingestion.run(context)
    entities = context.entities
    trace = context.agent_traces[-1] if context.agent_traces else None

    return {
        "crisis_id": context.crisis_id,
        "status": "completed",
        "crisis_type": entities.crisis_type.value if entities else "UNKNOWN",
        "location": entities.location if entities else "",
        "city": entities.city if entities else "",
        "language_detected": entities.language_detected if entities else "english",
        "keywords": entities.keywords[:6] if entities else [],
        "confidence": round(trace.confidence, 2) if trace else 0.7,
        "decision": trace.decision if trace else "Signal ingested.",
    }


# ── Tool 2: Verification ─────────────────────────────────────────────────────

def tool_verify_crisis(crisis_id: str) -> dict:
    """
    Cross-verifies the detected crisis against weather APIs, traffic data,
    and historical patterns for Pakistani cities.

    Args:
        crisis_id: The crisis_id returned by tool_ingest_signal

    Returns:
        verification_status, confidence_score, supporting_evidence, contradictions
    """
    context = _adk_contexts.get(crisis_id)
    if not context:
        return {"error": "crisis_id not found — call tool_ingest_signal first", "crisis_id": crisis_id}

    context = verification.run(context)
    v = context.verification
    trace = context.agent_traces[-1] if context.agent_traces else None

    return {
        "crisis_id": crisis_id,
        "status": "completed",
        "verification_status": v.status.value if v else "UNVERIFIED",
        "confidence_score": round(v.confidence_score, 2) if v else 0.5,
        "weather_consistent": v.weather_consistent if v else True,
        "traffic_consistent": v.traffic_consistent if v else True,
        "supporting_evidence": v.supporting_evidence if v else [],
        "contradictions": v.contradictions if v else [],
        "decision": trace.decision if trace else "Verification complete.",
    }


# ── Tool 3: Severity Analysis ────────────────────────────────────────────────

def tool_analyze_severity(crisis_id: str) -> dict:
    """
    Estimates crisis severity by analysing affected population, road network
    disruption, and infrastructure risk in the impacted Pakistani city.

    Args:
        crisis_id: The crisis_id from previous steps

    Returns:
        severity_level (LOW/MEDIUM/HIGH/CRITICAL), affected_population, affected_roads
    """
    context = _adk_contexts.get(crisis_id)
    if not context:
        return {"error": "crisis_id not found", "crisis_id": crisis_id}

    context = severity_analysis.run(context)
    s = context.severity
    trace = context.agent_traces[-1] if context.agent_traces else None

    return {
        "crisis_id": crisis_id,
        "status": "completed",
        "severity_level": s.level.value if s else "MEDIUM",
        "emergency_urgency": s.emergency_urgency if s else "STANDARD",
        "affected_population": s.affected_population if s else 0,
        "affected_roads": s.affected_roads if s else [],
        "infrastructure_impact": s.infrastructure_impact if s else "",
        "decision": trace.decision if trace else "Severity assessed.",
    }


# ── Tool 4: Response Planning ────────────────────────────────────────────────

def tool_plan_response(crisis_id: str) -> dict:
    """
    Generates a coordinated multi-department emergency response plan.
    Allocates resources across Rescue 1122, Traffic Police, WASA, PEMRA,
    and hospitals for the specific crisis type and severity.

    Args:
        crisis_id: The crisis_id from previous steps

    Returns:
        Prioritised list of response actions with responsible departments
    """
    context = _adk_contexts.get(crisis_id)
    if not context:
        return {"error": "crisis_id not found", "crisis_id": crisis_id}

    context = response_planning.run(context)
    trace = context.agent_traces[-1] if context.agent_traces else None

    return {
        "crisis_id": crisis_id,
        "status": "completed",
        "total_actions": len(context.action_plan),
        "actions": [
            {
                "priority": a.priority,
                "department": a.responsible_department,
                "description": a.description,
                "expected_impact": a.expected_impact,
            }
            for a in sorted(context.action_plan, key=lambda x: x.priority)[:5]
        ],
        "decision": trace.decision if trace else "Response plan generated.",
    }


# ── Tool 5: Execution Simulation ─────────────────────────────────────────────

def tool_simulate_execution(crisis_id: str) -> dict:
    """
    Simulates real-time execution of all response actions. Updates mock
    Google Maps routes, dispatches emergency units, broadcasts SMS alerts,
    and generates emergency tickets. Returns before/after system state.

    Args:
        crisis_id: The crisis_id from previous steps

    Returns:
        congestion before/after, units dispatched, alerts sent, emergency tickets
    """
    context = _adk_contexts.get(crisis_id)
    if not context:
        return {"error": "crisis_id not found", "crisis_id": crisis_id}

    context = execution_simulation.run(context)
    sim = context.simulation
    trace = context.agent_traces[-1] if context.agent_traces else None

    before = sim.congestion_level_before if sim else 0
    after = sim.congestion_level_after if sim else 0
    reduction = round((before - after) / max(before, 1) * 100) if before > 0 else 0

    return {
        "crisis_id": crisis_id,
        "status": "completed",
        "congestion_before": before,
        "congestion_after": after,
        "congestion_reduction_pct": reduction,
        "emergency_units_dispatched": sim.emergency_units_dispatched if sim else 0,
        "alerts_sent": sim.alerts_sent if sim else 0,
        "population_helped": sim.population_helped if sim else 0,
        "response_time_minutes": sim.response_time_minutes if sim else 0,
        "roads_rerouted": sim.roads_rerouted if sim else [],
        "emergency_tickets": sim.emergency_tickets[:4] if sim else [],
        "execution_logs": sim.execution_logs[:4] if sim else [],
        "decision": trace.decision if trace else "Simulation complete.",
    }


# ── Tool 6: System Audit ─────────────────────────────────────────────────────

def tool_audit_system(crisis_id: str) -> dict:
    """
    Performs a final system health audit and fallback-recovery check.
    Logs any API substitutions, confirms system resilience, and marks
    the crisis analysis as resolved.

    Args:
        crisis_id: The crisis_id from previous steps

    Returns:
        system_status, overall_confidence, fallback_count, execution_time_ms
    """
    context = _adk_contexts.get(crisis_id)
    if not context:
        return {"error": "crisis_id not found", "crisis_id": crisis_id}

    context = fallback_recovery.run(context)
    context.system_status = "RESOLVED"
    _adk_contexts[crisis_id] = context  # update store

    trace = context.agent_traces[-1] if context.agent_traces else None
    n = len(context.agent_traces)
    overall = round(sum(t.confidence for t in context.agent_traces) / max(n, 1), 2)
    total_ms = sum(t.execution_time_ms for t in context.agent_traces)

    return {
        "crisis_id": crisis_id,
        "status": "completed",
        "system_status": "OPERATIONAL",
        "total_agents_executed": n,
        "fallback_count": len(context.fallback_history),
        "fallback_strategies": [f.strategy_used for f in context.fallback_history],
        "overall_confidence": overall,
        "total_execution_time_ms": total_ms,
        "decision": trace.decision if trace else "System audit complete.",
    }


# ── ADK Agent ────────────────────────────────────────────────────────────────

SAHARA_CIRO_AGENT = Agent(
    name="SAHARA_ANTIGRAVITY_CIRO",
    model="gemini-2.0-flash",
    description=(
        "SAHARA AI — Pakistan's Crisis Intelligence & Response Orchestrator. "
        "Coordinates 6 specialist agents to detect, verify, plan, and simulate "
        "responses to urban crises (flooding, heatwaves, accidents, fires)."
    ),
    instruction="""You are SAHARA AI's Crisis Intelligence & Response Orchestrator (CIRO),
built on Google Antigravity (ADK) for Pakistan's urban emergency management.

You coordinate 6 specialist agents as FunctionTools to detect and respond to crises.

━━━ MANDATORY EXECUTION ORDER ━━━

When you receive a crisis signal, execute ALL 6 tools in this EXACT sequence:

1. tool_ingest_signal(crisis_text, source, location_hint)
   → Extracts: crisis_type, location, language, keywords, confidence
   → SAVE the returned crisis_id — all subsequent tools need it

2. tool_verify_crisis(crisis_id)
   → Verifies against weather + traffic APIs
   → Returns: verification_status, confidence_score

3. tool_analyze_severity(crisis_id)
   → Estimates population impact, road network disruption
   → Returns: severity_level (LOW/MEDIUM/HIGH/CRITICAL), urgency

4. tool_plan_response(crisis_id)
   → Generates coordinated actions for Rescue 1122, Traffic Police, WASA, hospitals
   → Returns: prioritised action list

5. tool_simulate_execution(crisis_id)
   → Simulates real-time response: reroutes traffic, dispatches units, sends alerts
   → Returns: before/after congestion, emergency tickets

6. tool_audit_system(crisis_id)
   → Final health check and resilience audit
   → Returns: overall_confidence, fallback_count

━━━ FINAL REPORT FORMAT ━━━

After all 6 tools complete, output EXACTLY this structure:

DETECTED SITUATION: [crisis type] at [location]
CONFIDENCE: [High/Medium/Low based on confidence_score]
SEVERITY: [severity_level]

IMPACT:
• [impact derived from affected_population and affected_roads]
• [infrastructure_impact]

RECOMMENDED ACTIONS:
• [Action 1 from tool_plan_response — department: description]
• [Action 2]
• [Action 3]

SIMULATED EXECUTION:
• Traffic congestion reduced [before]% → [after]% ([reduction_pct]% improvement)
• [N] emergency units dispatched in [response_time_minutes] minutes
• [N] SMS alerts sent to citizens
• Emergency tickets: [list ticket IDs]

OUTCOME: [1-sentence summary — what improved, how many people helped]
""",
    tools=[
        tool_ingest_signal,
        tool_verify_crisis,
        tool_analyze_severity,
        tool_plan_response,
        tool_simulate_execution,
        tool_audit_system,
    ],
)

# ── Runner ───────────────────────────────────────────────────────────────────

_session_service = InMemorySessionService()


def _make_runner() -> Runner:
    return Runner(
        agent=SAHARA_CIRO_AGENT,
        app_name="SAHARA_AI",
        session_service=_session_service,
    )


async def run_adk_analysis(
    crisis_text: str,
    source: str = "citizen_report",
    location_hint: str = "",
    session_id: Optional[str] = None,
) -> Tuple[Optional[CrisisContext], str]:
    """
    Run the full SAHARA 6-agent pipeline via Google ADK.

    Returns:
        (CrisisContext, final_report_text)
        CrisisContext is None on failure; caller should fall back to non-ADK pipeline.
    """
    user_id = "sahara_user"
    sid = session_id or str(uuid.uuid4())[:8]

    try:
        _session_service.create_session(
            app_name="SAHARA_AI",
            user_id=user_id,
            session_id=sid,
        )
    except Exception:
        pass  # session may already exist

    runner = _make_runner()

    prompt = (
        f"Process this crisis signal through all 6 agent steps:\n\n"
        f"CRISIS TEXT: {crisis_text}\n"
        f"SOURCE: {source}\n"
        f"LOCATION HINT: {location_hint or 'Not specified'}\n\n"
        f"Execute all 6 tools in sequence now: "
        f"ingest → verify → severity → plan → simulate → audit."
    )

    new_message = genai_types.Content(
        role="user",
        parts=[genai_types.Part(text=prompt)],
    )

    final_response = ""
    try:
        async for event in runner.run_async(
            user_id=user_id,
            session_id=sid,
            new_message=new_message,
        ):
            if event.is_final_response():
                if event.content and event.content.parts:
                    final_response = event.content.parts[0].text or ""
                break
    except Exception as exc:
        print(f"[ADK] runner error: {exc}")
        return None, str(exc)

    # Retrieve the context created during tool execution
    context: Optional[CrisisContext] = None
    for ctx in reversed(list(_adk_contexts.values())):
        if ctx.signals and ctx.signals[0].text == crisis_text:
            context = ctx
            break

    if context is None:
        return None, "ADK pipeline completed but context was not found."

    return context, final_response


def get_adk_status() -> dict:
    """Returns whether ADK is available and configured."""
    api_key = os.getenv("GEMINI_API_KEY", "")
    configured = bool(api_key and api_key != "your-gemini-api-key-here")
    return {
        "adk_version": "1.34.0",
        "agent_name": SAHARA_CIRO_AGENT.name,
        "model": "gemini-2.0-flash",
        "tools": [t.__name__ for t in [
            tool_ingest_signal, tool_verify_crisis, tool_analyze_severity,
            tool_plan_response, tool_simulate_execution, tool_audit_system,
        ]],
        "gemini_api_configured": configured,
        "pipeline_mode": "ADK_LIVE" if configured else "ADK_FALLBACK",
    }
