"""
SAHARA AI -- Antigravity Orchestrator v2.0
Gemini-enhanced multi-agent orchestration with visible workflow tracking.

Responsibilities:
- Task decomposition and workflow planning
- Sequential agent invocation with shared CrisisContext
- Gemini AI reasoning enrichment (with rule-based fallback)
- Reasoning trace management
- Fallback routing and retry handling
- State synchronization across agents
- Final result aggregation with orchestration workflow graph
"""

import sys
import os
import time
import uuid
from datetime import datetime
from typing import Optional

# Windows console UTF-8 fix
for _stream in (sys.stdout, sys.stderr):
    reconfigure = getattr(_stream, "reconfigure", None)
    if reconfigure is not None:
        try:
            reconfigure(encoding="utf-8", errors="replace")
        except (ValueError, OSError):
            pass

from dotenv import load_dotenv
load_dotenv()

from models import (
    CrisisContext, CrisisSignal, AnalysisResult,
    FallbackEntry, VerificationStatus, WorkflowStep
)
from mock_data import MAP_CRISIS_DATA, DEMO_SCENARIOS

# Import all 6 specialized agents
from agents import signal_ingestion, verification, severity_analysis
from agents import response_planning, execution_simulation, fallback_recovery
from firebase_client import firebase

# ---------- Gemini AI Client ----------
_gemini_model = None
_gemini_available = False

try:
    import google.generativeai as genai
    _api_key = os.getenv("GEMINI_API_KEY", "")
    if _api_key and _api_key != "your-gemini-api-key-here":
        genai.configure(api_key=_api_key)
        _gemini_model = genai.GenerativeModel("gemini-1.5-flash")
        _gemini_available = True
        print("[ANTIGRAVITY] Gemini AI connected -- AI-enhanced reasoning ACTIVE")
    else:
        print("[ANTIGRAVITY] No GEMINI_API_KEY found -- using rule-based reasoning (demo mode)")
except ImportError:
    print("[ANTIGRAVITY] google-generativeai not installed -- using rule-based reasoning")
except Exception as e:
    print(f"[ANTIGRAVITY] Gemini init error: {e} -- falling back to rule-based reasoning")


# In-memory crisis store
CRISIS_STORE: dict = {}
LOG_STORE: list = []


async def _gemini_reason(agent_name: str, context_summary: str, task: str) -> Optional[str]:
    """Call Gemini to generate agent-style reasoning. Returns None on failure."""
    if not _gemini_available or not _gemini_model:
        return None
    try:
        prompt = f"""You are the {agent_name} in the SAHARA AI crisis response system for Pakistan.

CRISIS CONTEXT:
{context_summary}

YOUR TASK:
{task}

Provide a concise 3-5 line reasoning analysis. Be specific about Pakistani geography, infrastructure, and emergency response. Include concrete numbers where possible. Format as bullet points."""

        response = await _gemini_model.generate_content_async(prompt)
        return response.text.strip() if response and response.text else None
    except Exception as e:
        print(f"[ANTIGRAVITY] Gemini call failed for {agent_name}: {e}")
        return None


