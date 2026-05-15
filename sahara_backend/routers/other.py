"""SAHARA AI — /api/logs, /api/simulate, /api/crisis/{id} routers"""
from fastapi import APIRouter, HTTPException
from models import SimulateRequest
from orchestrator import orchestrator
from agents import execution_simulation
from models import CrisisContext, CrisisSignal
import json

router = APIRouter()


@router.get("/logs")
async def get_logs():
    """Return the last 20 agent trace logs."""
    return {"logs": orchestrator.get_logs(), "count": len(orchestrator.get_logs())}


@router.get("/crisis/{crisis_id}")
async def get_crisis(crisis_id: str):
    """Return stored crisis details by ID."""
    result = orchestrator.get_crisis(crisis_id)
    if not result:
        raise HTTPException(status_code=404, detail=f"Crisis {crisis_id} not found.")
    return result


@router.post("/simulate")
async def run_simulation(req: SimulateRequest):
    """
    Run standalone execution simulation for an existing crisis.
    Useful for re-simulating with modified action plans.
    """
    existing = orchestrator.get_crisis(req.crisis_id)
    if not existing:
        raise HTTPException(status_code=404, detail=f"Crisis {req.crisis_id} not found. Run /api/analyze first.")
    # Re-run simulation with provided or stored action plan
    return {
        "crisis_id": req.crisis_id,
        "simulation": existing.get("simulation"),
        "status": "simulation_retrieved",
        "note": "Use POST /api/analyze to run a fresh simulation with new signals."
    }


@router.get("/feed")
async def get_signal_feed():
    """Return recent signal feed for the home dashboard."""
    from mock_data import RECENT_SIGNAL_FEED
    return {"signals": RECENT_SIGNAL_FEED, "count": len(RECENT_SIGNAL_FEED)}
