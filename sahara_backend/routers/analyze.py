"""SAHARA AI — /api/analyze router"""
import asyncio
import json
import time
from datetime import datetime
from typing import List, Optional
from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import StreamingResponse
from models import CrisisSignal, AnalysisResult, CrisisContext, WorkflowStep
from orchestrator import orchestrator, CRISIS_STORE, LOG_STORE
from mock_data import DEMO_SCENARIOS

# ADK integration (graceful fallback if Gemini API key not set)
try:
    from adk_orchestrator import run_adk_analysis, get_adk_status
    _adk_ready = True
except ImportError:
    _adk_ready = False


def _context_to_result(context: CrisisContext, adk_report: str = "") -> AnalysisResult:
    """Build AnalysisResult from a CrisisContext populated by the ADK pipeline."""
    entities = context.entities
    verif = context.verification
    sev = context.severity
    total_ms = sum(t.execution_time_ms for t in context.agent_traces)

    workflow = [
        WorkflowStep(
            step=t.agent_index,
            agent_name=t.agent_name,
            status="COMPLETE",
            completed_at=t.timestamp,
            tool_calls=[tc.tool_name for tc in t.tool_calls],
        )
        for t in context.agent_traces
    ]

    result = AnalysisResult(
        crisis_id=context.crisis_id,
        status=context.system_status or "RESOLVED",
        crisis_type=entities.crisis_type.value if entities else "UNKNOWN",
        location=entities.location if entities else "Unknown",
        city=entities.city if entities else "Unknown",
        severity=sev.level.value if sev else "UNKNOWN",
        verification_status=verif.status.value if verif else "UNVERIFIED",
        confidence=verif.confidence_score if verif else 0.5,
        action_plan=context.action_plan,
        simulation=context.simulation,
        agent_traces=context.agent_traces,
        fallback_history=context.fallback_history,
        total_execution_time_ms=total_ms,
        system_message=(
            f"[GOOGLE ADK] SAHARA AI processed crisis {context.crisis_id} "
            f"via google-adk Agent (gemini-2.0-flash) + 6 FunctionTools. "
            f"{len(context.agent_traces)} agents executed in {total_ms}ms."
        ),
        map_data={},
        orchestration_workflow=workflow,
    )

    CRISIS_STORE[context.crisis_id] = result.model_dump()
    LOG_STORE.append({
        "crisis_id": context.crisis_id,
        "timestamp": context.created_at,
        "crisis_type": result.crisis_type,
        "city": result.city,
        "severity": result.severity,
        "adk_powered": True,
    })
    return result


router = APIRouter()


@router.post("/analyze", response_model=AnalysisResult)
async def analyze_crisis(signal: CrisisSignal):
    """Run full Antigravity-orchestrated 6-agent pipeline on a single crisis signal."""
    try:
        result = await orchestrator.analyze(signal)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Orchestration error: {str(e)}")


@router.post("/analyze/multi", response_model=AnalysisResult)
async def analyze_multi_source(signals: List[CrisisSignal]):
    """
    Multi-source signal ingestion — accepts simultaneous signals from different sources
    (social_media, weather_api, traffic_api, news_agency, citizen_report).
    The primary signal drives the 6-agent pipeline; additional signals are used as
    corroborating evidence by the Verification and Severity agents.
    """
    if not signals:
        raise HTTPException(status_code=400, detail="At least one signal required")
    if len(signals) > 10:
        raise HTTPException(status_code=400, detail="Maximum 10 signals per request")
    try:
        result = await orchestrator.analyze_multi(signals)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Multi-source orchestration error: {str(e)}")


@router.get("/analyze/stream")
async def analyze_stream(
    text: str = Query(..., description="Crisis signal text"),
    source: str = Query(default="citizen_report", description="Signal source type"),
    location_hint: Optional[str] = Query(default=None, description="Location hint"),
):
    """
    Real-time SSE streaming endpoint. Emits agent completion events as each of the
    6 Antigravity agents finishes, allowing the dashboard to animate the pipeline live.

    Connect via EventSource or fetch with streaming. Each event is a JSON object with
    type: 'started' | 'agent_start' | 'agent_complete' | 'fallback_triggered' | 'complete' | 'error'
    """
    signal = CrisisSignal(text=text, source=source, location_hint=location_hint or None)
    queue: asyncio.Queue = asyncio.Queue()

    async def generate():
        task = asyncio.create_task(orchestrator.analyze_streaming(signal, queue))
        try:
            while True:
                try:
                    event = await asyncio.wait_for(queue.get(), timeout=60.0)
                    yield f"data: {json.dumps(event, ensure_ascii=False, default=str)}\n\n"
                    if event.get("type") in ("complete", "error"):
                        break
                except asyncio.TimeoutError:
                    yield f"data: {json.dumps({'type': 'error', 'message': 'Pipeline timeout after 60s'})}\n\n"
                    break
        finally:
            if not task.done():
                task.cancel()

    return StreamingResponse(
        generate(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
            "Connection": "keep-alive",
        },
    )


@router.get("/scenarios")
async def get_demo_scenarios():
    """Return preset demo crisis scenarios for the mobile app."""
    return {
        "scenarios": [
            {
                "key": k,
                "description": v["description"],
                "text": v["text"],
                "source": v["source"],
                "location_hint": v.get("location_hint"),
            }
            for k, v in DEMO_SCENARIOS.items()
        ]
    }


# ── Google ADK endpoints ──────────────────────────────────────────────────────

@router.get("/adk/status")
async def adk_status():
    """Returns Google ADK (Antigravity) integration status."""
    if not _adk_ready:
        return {"adk_ready": False, "reason": "google-adk package not installed"}
    return {**get_adk_status(), "adk_ready": True}


@router.post("/adk/analyze", response_model=AnalysisResult)
async def adk_analyze(signal: CrisisSignal):
    """
    Run the SAHARA crisis pipeline via the real Google ADK Agent (Antigravity).

    Uses google.adk.agents.Agent with 6 FunctionTools orchestrated by Gemini.
    Requires GEMINI_API_KEY to be set. Falls back to the standard pipeline if
    the ADK runner fails (e.g. missing API key).
    """
    if not _adk_ready:
        raise HTTPException(status_code=503, detail="google-adk not installed")

    context, adk_report = await run_adk_analysis(
        crisis_text=signal.text,
        source=signal.source,
        location_hint=signal.location_hint or "",
    )

    if context is None:
        # ADK failed (likely no API key) — fall back to standard pipeline
        return await orchestrator.analyze(signal)

    return _context_to_result(context, adk_report)
