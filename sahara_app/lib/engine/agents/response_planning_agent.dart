/// SAHARA AI — Agent 4: Response Planning Agent
/// Generates coordinated emergency response actions based on severity and resources.

import '../base_agent.dart';
import '../agent_memory.dart';

class ResponsePlanningAgent extends BaseAgent {
  @override String get name => 'Response Planning Agent';
  @override int get index => 4;
  @override String get description => 'Generates coordinated multi-department response plan with resource allocation';
  @override List<String> get tools => ['resource_inventory_api', 'department_notification_api', 'action_playbook_engine'];

  static final _responsePlaybooks = {
    'FLOODING': [
      {'priority': 1, 'action': 'Deploy Rescue 1122 flood units', 'department': 'Rescue 1122', 'resources': '3 boats, 8 rescue divers', 'eta_min': 8},
      {'priority': 2, 'action': 'Activate traffic rerouting', 'department': 'Traffic Police', 'resources': '12 wardens, 4 checkpoints', 'eta_min': 5},
      {'priority': 3, 'action': 'Activate WASA emergency pumps', 'department': 'WASA', 'resources': '6 mobile pumps, 2 tankers', 'eta_min': 15},
      {'priority': 4, 'action': 'Broadcast emergency alert via PEMRA', 'department': 'PEMRA/PTA', 'resources': 'SMS + TV broadcast', 'eta_min': 2},
      {'priority': 5, 'action': 'Alert hospitals for casualties', 'department': 'PIMS/Jinnah Hospital', 'resources': '4 ambulances, ER standby', 'eta_min': 10},
    ],
    'HEATWAVE': [
      {'priority': 1, 'action': 'Activate cooling centers', 'department': 'Municipal Corporation', 'resources': '12 cooling stations', 'eta_min': 20},
      {'priority': 2, 'action': 'Deploy mobile medical units', 'department': 'Health Department', 'resources': '8 units, IV drip supplies', 'eta_min': 15},
      {'priority': 3, 'action': 'Emergency water distribution', 'department': 'WASA', 'resources': '10 water tankers', 'eta_min': 25},
      {'priority': 4, 'action': 'Public heat advisory broadcast', 'department': 'PEMRA', 'resources': 'All media channels', 'eta_min': 3},
      {'priority': 5, 'action': 'Hospital capacity surge', 'department': 'Civil Hospital', 'resources': '50 extra beds', 'eta_min': 30},
    ],
    'EARTHQUAKE': [
      {'priority': 1, 'action': 'Deploy NDMA search & rescue teams', 'department': 'NDMA', 'resources': '5 SAR teams, K-9 units', 'eta_min': 12},
      {'priority': 2, 'action': 'Structural damage assessment', 'department': 'Building Control Authority', 'resources': '4 engineer teams', 'eta_min': 20},
      {'priority': 3, 'action': 'Emergency medical response', 'department': 'Rescue 1122', 'resources': '10 ambulances, trauma kits', 'eta_min': 8},
      {'priority': 4, 'action': 'Gas pipeline shutdown', 'department': 'SNGPL/SSGC', 'resources': 'Remote shutoff valves', 'eta_min': 5},
      {'priority': 5, 'action': 'Evacuation shelters activation', 'department': 'District Admin', 'resources': '3 shelter sites', 'eta_min': 30},
    ],
    'ACCIDENT': [
      {'priority': 1, 'action': 'Dispatch emergency ambulances', 'department': 'Rescue 1122', 'resources': '3 ambulances', 'eta_min': 6},
      {'priority': 2, 'action': 'Clear road and manage traffic', 'department': 'Traffic Police', 'resources': '8 wardens, crane', 'eta_min': 10},
      {'priority': 3, 'action': 'Hospital trauma alert', 'department': 'Jinnah Hospital', 'resources': 'Trauma unit standby', 'eta_min': 8},
      {'priority': 4, 'action': 'Traffic rerouting', 'department': 'Traffic Police', 'resources': '3 alternate routes', 'eta_min': 5},
    ],
  };

  @override
  Future<AgentMemory> execute(AgentMemory memory, {AgentProgressCallback? onProgress}) async {
    final sw = Stopwatch()..start();
    final observations = <String>[];
    final reasoning = <String>[];
    final toolCalls = <Map<String, dynamic>>[];

    final playbook = _responsePlaybooks[memory.crisisType] ?? _responsePlaybooks['ACCIDENT']!;

    // ── Tool 1: Resource Inventory ──
    onProgress?.call(name, 'Checking resource inventory...', 0.2);
    await simulateLatency(260);

    memory.rescueTeamsAvailable = memory.severity == 'CRITICAL' ? 8 : 4;
    memory.ambulancesAvailable = memory.severity == 'CRITICAL' ? 14 : 6;

    observations.add('Resource inventory: ${memory.rescueTeamsAvailable} rescue teams, ${memory.ambulancesAvailable} ambulances available.');
    observations.add('${memory.severity} severity → ${memory.severity == "CRITICAL" ? "Full" : "Partial"} resource allocation, no sharing with secondary incidents.');
    reasoning.add('Action playbook v3.2 loaded for ${memory.crisisType} scenario.');
    toolCalls.add(makeToolCall('resource_inventory_api', 260));

    // ── Tool 2: Department Notification ──
    onProgress?.call(name, 'Notifying emergency departments...', 0.5);
    await simulateLatency(310);

    memory.departmentsNotified = playbook.map((a) => a['department']).toSet().length;

    final deptList = playbook.map((a) => a['department']).toSet().join(' + ');
    observations.add('${memory.departmentsNotified} departments notified via Emergency Management Network.');
    reasoning.add('Dept coordination: $deptList alerted.');
    toolCalls.add(makeToolCall('department_notification_api', 310));

    // ── Tool 3: Action Playbook Generation ──
    onProgress?.call(name, 'Generating coordinated action plan...', 0.8);
    await simulateLatency(180);

    memory.actionPlan = playbook.map((a) => Map<String, dynamic>.from(a)).toList();

    final priorityOrder = playbook.map((a) => (a['action'] as String).split(' ').take(3).join(' ')).join(' → ');
    reasoning.add('Priority order: $priorityOrder.');
    toolCalls.add(makeToolCall('action_playbook_engine', 180));

    // Calculate ETA
    memory.estimatedResponseMinutes = playbook.map((a) => (a['eta_min'] as int?) ?? 10).reduce((a, b) => a < b ? a : b);

    sw.stop();
    final execTime = sw.elapsedMilliseconds;

    memory.agentTraces.add(AgentTrace(
      agentName: name,
      agentIndex: index,
      confidence: 0.74 + (memory.severity == 'CRITICAL' ? 0.1 : 0.0),
      executionTimeMs: execTime,
      decision: '${playbook.length} coordinated response actions generated. ${memory.departmentsNotified} departments alerted. ETA: ${memory.estimatedResponseMinutes} min.',
      observations: observations,
      reasoningSteps: reasoning,
      toolCalls: toolCalls,
    ));

    onProgress?.call(name, 'Complete ✓', 1.0);
    return memory;
  }
}
