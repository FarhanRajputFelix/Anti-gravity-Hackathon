/// SAHARA AI — Agent 3: Severity Analysis Agent
/// Calculates crisis severity, population impact, and urgency level.

import 'dart:math';
import '../base_agent.dart';
import '../agent_memory.dart';

class SeverityAnalysisAgent extends BaseAgent {
  @override String get name => 'Severity Analysis Agent';
  @override int get index => 3;
  @override String get description => 'Calculates severity, population impact, infrastructure damage, and urgency';
  @override List<String> get tools => ['population_impact_model', 'road_network_analyzer', 'infrastructure_risk_scanner'];

  static final _populationData = {
    'Islamabad': {'sector_pop': 44000, 'total_pop': 1100000, 'density': 'MEDIUM'},
    'Karachi': {'sector_pop': 120000, 'total_pop': 15000000, 'density': 'VERY_HIGH'},
    'Lahore': {'sector_pop': 85000, 'total_pop': 11000000, 'density': 'HIGH'},
    'Peshawar': {'sector_pop': 35000, 'total_pop': 2000000, 'density': 'MEDIUM'},
    'Rawalpindi': {'sector_pop': 55000, 'total_pop': 3600000, 'density': 'HIGH'},
    'Quetta': {'sector_pop': 20000, 'total_pop': 1100000, 'density': 'LOW'},
  };

  static final _roadNetworks = {
    'Islamabad': ['Srinagar Highway', 'G-10 Markaz Road', 'Murree Road', 'IJP Road', 'Margalla Road'],
    'Karachi': ['Shahrah-e-Faisal', 'University Road', 'M.A. Jinnah Road', 'Korangi Road', 'Hub River Road'],
    'Lahore': ['Shahrah-e-Quaid-e-Azam', 'Canal Road', 'GT Road', 'Multan Road', 'Ferozepur Road'],
  };

  @override
  Future<AgentMemory> execute(AgentMemory memory, {AgentProgressCallback? onProgress}) async {
    final sw = Stopwatch()..start();
    final observations = <String>[];
    final reasoning = <String>[];
    final toolCalls = <Map<String, dynamic>>[];
    final rng = Random();

    // Determine city
    final location = memory.extractedLocation ?? '';
    String city = 'Islamabad';
    for (final c in _populationData.keys) {
      if (location.toLowerCase().contains(c.toLowerCase())) {
        city = c;
        break;
      }
    }
    final popData = _populationData[city] ?? _populationData['Islamabad']!;
    final roads = _roadNetworks[city] ?? _roadNetworks['Islamabad']!;

    // ── Tool 1: Population Impact Model ──
    onProgress?.call(name, 'Running population impact model...', 0.15);
    await simulateLatency(210);

    memory.populationAffected = (popData['sector_pop'] as int?) ?? 44000;
    final totalPop = (popData['total_pop'] as int?) ?? 1100000;
    final pctAffected = (memory.populationAffected / totalPop * 100).toStringAsFixed(1);

    observations.add('Population impact model: ${_formatNum(memory.populationAffected)} citizens in affected zone ($pctAffected% of $city).');
    reasoning.add('Crisis type ${memory.crisisType} + confidence ${(memory.verificationConfidence * 100).toStringAsFixed(0)}% + pop ${_formatNum(memory.populationAffected)} → severity threshold calculation.');
    toolCalls.add(makeToolCall('population_impact_model', 210));

    // ── Tool 2: Road Network Analyzer ──
    onProgress?.call(name, 'Analyzing road network impact...', 0.5);
    await simulateLatency(190);

    final congestion = memory.congestionBefore;
    memory.roadsImpacted = min(roads.length, max(1, (congestion / 25).round()));
    memory.affectedRoads = roads.sublist(0, memory.roadsImpacted);

    observations.add('Road network: ${memory.affectedRoads.join(", ")} — ${memory.roadsImpacted} of ${roads.length} arteries disrupted.');
    reasoning.add('$location covers ${memory.roadsImpacted} major road arteries per $city grid analysis.');
    toolCalls.add(makeToolCall('road_network_analyzer', 190));

    // ── Tool 3: Infrastructure Risk Scanner ──
    onProgress?.call(name, 'Scanning infrastructure risk...', 0.75);
    await simulateLatency(150);

    memory.affectedInfrastructure = [];
    if (memory.crisisType == 'FLOODING') {
      memory.affectedInfrastructure = ['Stormwater drainage system', 'Underground electrical grid', 'Telecom fiber lines'];
    } else if (memory.crisisType == 'EARTHQUAKE') {
      memory.affectedInfrastructure = ['Building structures', 'Gas pipelines', 'Water supply network', 'Bridges'];
    } else if (memory.crisisType == 'HEATWAVE') {
      memory.affectedInfrastructure = ['Power grid (overload risk)', 'Water supply system'];
    } else {
      memory.affectedInfrastructure = ['Traffic control systems', 'Street lighting'];
    }
    observations.add('Infrastructure: ${memory.affectedInfrastructure.join(", ")} — at risk.');
    toolCalls.add(makeToolCall('infrastructure_risk_scanner', 150));

    // ── Calculate Final Severity ──
    onProgress?.call(name, 'Computing severity verdict...', 0.9);
    await simulateLatency(80);

    // Severity matrix: confidence × population × roads × infrastructure
    double severityScore = memory.verificationConfidence * 0.3 +
        (memory.populationAffected > 50000 ? 0.3 : memory.populationAffected > 20000 ? 0.2 : 0.1) +
        (memory.roadsImpacted > 3 ? 0.25 : memory.roadsImpacted > 1 ? 0.15 : 0.05) +
        (memory.affectedInfrastructure.length > 2 ? 0.15 : 0.05);

    if (severityScore >= 0.7) {
      memory.severity = 'CRITICAL';
      memory.urgency = 'IMMEDIATE';
    } else if (severityScore >= 0.5) {
      memory.severity = 'HIGH';
      memory.urgency = 'URGENT';
    } else if (severityScore >= 0.3) {
      memory.severity = 'MEDIUM';
      memory.urgency = 'MODERATE';
    } else {
      memory.severity = 'LOW';
      memory.urgency = 'MONITOR';
    }

    reasoning.add('${memory.severity} severity → ${memory.urgency} urgency → ${memory.severity == 'CRITICAL' ? 'full' : 'partial'} resource allocation triggered.');

    sw.stop();
    final execTime = sw.elapsedMilliseconds;

    memory.agentTraces.add(AgentTrace(
      agentName: name,
      agentIndex: index,
      confidence: min(0.95, severityScore + 0.1 * rng.nextDouble()),
      executionTimeMs: execTime,
      decision: 'Severity = ${memory.severity}. Affected: ${_formatNum(memory.populationAffected)} citizens. Roads impacted: ${memory.roadsImpacted}. Urgency: ${memory.urgency}.',
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
