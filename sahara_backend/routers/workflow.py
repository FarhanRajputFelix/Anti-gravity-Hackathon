"""SAHARA AI -- /api/workflow router for visible orchestration graph"""
from fastapi import APIRouter, HTTPException
from orchestrator import orchestrator

router = APIRouter()


@router.get("/workflow/template")
async def get_workflow_template():
    """Return the static Antigravity pipeline template for UI pre-rendering."""
    return {
        "orchestrator": orchestrator.name,
        "version": orchestrator.version,
        "gemini_enabled": orchestrator.gemini_enabled,
        "pipeline": orchestrator.get_workflow_template(),
    }


@router.get("/workflow/{crisis_id}")
async def get_workflow(crisis_id: str):
    """Return the executed workflow graph for a specific crisis analysis."""
    crisis = orchestrator.get_crisis(crisis_id)
    if not crisis:
        raise HTTPException(status_code=404, detail=f"Crisis {crisis_id} not found.")
    return {
        "crisis_id": crisis_id,
        "orchestration_workflow": crisis.get("orchestration_workflow", []),
        "agent_traces": crisis.get("agent_traces", []),
        "total_execution_time_ms": crisis.get("total_execution_time_ms", 0),
    }
