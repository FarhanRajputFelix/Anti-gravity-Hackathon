/// SAHARA AI — Agent 5: Execution Simulation Agent
/// Simulates execution of all response actions, generates tickets, and calculates impact.

import 'dart:math';
import '../base_agent.dart';
import '../agent_memory.dart';

class ExecutionSimulationAgent extends BaseAgent {
  @override String get name => 'Execution Simulation Agent';
  @override int get index => 5;
  @override String get description => 'Simulates real-time execution of response plan — dispatch, rerouting, alerts';
  @override List<String> get tools => ['system_state_snapshot', 'dispatch_engine', 'google_maps_rerouting_api', 'alert_broadcast_engine'];

  @override
  Future<AgentMemory> execute(AgentMemory memory, {AgentProgressCallback? onProgress}) async {
    final sw = Stopwatch()..start();
    final observations = <String>[];
    final reasoning = <String>[];
    final toolCalls = <Map<String, dynamic>>[];
    final rng = Random();
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // ── Tool 1: Pre-Simulation State Snapshot ──
    onProgress?.call(name, 'Taking pre-simulation state snapshot...', 0.1);
    await simulateLatency(90);

    observations.add('BEFORE: congestion ${memory.congestionBefore}/100, 0 responders, 0 alerts sent.');
    reasoning.add('Pre-simulation state snapshot taken at $timeStr:00.');
    toolCalls.add(makeToolCall('system_state_snapshot', 90));

    // ── Tool 2: Dispatch Engine ──
    onProgress?.call(name, 'Dispatching emergency units...', 0.3);
    await simulateLatency(300);

    memory.unitsDispatched = memory.severity == 'CRITICAL' ? 6 : 3;
    memory.emergencyTickets = [];

    final ticketPrefixes = ['DISP', 'RTE', 'ALT', 'MED', 'EVA', 'INF'];
    for (int i = 0; i < memory.actionPlan.length && i < ticketPrefixes.length; i++) {
      final hex = (rng.nextInt(0xFFFFFF)).toRadixString(16).toUpperCase().padLeft(6, '0');
      final ticket = '${ticketPrefixes[i]}-${hex.substring(0, 6)}';
      memory.emergencyTickets.add(ticket);

      final action = memory.actionPlan[i];
      final dept = action['department'] ?? 'Response Team';
      final secondsOffset = 12 * i;
      final logTime = '$timeStr:${secondsOffset.toString().padLeft(2, '0')}';
      memory.executionLogs.add('[$logTime] ✅ $dept: Dispatch order #$ticket issued. ${action['resources'] ?? 'Units deployed'}.');
      observations.add('P${i + 1}: $dept — ${action['action']}. Ticket $ticket.');
    }
    reasoning.add('Actions executed in priority order with 12-second stagger intervals.');
    toolCalls.add(makeToolCall('dispatch_engine', 300));

    // ── Tool 3: Google Maps Rerouting ──
    onProgress?.call(name, 'Activating route rerouting via Google Maps...', 0.6);
    await simulateLatency(430);

    if (memory.affectedRoads.length >= 2) {
      memory.roadsRerouted = [memory.affectedRoads[0], memory.affectedRoads[1]];
    } else if (memory.affectedRoads.isNotEmpty) {
      memory.roadsRerouted = [memory.affectedRoads[0]];
    } else {
      memory.roadsRerouted = ['Main affected route'];
    }

    reasoning.add('Google Maps rerouting API updated — ${memory.roadsRerouted.length} alternate routes activated, ETA -18 min.');
    toolCalls.add(makeToolCall('google_maps_rerouting_api', 430));

    // ── Tool 4: Alert Broadcast ──
    onProgress?.call(name, 'Broadcasting emergency alerts...', 0.8);
    await simulateLatency(200);

    memory.alertsSent = memory.populationAffected > 50000 ? 34320 + rng.nextInt(5000) : 12000 + rng.nextInt(3000);
    memory.hospitalsNotified = memory.severity == 'CRITICAL' ? 3 : 1;

    toolCalls.add(makeToolCall('alert_broadcast_engine', 200));

    // ── Calculate Post-Simulation State ──
    onProgress?.call(name, 'Computing post-response state...', 0.9);
    await simulateLatency(110);

    // Congestion reduction based on severity and actions
    final reductionPct = memory.severity == 'CRITICAL' ? 0.63 : memory.severity == 'HIGH' ? 0.5 : 0.35;
    memory.congestionAfter = max(15, (memory.congestionBefore * (1 - reductionPct)).round());
    memory.populationHelped = (memory.populationAffected * (0.5 + rng.nextDouble() * 0.3)).round();

    final congDrop = memory.congestionBefore - memory.congestionAfter;
    memory.executionLogs.add('[$timeStr:${(12 * memory.actionPlan.length + 30).toString().padLeft(2, '0')}] 📊 POST-RESPONSE: Congestion ↓${congDrop}pts | ${_formatNum(memory.populationHelped)} residents assisted');

    observations.add('AFTER: congestion ${memory.congestionAfter}/100, ${memory.unitsDispatched} units active, ${_formatNum(memory.alertsSent)} alerts, ${_formatNum(memory.populationHelped)} helped.');

    toolCalls.add(makeToolCall('system_state_snapshot', 110));

    sw.stop();
    final execTime = sw.elapsedMilliseconds;

    memory.agentTraces.add(AgentTrace(
      agentName: name,
      agentIndex: index,
      confidence: 0.88 + rng.nextDouble() * 0.07,
      executionTimeMs: execTime,
      decision: 'All ${memory.actionPlan.length} actions EXECUTED. Congestion: ${memory.congestionBefore}→${memory.congestionAfter}. ${_formatNum(memory.alertsSent)} alerts sent. ${_formatNum(memory.populationHelped)} citizens helped.',
      observations: observations,
      reasoningSteps: reasoning,
      toolCalls: toolCalls,
    ));

    onProgress?.call(name, 'Complete ✓', 1.0);
    return memory;
  }

  String _formatNum(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}
