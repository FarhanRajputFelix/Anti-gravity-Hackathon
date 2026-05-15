"""SAHARA AI — /api/analyze router"""
from fastapi import APIRouter, HTTPException
from models import CrisisSignal, AnalysisResult
from orchestrator import orchestrator
from mock_data import DEMO_SCENARIOS

router = APIRouter()


@router.post("/analyze", response_model=AnalysisResult)
async def analyze_crisis(signal: CrisisSignal):
    """
    Run full Antigravity-orchestrated agent pipeline on a crisis signal.
    Returns agent traces, action plan, simulation results, and outcome metrics.
    """
    try:
        result = await orchestrator.analyze(signal)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Orchestration error: {str(e)}")


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
