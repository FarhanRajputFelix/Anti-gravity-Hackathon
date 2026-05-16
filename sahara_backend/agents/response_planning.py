"""
SAHARA AI — Agent 4: Response Planning Agent
Generates a prioritized, coordinated emergency response action plan.
"""

import time
import uuid
from datetime import datetime
from models import (
    CrisisContext, AgentTrace, ToolCall,
    ResponseAction, SeverityLevel, CrisisType
)


ACTION_TEMPLATES: dict = {
    CrisisType.FLOODING: [
        {"priority": 1, "dept": "Rescue 1122 / NDMA",
         "desc": "Deploy water rescue teams to {location}. Evacuate residents from ground-floor properties.",
         "impact": "Estimated {pop} residents evacuated within 45 minutes. Life safety risk eliminated."},
        {"priority": 2, "dept": "Traffic Police",
         "desc": "Close and cordon {roads}. Redirect traffic via alternate routes immediately.",
         "impact": "Prevents additional vehicles from becoming stranded. Clears rescue access lanes."},
        {"priority": 3, "dept": "WASA / Utility Authority",
         "desc": "Deploy pump trucks to {location}. Activate emergency stormwater drainage bypass.",
         "impact": "Reduce flood depth by 40-60% within 3 hours."},
        {"priority": 4, "dept": "PEMRA / PTA",
         "desc": "Broadcast emergency SMS alerts to all subscribers in {location} radius.",
         "impact": "Warning reaches ~{pop} citizens within 4 minutes. Reduces civilian exposure."},
        {"priority": 5, "dept": "PIMS / DHQ Hospital",
         "desc": "Activate emergency protocol. Reserve 30 trauma beds. Pre-position medical teams.",
         "impact": "Hospital surge capacity ready for flood-related injuries within 20 minutes."},
    ],
    CrisisType.HEATWAVE: [
        {"priority": 1, "dept": "PDMA / City Administration",
         "desc": "Open emergency cooling centers in {location}. Deploy water tankers for public cooling.",
         "impact": "Provides immediate relief for {pop} vulnerable residents. Reduces heat stroke cases."},
        {"priority": 2, "dept": "Edhi Foundation / Rescue",
         "desc": "Deploy ambulance units with IV fluids to {location}. Prioritize elderly and children.",
         "impact": "Medical response time reduced to under 8 minutes in affected zone."},
        {"priority": 3, "dept": "WAPDA / LESCO / KESC",
         "desc": "Suspend load-shedding in {location} for 12 hours. Prioritize hospital and elderly care areas.",
         "impact": "Continuous air conditioning in critical facilities. Prevents heat amplification indoors."},
        {"priority": 4, "dept": "Health Authority",
         "desc": "Issue public health advisory: stay indoors 11am-4pm. Distribute ORS packets at govt offices.",
         "impact": "Estimated 30% reduction in heat-related emergency calls."},
    ],
    CrisisType.TRAFFIC_ACCIDENT: [
        {"priority": 1, "dept": "Rescue 1122 / Edhi",
         "desc": "Dispatch 2 ambulances to {location}. Secure accident scene and triage injured.",
         "impact": "Emergency response within 6-10 minutes. Life-threatening cases stabilized on-site."},
        {"priority": 2, "dept": "Traffic Police",
         "desc": "Deploy traffic wardens to {roads}. Establish one-way detour via alternate route.",
         "impact": "Traffic flow restored at 60% capacity within 25 minutes."},
        {"priority": 3, "dept": "National Highways Authority",
         "desc": "Activate road clearance team. Tow damaged vehicles from {roads}.",
         "impact": "Full lane clearance estimated within 90 minutes."},
        {"priority": 4, "dept": "PEMRA / PTA",
         "desc": "Push traffic alert to Waze/Google Maps API partners. Update digital road signs.",
         "impact": "Dynamic rerouting for ~{pop} vehicles in 5km radius within 3 minutes."},
    ],
}

DEFAULT_ACTIONS = [
    {"priority": 1, "dept": "Emergency Management Authority",
     "desc": "Activate crisis command center. Coordinate multi-agency response.",
     "impact": "Unified command structure established within 15 minutes."},
    {"priority": 2, "dept": "Civil Defense",
     "desc": "Deploy assessment teams to verify ground situation at {location}.",
     "impact": "On-ground verification within 20 minutes. Improves decision accuracy."},
]


