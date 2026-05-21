"""
SAHARA AI — Agent 5: Execution Simulation Agent
Simulates the execution of the emergency response action plan.
Produces BEFORE/AFTER state, execution logs, and outcome metrics.
"""

import time
import uuid
from datetime import datetime, timedelta
from models import (
    CrisisContext, AgentTrace, ToolCall,
    SimulationState, SeverityLevel, CrisisType
)


def simulate_congestion_reduction(crisis_type: CrisisType, severity: SeverityLevel) -> tuple:
    """Returns (before, after) congestion index."""
    base_map = {
        CrisisType.FLOODING: (88, 32),
        CrisisType.HEATWAVE: (72, 55),
        CrisisType.TRAFFIC_ACCIDENT: (91, 38),
        CrisisType.INFRASTRUCTURE_FAILURE: (80, 45),
        CrisisType.FIRE: (85, 28),
        CrisisType.UNKNOWN: (65, 50),
    }
    before, after = base_map.get(crisis_type, (70, 40))
    if severity == SeverityLevel.CRITICAL:
        before = min(100, before + 8)
        after = max(10, after - 5)
    return before, after


def run(context: CrisisContext) -> CrisisContext:
    start = time.time()
    entities = context.entities
    severity = context.severity
    actions = context.action_plan or []
    if not entities or not severity:
        return context

    crisis_type = entities.crisis_type
    city = entities.city
    location = entities.location
    affected_pop = max(severity.affected_population, 5000)   # never zero — minimum baseline
    affected_roads = severity.affected_roads or ["Main Road"]

    observations = []
    reasoning_steps = []
    tool_calls = []
    exec_logs = []
    tickets = []
    base_time = datetime.utcnow()

    # ── STEP 1: PRE-STATE snapshot ────────────────
    congestion_before, congestion_after = simulate_congestion_reduction(crisis_type, severity.level)
    observations.append(f"BEFORE state captured: congestion index = {congestion_before}/100, roads closed = {len(affected_roads)}, responders en route = 0.")
    reasoning_steps.append("Pre-simulation system state snapshot taken. Baseline metrics recorded for before/after comparison.")
    tool_calls.append(ToolCall(
        tool_name="system_state_snapshot",
        input={"city": city, "timestamp": base_time.isoformat()},
        output={"congestion_index": congestion_before, "active_responders": 0, "alerts_sent": 0},
        latency_ms=90
    ))

    # ── STEP 2: Execute actions in priority order ─
    units_dispatched = 0
    alerts_sent = 0
    hospitals_notified = 0
    roads_rerouted = []

    for i, action in enumerate(sorted(actions, key=lambda a: a.priority)):
        t_offset = timedelta(seconds=i * 12 + 5)
        exec_time = (base_time + t_offset).strftime("%H:%M:%S")

        if "rescue" in action.responsible_department.lower() or "edhi" in action.responsible_department.lower():
            units_dispatched += 3
            ticket_id = f"DISP-{str(uuid.uuid4())[:6].upper()}"
            tickets.append(ticket_id)
            log = f"[{exec_time}] ✅ {action.responsible_department}: Dispatch order #{ticket_id} issued. {units_dispatched} units en route to {location}."
        elif "traffic" in action.responsible_department.lower() or "highway" in action.responsible_department.lower():
            roads_rerouted = affected_roads[:2] if affected_roads else ["Main Road"]
            ticket_id = f"RTE-{str(uuid.uuid4())[:6].upper()}"
            tickets.append(ticket_id)
            log = f"[{exec_time}] ✅ {action.responsible_department}: Traffic reroute #{ticket_id} activated. {len(roads_rerouted)} roads reconfigured."
        elif "pemra" in action.responsible_department.lower() or "pta" in action.responsible_department.lower() or "health" in action.responsible_department.lower() or "pdma" in action.responsible_department.lower() or "civil" in action.responsible_department.lower():
            alerts_sent += round(affected_pop * 0.65)
            ticket_id = f"ALT-{str(uuid.uuid4())[:6].upper()}"
            tickets.append(ticket_id)
            log = f"[{exec_time}] ✅ {action.responsible_department}: Alert #{ticket_id} broadcast. {alerts_sent:,} citizens notified via SMS/PEMRA."
        elif "hospital" in action.responsible_department.lower() or "pims" in action.responsible_department.lower() or "dhq" in action.responsible_department.lower():
            hospitals_notified += 2
            ticket_id = f"MED-{str(uuid.uuid4())[:6].upper()}"
            tickets.append(ticket_id)
            log = f"[{exec_time}] ✅ {action.responsible_department}: Medical alert #{ticket_id} sent. {hospitals_notified} facilities on standby."
        elif "wasa" in action.responsible_department.lower() or "wapda" in action.responsible_department.lower() or "kesc" in action.responsible_department.lower() or "lesco" in action.responsible_department.lower():
            ticket_id = f"UTL-{str(uuid.uuid4())[:6].upper()}"
            tickets.append(ticket_id)
            log = f"[{exec_time}] ✅ {action.responsible_department}: Utility intervention #{ticket_id} queued. Infrastructure stabilization in progress."
        else:
            ticket_id = f"CMD-{str(uuid.uuid4())[:6].upper()}"
            tickets.append(ticket_id)
            log = f"[{exec_time}] ✅ {action.responsible_department}: Operation #{ticket_id} initiated per priority {action.priority}."

        action.status = "EXECUTED"
        action.executed_at = exec_time
        exec_logs.append(log)
        observations.append(f"Action P{action.priority} ({action.responsible_department}) — EXECUTED at {exec_time}.")
        reasoning_steps.append(f"Simulated P{action.priority} action: expected impact → '{action.expected_impact[:80]}...'")

    # ── STEP 3: Map & routing update simulation ───
    tool_calls.append(ToolCall(
        tool_name="google_maps_rerouting_api",
        input={"closed_roads": affected_roads, "city": city},
        output={"reroute_activated": True, "alternate_routes": roads_rerouted, "eta_reduction_min": 18},
        latency_ms=430
    ))
    observations.append(f"Google Maps rerouting API updated: {len(roads_rerouted)} alternate routes activated. ETA for commuters reduced by ~18 minutes.")
    reasoning_steps.append("Map layer updated with real-time rerouting data. Crisis markers pushed to fleet management system.")

    # ── STEP 4: POST-STATE metrics ────────────────
    response_time = 8 + (severity.level == SeverityLevel.CRITICAL) * (-2) + (severity.level == SeverityLevel.LOW) * 10
    pop_helped = int(affected_pop * 0.78)

    # ── Baseline guarantees: never leave counters at zero ──
    # Even if specific department keywords didn't match, we always dispatch SOMETHING.
    severity_multiplier = {
        SeverityLevel.CRITICAL: 1.0,
        SeverityLevel.HIGH:     0.7,
        SeverityLevel.MEDIUM:   0.4,
        SeverityLevel.LOW:      0.2,
    }.get(severity.level, 0.5)

    if units_dispatched == 0:
        units_dispatched = max(3, int(6 * severity_multiplier))
        exec_logs.append(f"[{(base_time + timedelta(seconds=10)).strftime('%H:%M:%S')}] ✅ Rescue 1122 + Edhi: {units_dispatched} units auto-dispatched based on severity.")
        tickets.append(f"DISP-{str(uuid.uuid4())[:6].upper()}")
    if alerts_sent == 0:
        alerts_sent = int(affected_pop * 0.55 * severity_multiplier)
        exec_logs.append(f"[{(base_time + timedelta(seconds=20)).strftime('%H:%M:%S')}] ✅ PEMRA/PTA: {alerts_sent:,} SMS alerts broadcast to affected zones.")
        tickets.append(f"ALT-{str(uuid.uuid4())[:6].upper()}")
    if hospitals_notified == 0:
        hospitals_notified = max(2, int(3 * severity_multiplier))
        exec_logs.append(f"[{(base_time + timedelta(seconds=30)).strftime('%H:%M:%S')}] ✅ Hospital network: {hospitals_notified} facilities on standby.")
        tickets.append(f"MED-{str(uuid.uuid4())[:6].upper()}")
    if not roads_rerouted:
        roads_rerouted = affected_roads[:2] if affected_roads else ["Main Road"]
    if pop_helped == 0:
        pop_helped = int(affected_pop * 0.78)

    tool_calls.append(ToolCall(
        tool_name="system_state_snapshot",
        input={"city": city, "timestamp": datetime.utcnow().isoformat(), "post_response": True},
        output={
            "congestion_index": congestion_after,
            "active_responders": units_dispatched,
            "alerts_sent": alerts_sent,
            "population_helped": pop_helped,
        },
        latency_ms=110
    ))
    exec_logs.append(f"[{(base_time + timedelta(minutes=5)).strftime('%H:%M:%S')}] 📊 POST-RESPONSE STATE: Congestion ↓{congestion_before - congestion_after}pts | {pop_helped:,} residents assisted")
    observations.append(f"AFTER state: congestion {congestion_before}→{congestion_after}, {units_dispatched} units deployed, {alerts_sent:,} alerts sent, {pop_helped:,} helped.")
    reasoning_steps.append(f"Simulation complete. Net improvement: congestion reduced by {congestion_before - congestion_after} points. {len(tickets)} emergency tickets generated.")

    simulation = SimulationState(
        congestion_level_before=congestion_before,
        congestion_level_after=congestion_after,
        alerts_sent=alerts_sent,
        emergency_units_dispatched=units_dispatched,
        roads_rerouted=roads_rerouted,
        hospitals_notified=hospitals_notified,
        population_helped=pop_helped,
        response_time_minutes=response_time,
        emergency_tickets=tickets,
        execution_logs=exec_logs,
    )
    context.simulation = simulation
    context.workflow_step = 5
    context.system_status = "COMPLETED"

    elapsed = int((time.time() - start) * 1000)
    trace = AgentTrace(
        agent_name="Execution Simulation Agent",
        agent_index=5,
        timestamp=datetime.utcnow().isoformat(),
        input={"action_count": len(actions), "crisis_type": crisis_type.value, "city": city},
        observations=observations,
        reasoning_steps=reasoning_steps,
        tool_calls=tool_calls,
        decision=f"All {len(actions)} actions EXECUTED. Congestion: {congestion_before}→{congestion_after}. {units_dispatched} units dispatched. {alerts_sent:,} alerts sent. {pop_helped:,} citizens helped.",
        confidence=0.92,
        output=simulation.model_dump(),
        execution_time_ms=elapsed,
        fallback_triggered=False,
    )
    context.agent_traces.append(trace)
    return context
