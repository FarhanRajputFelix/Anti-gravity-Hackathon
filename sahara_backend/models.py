"""
SAHARA AI — Pydantic Models
Shared data models used across agents and API endpoints.
"""

from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
from enum import Enum
import uuid
from datetime import datetime


class SeverityLevel(str, Enum):
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"
    CRITICAL = "CRITICAL"


class CrisisType(str, Enum):
    FLOODING = "FLOODING"
    HEATWAVE = "HEATWAVE"
    TRAFFIC_ACCIDENT = "TRAFFIC_ACCIDENT"
    INFRASTRUCTURE_FAILURE = "INFRASTRUCTURE_FAILURE"
    FIRE = "FIRE"
    UNKNOWN = "UNKNOWN"


class VerificationStatus(str, Enum):
    CONFIRMED = "CONFIRMED"
    UNCERTAIN = "UNCERTAIN"
    UNVERIFIED = "UNVERIFIED"
    CONTRADICTED = "CONTRADICTED"


# ─────────────────────────────────────────
# INPUT MODEL
# ─────────────────────────────────────────

class CrisisSignal(BaseModel):
    text: str = Field(..., description="Raw crisis report text (Urdu/Roman Urdu/English)")
    source: str = Field(default="citizen_report", description="Source type: citizen_report, weather_api, traffic_api, social_media")
    location_hint: Optional[str] = None
    timestamp: Optional[str] = None
    signal_id: Optional[str] = Field(default_factory=lambda: str(uuid.uuid4())[:8])


# ─────────────────────────────────────────
# AGENT TRACE MODEL
# ─────────────────────────────────────────

class ToolCall(BaseModel):
    tool_name: str
    input: Dict[str, Any]
    output: Any
    latency_ms: int


class AgentTrace(BaseModel):
    agent_name: str
    agent_index: int
    timestamp: str
    input: Dict[str, Any]
    observations: List[str]
    reasoning_steps: List[str]
    tool_calls: List[ToolCall] = []
    decision: str
    confidence: float = Field(ge=0.0, le=1.0)
    output: Dict[str, Any]
    execution_time_ms: int
    fallback_triggered: bool = False
    fallback_reason: Optional[str] = None
    gemini_enhanced: bool = False


# ─────────────────────────────────────────
# CRISIS CONTEXT (shared state)
# ─────────────────────────────────────────

class ExtractedEntities(BaseModel):
    crisis_type: CrisisType = CrisisType.UNKNOWN
    location: str = ""
    city: str = ""
    severity_hint: str = ""
    language_detected: str = "english"
    keywords: List[str] = []
    duplicate_signal_ids: List[str] = []


class VerificationResult(BaseModel):
    status: VerificationStatus = VerificationStatus.UNVERIFIED
    confidence_score: float = 0.5
    weather_consistent: bool = True
    traffic_consistent: bool = True
    contradictions: List[str] = []
    supporting_evidence: List[str] = []


class SeverityResult(BaseModel):
    level: SeverityLevel = SeverityLevel.MEDIUM
    affected_population: int = 0
    affected_roads: List[str] = []
    infrastructure_impact: str = ""
    emergency_urgency: str = "STANDARD"


class ResponseAction(BaseModel):
    action_id: str
    priority: int  # 1 = highest
    responsible_department: str
    description: str
    expected_impact: str
    status: str = "PLANNED"
    executed_at: Optional[str] = None


class SimulationState(BaseModel):
    congestion_level_before: int = 0     # 0-100
    congestion_level_after: int = 0
    alerts_sent: int = 0
    emergency_units_dispatched: int = 0
    roads_rerouted: List[str] = []
    hospitals_notified: int = 0
    population_helped: int = 0
    response_time_minutes: int = 0
    emergency_tickets: List[str] = []
    execution_logs: List[str] = []


class FallbackEntry(BaseModel):
    triggered_by: str
    reason: str
    strategy_used: str
    timestamp: str


class CrisisContext(BaseModel):
    crisis_id: str = Field(default_factory=lambda: str(uuid.uuid4())[:12])
    created_at: str = Field(default_factory=lambda: datetime.utcnow().isoformat())
    signals: List[CrisisSignal] = []
    entities: Optional[ExtractedEntities] = None
    verification: Optional[VerificationResult] = None
    severity: Optional[SeverityResult] = None
    action_plan: List[ResponseAction] = []
    simulation: Optional[SimulationState] = None
    agent_traces: List[AgentTrace] = []
    fallback_history: List[FallbackEntry] = []
    system_status: str = "PROCESSING"
    workflow_step: int = 0


# ─────────────────────────────────────────
# API RESPONSE MODELS
# ─────────────────────────────────────────

class WorkflowStep(BaseModel):
    step: int
    agent_name: str
    status: str = "PENDING"  # PENDING, RUNNING, COMPLETE, SKIPPED, FAILED
    started_at: Optional[str] = None
    completed_at: Optional[str] = None
    tool_calls: List[str] = []
    handoff_to: Optional[str] = None
    gemini_used: bool = False


class AnalysisResult(BaseModel):
    crisis_id: str
    status: str
    crisis_type: str
    location: str
    city: str
    severity: str
    verification_status: str
    confidence: float
    action_plan: List[ResponseAction]
    simulation: Optional[SimulationState]
    agent_traces: List[AgentTrace]
    fallback_history: List[FallbackEntry]
    total_execution_time_ms: int
    system_message: str
    map_data: Dict[str, Any] = {}
    orchestration_workflow: List[WorkflowStep] = []


class SimulateRequest(BaseModel):
    crisis_id: str
    action_plan: Optional[List[ResponseAction]] = None