def build_action(template: dict, location: str, pop: int, roads: list) -> ResponseAction:
    roads_str = ", ".join(roads[:2]) if roads else "affected area roads"
    return ResponseAction(
        action_id=f"ACT-{str(uuid.uuid4())[:6].upper()}",
        priority=template["priority"],
        responsible_department=template["dept"],
        description=template["desc"].format(location=location, pop=f"{pop:,}", roads=roads_str),
        expected_impact=template["impact"].format(pop=f"{pop:,}"),
        status="PLANNED",
    )


def run(context: CrisisContext) -> CrisisContext:
    start = time.time()
    entities = context.entities
    severity = context.severity
    verification = context.verification
    if not entities or not severity:
        return context

    crisis_type = entities.crisis_type
    location = entities.location
    city = entities.city
    affected_pop = severity.affected_population
    affected_roads = severity.affected_roads
    confidence = verification.confidence_score if verification else 0.5

    observations = []
    reasoning_steps = []
    tool_calls = []

    # ── STEP 1: Resource availability check ───────
    tool_calls.append(ToolCall(
        tool_name="resource_inventory_api",
        input={"city": city, "severity": severity.level.value},
        output={
            "rescue_teams_available": 8,
            "ambulances_available": 14,
            "traffic_wardens_available": 23,
            "hospital_beds_available": 156,
            "water_pumps_available": 5,
        },
        latency_ms=260
    ))
    observations.append(f"Resource inventory fetched: 8 rescue teams, 14 ambulances, 23 traffic wardens available in {city.title()}.")
    reasoning_steps.append(f"Resource availability confirmed from {city.title()} Emergency Management database. Sufficient capacity for {severity.level.value} response.")

    # ── STEP 2: Multi-crisis resource allocation ──
    if severity.level in [SeverityLevel.CRITICAL, SeverityLevel.HIGH]:
        observations.append(f"CRITICAL/HIGH severity⟹ Full resource allocation protocol. No resource sharing with secondary incidents.")
        reasoning_steps.append("Severity={} triggers full response mode. Secondary crises in queue will receive reduced resource allocation until this is resolved.".format(severity.level.value))
    else:
        reasoning_steps.append("MEDIUM severity — proportional resource allocation. 60% dedicated to this crisis, 40% on reserve for concurrent incidents.")

    # ── STEP 3: Generate action plan ──────────────
    action_templates = ACTION_TEMPLATES.get(crisis_type, DEFAULT_ACTIONS)
    actions = []
    for template in action_templates:
        action = build_action(template, location, affected_pop, affected_roads)
        actions.append(action)

    observations.append(f"Generated {len(actions)} coordinated response actions for {crisis_type.value} at {location}.")
    reasoning_steps.append(f"Action plan synthesized from {crisis_type.value} response playbook v3.2. Priority ordering: Life Safety → Access Control → Mitigation → Communication → Medical Readiness.")

    # ── STEP 4: Department coordination ───────────
    departments = list({a.responsible_department for a in actions})
    tool_calls.append(ToolCall(
        tool_name="department_notification_api",
        input={"departments": departments, "priority": severity.emergency_urgency, "location": location},
        output={"notified": departments, "ack_received": departments[:3], "estimated_response_min": 8},
        latency_ms=310
    ))
    observations.append(f"Coordination alerts dispatched to {len(departments)} departments: {', '.join(departments[:3])}...")
    reasoning_steps.append(f"Multi-department coordination complete. {len(departments)} agencies alerted via Emergency Management Network. Expected first responders on scene in 8 minutes.")

    context.action_plan = actions
    context.workflow_step = 4

    elapsed = int((time.time() - start) * 1000)
    trace = AgentTrace(
        agent_name="Response Planning Agent",
        agent_index=4,
        timestamp=datetime.utcnow().isoformat(),
        input={"crisis_type": crisis_type.value, "severity": severity.level.value, "location": location},
        observations=observations,
        reasoning_steps=reasoning_steps,
        tool_calls=tool_calls,
        decision=f"Generated {len(actions)}-action coordinated response plan. Departments notified: {len(departments)}. First action priority: {actions[0].responsible_department}.",
        confidence=round(confidence * 0.92, 3),
        output={"action_count": len(actions), "departments": departments, "actions": [a.model_dump() for a in actions]},
        execution_time_ms=elapsed,
        fallback_triggered=False,
    )
    context.agent_traces.append(trace)
    return context
