/// SAHARA AI — Agent 6: Fallback & Recovery Agent
/// Monitors pipeline health, triggers API fallbacks, and ensures system resilience.

import '../base_agent.dart';
import '../agent_memory.dart';

class FallbackRecoveryAgent extends BaseAgent {
  @override String get name => 'Fallback & Recovery Agent';
  @override int get index => 6;
  @override String get description => 'Monitors pipeline health, triggers API substitutions, ensures system continuity';
  @override List<String> get tools => ['pipeline_health_monitor', 'historical_traffic_db', 'rule_based_nlp_fallback', 'resilience_scorer'];

  @override
  Future<AgentMemory> execute(AgentMemory memory, {AgentProgressCallback? onProgress}) async {
    final sw = Stopwatch()..start();
    final observations = <String>[];
    final reasoning = <String>[];
    final toolCalls = <Map<String, dynamic>>[];

    // ── Tool 1: Pipeline Health Monitor ──
    onProgress?.call(name, 'Scanning pipeline health...', 0.15);
    await simulateLatency(120);

    // Simulate realistic failure scenarios
    final trafficApiDown = memory.crisisType == 'FLOODING' || memory.crisisType == 'EARTHQUAKE';
    final nlpDegraded = memory.crisisType != 'ACCIDENT';
    int fallbacksApplied = 0;

    observations.add('Pipeline health scan: ${trafficApiDown ? "⚠ Traffic API elevated latency" : "✅ Traffic API nominal"}, ${nlpDegraded ? "⚠ NLP API degraded mode" : "✅ NLP API nominal"}.');
    toolCalls.add(makeToolCall('pipeline_health_monitor', 120));

    // ── Fallback 1: Traffic API ──
    if (trafficApiDown) {
      onProgress?.call(name, 'Applying traffic API fallback...', 0.4);
      await simulateLatency(180);

      fallbacksApplied++;
      final location = memory.extractedLocation ?? 'Pakistan';
      final city = location.contains('Islamabad') ? 'Islamabad' : location.contains('Karachi') ? 'Karachi' : 'Lahore';

      observations.add('⚠ Traffic API unavailable. Switching to historical congestion baseline.');
      observations.add('Historical pattern for $city: typical congestion = 65/100. Accuracy: ±15%.');
      reasoning.add('FALLBACK 1: Live traffic → historical average (65/100, ±15% margin).');
      memory.fallbackStrategies.add('Traffic API → Historical baseline (±15%)');
      toolCalls.add(makeToolCall('historical_traffic_db', 180));
    }

    // ── Fallback 2: NLP API ──
    if (nlpDegraded) {
      onProgress?.call(name, 'Applying NLP fallback...', 0.6);
      await simulateLatency(45);

      fallbacksApplied++;
      observations.add('Gemini NLP API: DEGRADED — rule-based engine substituted at 92% accuracy.');
      reasoning.add('FALLBACK 2: Gemini API timeout → rule-based NLP (92% accuracy, 45ms).');
      memory.fallbackStrategies.add('Gemini NLP → Rule-based engine (92% accuracy)');
      toolCalls.add(makeToolCall('rule_based_nlp_fallback', 45));
    }

    // ── Resilience Score ──
    onProgress?.call(name, 'Computing system resilience score...', 0.85);
    await simulateLatency(60);

    memory.fallbackTriggered = fallbacksApplied > 0;
    memory.fallbackCount = fallbacksApplied;
    memory.systemResilience = fallbacksApplied == 0 ? 1.0 : fallbacksApplied == 1 ? 0.92 : 0.85;

    if (fallbacksApplied > 0) {
      reasoning.add('Pipeline continuity maintained through $fallbacksApplied failure scenario${fallbacksApplied > 1 ? 's' : ''}.');
    } else {
      reasoning.add('All systems nominal — no fallbacks required. Pipeline resilience: 100%.');
    }
    observations.add('System resilience: ${(memory.systemResilience * 100).toStringAsFixed(0)}%. All downstream agents unaffected.');
    toolCalls.add(makeToolCall('resilience_scorer', 60));

    // ── Calculate overall confidence ──
    onProgress?.call(name, 'Finalizing pipeline confidence...', 0.95);

    double avgConfidence = 0;
    for (final trace in memory.agentTraces) {
      avgConfidence += trace.confidence;
    }
    avgConfidence = avgConfidence / (memory.agentTraces.isEmpty ? 1 : memory.agentTraces.length);
    memory.overallConfidence = avgConfidence * memory.systemResilience;

    sw.stop();
    final execTime = sw.elapsedMilliseconds;
    memory.totalExecutionTimeMs = memory.agentTraces.fold<int>(0, (sum, t) => sum + t.executionTimeMs) + execTime;

    memory.agentTraces.add(AgentTrace(
      agentName: name,
      agentIndex: index,
      confidence: memory.systemResilience,
      executionTimeMs: execTime,
      fallbackTriggered: memory.fallbackTriggered,
      decision: fallbacksApplied > 0
          ? '$fallbacksApplied fallback strategies applied: ${memory.fallbackStrategies.join(" + ")}.'
          : 'All systems nominal — pipeline running at full capacity. No fallbacks needed.',
      observations: observations,
      reasoningSteps: reasoning,
      toolCalls: toolCalls,
    ));

    onProgress?.call(name, 'Complete ✓', 1.0);
    return memory;
  }
}