class AntigravityOrchestrator:
    """
    The Antigravity Orchestrator v2.0 coordinates all 6 SAHARA AI agents
    with optional Gemini AI reasoning enrichment.

    Execution Plan:
    +------------------------------------------+
    |  Step 1 | Signal Ingestion Agent         |
    |  Step 2 | Verification Agent             |
    |  Step 3 | [Fallback if contradicted]     |
    |  Step 4 | Severity Analysis Agent        |
    |  Step 5 | Response Planning Agent        |
    |  Step 6 | Execution Simulation Agent     |
    |  Step 7 | Fallback & Recovery Agent      |
    |  Step 8 | Aggregate + Return Results     |
    +------------------------------------------+
    """

    PIPELINE = [
        {"step": 1, "agent": "Signal Ingestion Agent", "purpose": "Parse multilingual signal -> structured data"},
        {"step": 2, "agent": "Verification Agent", "purpose": "Cross-check APIs -> confidence score"},
        {"step": 3, "agent": "Severity Analysis Agent", "purpose": "Estimate impact -> severity level"},
        {"step": 4, "agent": "Response Planning Agent", "purpose": "Generate actionable response plan"},
        {"step": 5, "agent": "Execution Simulation Agent", "purpose": "Simulate response + produce before/after state"},
        {"step": 6, "agent": "Fallback & Recovery Agent", "purpose": "Final resilience audit + system health check"},
    ]

    def __init__(self):
        self.name = "Antigravity Orchestrator v2.0"
        self.version = "2.0.0"
        self.gemini_enabled = _gemini_available

    def create_execution_plan(self, context: CrisisContext) -> list:
        """Task decomposition -- generates ordered execution plan."""
        return list(self.PIPELINE)

    def _should_trigger_fallback(self, context: CrisisContext) -> bool:
        """Evaluates whether fallback logic is needed after verification."""
        if not context.verification:
            return True
        status = context.verification.status
        return (
            status in [VerificationStatus.CONTRADICTED, VerificationStatus.UNCERTAIN]
            or len(context.fallback_history) > 0
        )

    def _get_map_data(self, context: CrisisContext) -> dict:
        """Determine which map overlay data to return based on detected crisis."""
        if not context.entities:
            return {}
        city = context.entities.city
        for key, data in MAP_CRISIS_DATA.items():
            if city in key:
                return data
        return {}

    def _build_context_summary(self, context: CrisisContext) -> str:
        """Build a text summary of the current crisis context for Gemini."""
        parts = [f"Crisis ID: {context.crisis_id}"]
        if context.signals:
            parts.append(f"Signal: {context.signals[0].text}")
            parts.append(f"Source: {context.signals[0].source}")
        if context.entities:
            e = context.entities
            parts.append(f"Type: {e.crisis_type.value}, Location: {e.location}, City: {e.city}")
            parts.append(f"Keywords: {', '.join(e.keywords)}")
        if context.verification:
            v = context.verification
            parts.append(f"Verification: {v.status.value}, Confidence: {v.confidence_score:.0%}")
        if context.severity:
            s = context.severity
            parts.append(f"Severity: {s.level.value}, Affected: {s.affected_population:,}")
        return "\n".join(parts)

    async def analyze(self, signal: CrisisSignal) -> AnalysisResult:
        """
        Full orchestrated workflow for a crisis signal.
        This is the primary entry point called by the API.
        """
        workflow_start = time.time()
        workflow_steps: list[WorkflowStep] = []

        # Initialize Crisis Context
        context = CrisisContext(
            crisis_id=f"CRS-{str(uuid.uuid4())[:8].upper()}",
            created_at=datetime.utcnow().isoformat(),
            signals=[signal],
        )

        print(f"\n{'='*60}")
        print(f"[ANTIGRAVITY v2.0] Crisis ID: {context.crisis_id}")
        print(f"[ANTIGRAVITY] Gemini AI: {'ACTIVE' if self.gemini_enabled else 'OFFLINE (rule-based)'}")
        print(f"[ANTIGRAVITY] Creating execution plan...")

        plan = self.create_execution_plan(context)
        for step in plan:
            print(f"  Step {step['step']}: {step['agent']} -> {step['purpose']}")

        print(f"[ANTIGRAVITY] Execution plan created. Initiating agent pipeline...")
        print(f"{'='*60}\n")

        # ---- STEP 1: Signal Ingestion Agent ----
        step1_start = datetime.utcnow().isoformat()
        print(f"[ANTIGRAVITY] -> Invoking Agent 1: Signal Ingestion Agent")
        context = signal_ingestion.run(context)

        # Gemini enrichment
        gemini_used_1 = False
        if self.gemini_enabled:
            ai_reasoning = await _gemini_reason(
                "Signal Ingestion Agent",
                self._build_context_summary(context),
                "Analyze the multilingual crisis signal. What type of crisis is this? What location details can you extract? What is the urgency level?"
            )
            if ai_reasoning and context.agent_traces:
                context.agent_traces[-1].reasoning_steps.append(f"[GEMINI AI] {ai_reasoning}")
                context.agent_traces[-1].gemini_enhanced = True
                gemini_used_1 = True

        workflow_steps.append(WorkflowStep(
            step=1, agent_name="Signal Ingestion Agent", status="COMPLETE",
            started_at=step1_start, completed_at=datetime.utcnow().isoformat(),
            tool_calls=["keyword_detector", "language_classifier", "entity_extractor"],
            handoff_to="Verification Agent", gemini_used=gemini_used_1,
        ))
        print(f"[ANTIGRAVITY] OK Agent 1 complete: {context.entities.crisis_type.value if context.entities else 'UNKNOWN'} in {context.entities.city if context.entities else '?'}")

        # ---- STEP 2: Verification Agent ----
        step2_start = datetime.utcnow().isoformat()
        print(f"[ANTIGRAVITY] -> Invoking Agent 2: Verification Agent")
        context = verification.run(context)

        gemini_used_2 = False
        if self.gemini_enabled:
            ai_reasoning = await _gemini_reason(
                "Verification Agent",
                self._build_context_summary(context),
                "Cross-verify the crisis report against weather and traffic data. Is it consistent? What is your confidence level and why?"
            )
            if ai_reasoning and context.agent_traces:
                context.agent_traces[-1].reasoning_steps.append(f"[GEMINI AI] {ai_reasoning}")
                context.agent_traces[-1].gemini_enhanced = True
                gemini_used_2 = True

        conf = context.verification.confidence_score if context.verification else 0
        workflow_steps.append(WorkflowStep(
            step=2, agent_name="Verification Agent", status="COMPLETE",
            started_at=step2_start, completed_at=datetime.utcnow().isoformat(),
            tool_calls=["weather_api", "traffic_api", "social_media_scanner"],
            handoff_to="Fallback Agent" if self._should_trigger_fallback(context) else "Severity Analysis Agent",
            gemini_used=gemini_used_2,
        ))
        print(f"[ANTIGRAVITY] OK Agent 2 complete: confidence={conf:.0%}, status={context.verification.status.value if context.verification else 'UNKNOWN'}")

        # ---- STEP 3: Conditional Fallback ----
        if self._should_trigger_fallback(context):
            step_fb_start = datetime.utcnow().isoformat()
            print(f"[ANTIGRAVITY] !! Fallback condition detected! Routing to Fallback Agent...")
            context = fallback_recovery.run(context)
            workflow_steps.append(WorkflowStep(
                step=3, agent_name="Fallback & Recovery Agent (conditional)", status="COMPLETE",
                started_at=step_fb_start, completed_at=datetime.utcnow().isoformat(),
                tool_calls=["historical_baseline", "rule_based_nlp"],
                handoff_to="Severity Analysis Agent", gemini_used=False,
            ))
            print(f"[ANTIGRAVITY] OK Fallback Agent handled {len(context.fallback_history)} issue(s)")
        else:
            print(f"[ANTIGRAVITY] OK No fallback needed -- all primary APIs nominal")

        # ---- STEP 4: Severity Analysis Agent ----
        step4_start = datetime.utcnow().isoformat()
        print(f"[ANTIGRAVITY] -> Invoking Agent 3: Severity Analysis Agent")
        context = severity_analysis.run(context)

        gemini_used_4 = False
        if self.gemini_enabled:
            ai_reasoning = await _gemini_reason(
                "Severity Analysis Agent",
                self._build_context_summary(context),
                "Assess the severity of this crisis. How many people are affected? What infrastructure is at risk? Rate the emergency urgency."
            )
            if ai_reasoning and context.agent_traces:
                context.agent_traces[-1].reasoning_steps.append(f"[GEMINI AI] {ai_reasoning}")
                context.agent_traces[-1].gemini_enhanced = True
                gemini_used_4 = True

        sev_label = context.severity.level.value if context.severity else 'UNKNOWN'
        sev_pop = f"{context.severity.affected_population:,}" if context.severity else "0"
        workflow_steps.append(WorkflowStep(
            step=4, agent_name="Severity Analysis Agent", status="COMPLETE",
            started_at=step4_start, completed_at=datetime.utcnow().isoformat(),
            tool_calls=["population_estimator", "infrastructure_scanner", "impact_modeler"],
            handoff_to="Response Planning Agent", gemini_used=gemini_used_4,
        ))
        print(f"[ANTIGRAVITY] OK Agent 3 complete: severity={sev_label}, pop={sev_pop}")

        # ---- STEP 5: Response Planning Agent ----
        step5_start = datetime.utcnow().isoformat()
        print(f"[ANTIGRAVITY] -> Invoking Agent 4: Response Planning Agent")
        context = response_planning.run(context)

        gemini_used_5 = False
        if self.gemini_enabled:
            ai_reasoning = await _gemini_reason(
                "Response Planning Agent",
                self._build_context_summary(context),
                "Generate a prioritized emergency response plan for this Pakistani city crisis. Include rerouting, dispatch, alerts, and medical support."
            )
            if ai_reasoning and context.agent_traces:
                context.agent_traces[-1].reasoning_steps.append(f"[GEMINI AI] {ai_reasoning}")
                context.agent_traces[-1].gemini_enhanced = True
                gemini_used_5 = True

        workflow_steps.append(WorkflowStep(
            step=5, agent_name="Response Planning Agent", status="COMPLETE",
            started_at=step5_start, completed_at=datetime.utcnow().isoformat(),
            tool_calls=["action_template_engine", "dispatch_coordinator", "alert_system"],
            handoff_to="Execution Simulation Agent", gemini_used=gemini_used_5,
        ))
        print(f"[ANTIGRAVITY] OK Agent 4 complete: {len(context.action_plan)} actions generated")

        # ---- STEP 6: Execution Simulation Agent ----
        step6_start = datetime.utcnow().isoformat()
        print(f"[ANTIGRAVITY] -> Invoking Agent 5: Execution Simulation Agent")
        context = execution_simulation.run(context)
        sim = context.simulation
        workflow_steps.append(WorkflowStep(
            step=6, agent_name="Execution Simulation Agent", status="COMPLETE",
            started_at=step6_start, completed_at=datetime.utcnow().isoformat(),
            tool_calls=["congestion_simulator", "dispatch_engine", "alert_broadcaster"],
            handoff_to="Fallback & Recovery Agent", gemini_used=False,
        ))
        print(f"[ANTIGRAVITY] OK Agent 5 complete: congestion {sim.congestion_level_before}->{sim.congestion_level_after} | {sim.alerts_sent:,} alerts" if sim else "")

        # ---- STEP 7: Final Fallback Audit ----
        step7_start = datetime.utcnow().isoformat()
        print(f"[ANTIGRAVITY] -> Invoking Agent 6: Fallback & Recovery Agent (final audit)")
        already_run = any(t.agent_name == "Fallback & Recovery Agent" for t in context.agent_traces)
        if not already_run:
            context = fallback_recovery.run(context)
        workflow_steps.append(WorkflowStep(
            step=7, agent_name="Fallback & Recovery Agent", status="COMPLETE",
            started_at=step7_start, completed_at=datetime.utcnow().isoformat(),
            tool_calls=["system_health_check", "resilience_auditor"],
            handoff_to=None, gemini_used=False,
        ))
        print(f"[ANTIGRAVITY] OK Agent 6 complete: {len(context.fallback_history)} fallback entries logged")

        # ---- STEP 8: Aggregate result ----
        total_elapsed = int((time.time() - workflow_start) * 1000)
        print(f"\n[ANTIGRAVITY] DONE Full pipeline complete in {total_elapsed}ms")
        print(f"[ANTIGRAVITY] Generating final AnalysisResult...")

        entities = context.entities
        verif = context.verification
        sev = context.severity
        map_data = self._get_map_data(context)

        gemini_count = sum(1 for t in context.agent_traces if t.gemini_enhanced)

        result = AnalysisResult(
            crisis_id=context.crisis_id,
            status=context.system_status,
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
            total_execution_time_ms=total_elapsed,
            system_message=f"SAHARA AI processed crisis {context.crisis_id} in {total_elapsed}ms via Antigravity v2.0 orchestration. {len(context.agent_traces)} agents executed. {gemini_count} Gemini-enhanced. {len(context.action_plan)} response actions {'executed' if context.simulation else 'planned'}.",
            map_data=map_data,
            orchestration_workflow=workflow_steps,
        )

        # Store in memory + log + Firebase
        result_payload = result.model_dump()
        log_payload = {
            "crisis_id": context.crisis_id,
            "timestamp": context.created_at,
            "crisis_type": result.crisis_type,
            "city": result.city,
            "severity": result.severity,
            "gemini_enhanced": gemini_count > 0,
            "traces": [t.model_dump() for t in context.agent_traces],
        }
        CRISIS_STORE[context.crisis_id] = result_payload
        LOG_STORE.append(log_payload)
        firebase.save_crisis(context.crisis_id, result_payload)
        firebase.save_log(log_payload)

        return result

    def get_crisis(self, crisis_id: str) -> Optional[dict]:
        return CRISIS_STORE.get(crisis_id)

    def get_logs(self) -> list:
        return LOG_STORE[-20:]

    def get_workflow_template(self) -> list:
        """Return the static pipeline template for UI pre-rendering."""
        return [
            {"step": s["step"], "agent": s["agent"], "purpose": s["purpose"], "tools": tools}
            for s, tools in zip(self.PIPELINE, [
                ["keyword_detector", "language_classifier", "entity_extractor"],
                ["weather_api", "traffic_api", "social_media_scanner"],
                ["population_estimator", "infrastructure_scanner", "impact_modeler"],
                ["action_template_engine", "dispatch_coordinator", "alert_system"],
                ["congestion_simulator", "dispatch_engine", "alert_broadcaster"],
                ["system_health_check", "resilience_auditor"],
            ])
        ]


# Singleton orchestrator instance
orchestrator = AntigravityOrchestrator()
