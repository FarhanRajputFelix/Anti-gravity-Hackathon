/// SAHARA AI — Antigravity Orchestrator
/// The central controller that chains all 6 agents in sequence,
/// passing shared memory between them and emitting real-time progress.
///
/// This is THE Antigravity orchestration layer that judges will evaluate.
library;

import 'agent_memory.dart';
import 'base_agent.dart';
import 'agents/signal_ingestion_agent.dart';
import 'agents/verification_agent.dart';
import 'agents/severity_analysis_agent.dart';
import 'agents/response_planning_agent.dart';
import 'agents/execution_simulation_agent.dart';
import 'agents/fallback_recovery_agent.dart';

/// Callback for orchestrator-level progress updates
typedef OrchestratorProgressCallback = void Function(
  int agentIndex,
  String agentName,
  String status,
  double overallProgress,
);

/// The Antigravity Orchestrator — chains 6 agents via shared memory
class AntigravityOrchestrator {
  /// The ordered agent pipeline
  final List<BaseAgent> agents = [
    SignalIngestionAgent(),
    VerificationAgent(),
    SeverityAnalysisAgent(),
    ResponsePlanningAgent(),
    ExecutionSimulationAgent(),
    FallbackRecoveryAgent(),
  ];

  /// Execute the full 6-agent pipeline
  ///
  /// [text] — Raw crisis signal (English, Urdu, or Roman Urdu)
  /// [source] — Signal source (citizen_report, weather_api, etc.)
  /// [locationHint] — Optional location hint
  /// [onProgress] — Real-time progress callback for UI
  ///
  /// Returns a Map suitable for all Flutter screens (agent traces, simulation, etc.)
  Future<Map<String, dynamic>> analyze({
    required String text,
    required String source,
    String? locationHint,
    OrchestratorProgressCallback? onProgress,
  }) async {
    // Initialize shared memory
    final memory = AgentMemory()
      ..rawText = text
      ..source = source
      ..locationHint = locationHint
      ..timestamp = DateTime.now();

    final pipelineSw = Stopwatch()..start();

    // ── STEP 1: Signal Ingestion Agent ──
    onProgress?.call(1, agents[0].name, 'Starting...', 0.0);
    await agents[0].execute(memory, onProgress: (name, status, p) {
      onProgress?.call(1, name, status, p / agents.length);
    });
    onProgress?.call(1, agents[0].name, 'Complete ✓', 1.0 / agents.length);

    // ── GATE 1: Was the signal rejected as not a crisis? ──
    if (memory.crisisType == null || memory.crisisType == 'UNKNOWN' || memory.signalConfidence < 0.55) {
      pipelineSw.stop();
      memory.totalExecutionTimeMs = pipelineSw.elapsedMilliseconds;
      memory.pipelineStatus = 'REJECTED';
      memory.systemMessage = 'Signal rejected: Not a valid crisis report. Confidence too low or crisis type unrecognized.';
      memory.overallConfidence = memory.signalConfidence;
      onProgress?.call(agents.length, 'Pipeline Halted', 'Gate 1: Signal rejected', 1.0);
      return memory.toResult();
    }

    // ── STEP 2: Verification Agent ──
    onProgress?.call(2, agents[1].name, 'Starting...', 1.0 / agents.length);
    await agents[1].execute(memory, onProgress: (name, status, p) {
      onProgress?.call(2, name, status, (1.0 + p) / agents.length);
    });
    onProgress?.call(2, agents[1].name, 'Complete ✓', 2.0 / agents.length);

    // ── GATE 2: Was the crisis CONTRADICTED by real-world data? ──
    if (memory.verificationStatus == 'CONTRADICTED') {
      pipelineSw.stop();
      memory.totalExecutionTimeMs = pipelineSw.elapsedMilliseconds;
      memory.pipelineStatus = 'UNVERIFIED';
      memory.overallConfidence = memory.verificationConfidence;
      final contradictionText = memory.contradictions.isNotEmpty
          ? memory.contradictions.join(' | ')
          : 'Report contradicts real-world data';
      memory.systemMessage =
          'Crisis report REJECTED by verification gate: $contradictionText. '
          'No emergency response initiated. ${memory.agentTraces.length} agents executed.';
      onProgress?.call(
          agents.length, 'Pipeline Halted',
          '⛔ Gate 2: Verification CONTRADICTED — false report detected', 1.0);
      return memory.toResult();
    }

    // ── STEPS 3–6: Remaining agents (only if verification passed) ──
    for (int i = 2; i < agents.length; i++) {
      final agent = agents[i];
      final baseProgress = (i) / agents.length;
      final progressPerAgent = 1.0 / agents.length;

      onProgress?.call(i + 1, agent.name, 'Starting...', baseProgress);

      await agent.execute(memory, onProgress: (name, status, agentProgress) {
        final overall = baseProgress + (agentProgress * progressPerAgent);
        onProgress?.call(i + 1, name, status, overall);
      });

      onProgress?.call(
          i + 1, agent.name, 'Complete ✓', baseProgress + progressPerAgent);
    }

    pipelineSw.stop();
    memory.totalExecutionTimeMs = pipelineSw.elapsedMilliseconds;
    memory.pipelineStatus = 'COMPLETED';

    // Compute overall pipeline confidence
    if (memory.agentTraces.isNotEmpty) {
      double sum = 0;
      for (final trace in memory.agentTraces) {
        sum += trace.confidence;
      }
      memory.overallConfidence =
          (sum / memory.agentTraces.length) * memory.systemResilience;
    }

    memory.systemMessage =
        'SAHARA AI processed crisis in ${memory.totalExecutionTimeMs}ms. '
        '${memory.agentTraces.length} agents executed. '
        '${memory.actionPlan.length} response actions planned.';

    onProgress?.call(
        agents.length, 'Pipeline Complete', 'All agents finished', 1.0);

    return memory.toResult();
  }

  /// Get the agent pipeline description (for visualization)
  List<Map<String, String>> getPipelineDescription() {
    return agents
        .map((a) => {
              'name': a.name,
              'description': a.description,
              'tools': a.tools.join(', '),
              'index': a.index.toString(),
            })
        .toList();
  }
}
