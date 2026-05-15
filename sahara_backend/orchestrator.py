"""
SAHARA AI — Antigravity Orchestrator
The central intelligence layer that coordinates all 6 specialized agents.

Responsibilities:
- Task decomposition and workflow planning
- Sequential agent invocation with shared CrisisContext
- Reasoning trace management
- Fallback routing and retry handling
- State synchronization across agents
- Final result aggregation
"""

import time
import uuid
from datetime import datetime
from typing import Optional
from models import (
    CrisisContext, CrisisSignal, AnalysisResult,
    FallbackEntry, VerificationStatus
)
from mock_data import MAP_CRISIS_DATA, DEMO_SCENARIOS

# ── Import all 6 specialized agents ───────────────
from agents import signal_ingestion, verification, severity_analysis
from agents import response_planning, execution_simulation, fallback_recovery

# In-memory crisis store (acts as lightweight Firebase stand-in)
CRISIS_STORE: dict = {}
LOG_STORE: list = []


class AntigravityOrchestrator:
    """
    The Antigravity Orchestrator coordinates all 6 SAHARA AI agents.

    Execution Plan:
    ┌─────────────────────────────────────────┐
    │  Step 1 │ Signal Ingestion Agent         │
    │  Step 2 │ Verification Agent             │
    │  Step 3 │ [Fallback if contradicted]     │
    │  Step 4 │ Severity Analysis Agent        │
    │  Step 5 │ Response Planning Agent        │
    │  Step 6 │ Execution Simulation Agent     │
    │  Step 7 │ Fallback & Recovery Agent      │
    │  Step 8 │ Aggregate + Return Results     │
    └─────────────────────────────────────────┘
    """

    def __init__(self):
        self.name = "Antigravity Orchestrator v1.0"
        self.version = "1.0.0"

    def create_execution_plan(self, context: CrisisContext) -> list:
        """Task decomposition — generates ordered execution plan."""
        plan = [
            {"step": 1, "agent": "Signal Ingestion Agent", "purpose": "Parse multilingual signal -> structured data"},
            {"step": 2, "agent": "Verification Agent", "purpose": "Cross-check APIs -> confidence score"},
            {"step": 3, "agent": "Severity Analysis Agent", "purpose": "Estimate impact -> severity level"},
            {"step": 4, "agent": "Response Planning Agent", "purpose": "Generate actionable response plan"},
            {"step": 5, "agent": "Execution Simulation Agent", "purpose": "Simulate response + produce before/after state"},
            {"step": 6, "agent": "Fallback & Recovery Agent", "purpose": "Final resilience audit + system health check"},
        ]
        # Log execution plan (metadata not stored in strict Pydantic model)
        return plan

    def _should_trigger_fallback(self, context: CrisisContext) -> bool:
        """Evaluates whether fallback logic is needed after verification."""
        if not context.verification:
            return True
        status = context.verification.status
        # Trigger fallback if: contradicted, uncertain, or any API failures logged
        return (
            status in [VerificationStatus.CONTRADICTED, VerificationStatus.UNCERTAIN]
            or len(context.fallback_history) > 0
        )

    def _get_map_data(self, context: CrisisContext) -> dict:
        """Determine which map overlay data to return based on detected crisis."""
        if not context.entities:
            return {}
        city = context.entities.city
        crisis_type = context.entities.crisis_type.value.lower()
        # Match scenario key
        for key, data in MAP_CRISIS_DATA.items():
            if city in key:
                return data
        return {}

    async def analyze(self, signal: CrisisSignal) -> AnalysisResult:
        """
        Full orchestrated workflow for a crisis signal.
        This is the primary entry point called by the API.
        """
        workflow_start = time.time()

        # ── INITIALIZE Crisis Context ──────────────────
        context = CrisisContext(
            crisis_id=f"CRS-{str(uuid.uuid4())[:8].upper()}",
            created_at=datetime.utcnow().isoformat(),
            signals=[signal],
        )

        print(f"\n{'='*60}")
        print(f"[ANTIGRAVITY] Crisis ID: {context.crisis_id}")
        print(f"[ANTIGRAVITY] Creating execution plan...")

        plan = self.create_execution_plan(context)
        for step in plan:
            print(f"  Step {step['step']}: {step['agent']} -> {step['purpose']}")

        print(f"[ANTIGRAVITY] Execution plan created. Initiating agent pipeline...")
        print(f"{'='*60}\n")

        # ── STEP 1: Signal Ingestion Agent ────────────
        print(f"[ANTIGRAVITY] → Invoking Agent 1: Signal Ingestion Agent")
        context = signal_ingestion.run(context)
        print(f"[ANTIGRAVITY] ✓ Agent 1 complete: {context.entities.crisis_type.value if context.entities else 'UNKNOWN'} in {context.entities.city if context.entities else '?'}")

        # ── STEP 2: Verification Agent ─────────────────
        print(f"[ANTIGRAVITY] → Invoking Agent 2: Verification Agent")
        context = verification.run(context)
        conf = context.verification.confidence_score if context.verification else 0
        print(f"[ANTIGRAVITY] ✓ Agent 2 complete: confidence={conf:.0%}, status={context.verification.status.value if context.verification else 'UNKNOWN'}")

        # ── STEP 3: Conditional Fallback ───────────────
        if self._should_trigger_fallback(context):
            print(f"[ANTIGRAVITY] ⚡ Fallback condition detected! Routing to Fallback Agent...")
            context = fallback_recovery.run(context)
            print(f"[ANTIGRAVITY] ✓ Fallback Agent handled {len(context.fallback_history)} issue(s)")
        else:
            print(f"[ANTIGRAVITY] ✓ No fallback needed — all primary APIs nominal")

        # ── STEP 4: Severity Analysis Agent ───────────
        print(f"[ANTIGRAVITY] → Invoking Agent 3: Severity Analysis Agent")
        context = severity_analysis.run(context)
        sev_label = context.severity.level.value if context.severity else 'UNKNOWN'
        sev_pop = f"{context.severity.affected_population:,}" if context.severity else "0"
        print(f"[ANTIGRAVITY] ✓ Agent 3 complete: severity={sev_label}, pop={sev_pop}")

        # ── STEP 5: Response Planning Agent ───────────
        print(f"[ANTIGRAVITY] → Invoking Agent 4: Response Planning Agent")
        context = response_planning.run(context)
        print(f"[ANTIGRAVITY] ✓ Agent 4 complete: {len(context.action_plan)} actions generated")

        # ── STEP 6: Execution Simulation Agent ────────
        print(f"[ANTIGRAVITY] → Invoking Agent 5: Execution Simulation Agent")
        context = execution_simulation.run(context)
        sim = context.simulation
        print(f"[ANTIGRAVITY] ✓ Agent 5 complete: congestion {sim.congestion_level_before}→{sim.congestion_level_after} | {sim.alerts_sent:,} alerts" if sim else "")

        # ── STEP 7: Final Fallback Audit ───────────────
        print(f"[ANTIGRAVITY] → Invoking Agent 6: Fallback & Recovery Agent (final audit)")
        # Only run if not already triggered, or always run for final health check
        already_run = any(t.agent_name == "Fallback & Recovery Agent" for t in context.agent_traces)
        if not already_run:
            context = fallback_recovery.run(context)

        # If already ran, log it as health audit only (skip re-adding)
        print(f"[ANTIGRAVITY] ✓ Agent 6 complete: {len(context.fallback_history)} fallback entries logged")

        # ── STEP 8: Aggregate result ───────────────────
        total_elapsed = int((time.time() - workflow_start) * 1000)
        print(f"\n[ANTIGRAVITY] ✅ Full pipeline complete in {total_elapsed}ms")
        print(f"[ANTIGRAVITY] Generating final AnalysisResult...")

        entities = context.entities
        verif = context.verification
        sev = context.severity

        map_data = self._get_map_data(context)

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
            system_message=f"SAHARA AI processed crisis {context.crisis_id} in {total_elapsed}ms via Antigravity orchestration. {len(context.agent_traces)} agent traces generated. {len(context.action_plan)} response actions {'executed' if context.simulation else 'planned'}.",
            map_data=map_data,
        )

        # Store in memory + log
        CRISIS_STORE[context.crisis_id] = result.dict()
        LOG_STORE.append({
            "crisis_id": context.crisis_id,
            "timestamp": context.created_at,
            "traces": [t.dict() for t in context.agent_traces],
        })

        return result

    def get_crisis(self, crisis_id: str) -> Optional[dict]:
        return CRISIS_STORE.get(crisis_id)

    def get_logs(self) -> list:
        return LOG_STORE[-20:]  # Return last 20 analyses


# Singleton orchestrator instance
orchestrator = AntigravityOrchestrator()
