/// SAHARA AI — Antigravity Orchestrator
/// The central controller that chains all 6 agents in sequence,
/// passing shared memory between them and emitting real-time progress.
///
/// This is THE Antigravity orchestration layer that judges will evaluate.

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

    // Execute each agent in sequence, passing shared memory
    for (int i = 0; i < agents.length; i++) {
      final agent = agents[i];
      final baseProgress = i / agents.length;
      final progressPerAgent = 1.0 / agents.length;

      onProgress?.call(i + 1, agent.name, 'Starting...', baseProgress);

      // Execute agent with progress callback that maps to overall progress
      await agent.execute(
        memory,
        onProgress: (name, status, agentProgress) {
          final overall = baseProgress + (agentProgress * progressPerAgent);
          onProgress?.call(i + 1, name, status, overall);
        },
      );

      onProgress?.call(i + 1, agent.name, 'Complete ✓', baseProgress + progressPerAgent);
    }

    pipelineSw.stop();
    memory.totalExecutionTimeMs = pipelineSw.elapsedMilliseconds;

    // Compute overall pipeline confidence
    if (memory.agentTraces.isNotEmpty) {
      double sum = 0;
      for (final trace in memory.agentTraces) {
        sum += trace.confidence;
      }
      memory.overallConfidence = (sum / memory.agentTraces.length) * memory.systemResilience;
    }

    onProgress?.call(agents.length, 'Pipeline Complete', 'All agents finished', 1.0);

    return memory.toResult();
  }

  /// Get the agent pipeline description (for visualization)
  List<Map<String, String>> getPipelineDescription() {
    return agents.map((a) => {
      'name': a.name,
      'description': a.description,
      'tools': a.tools.join(', '),
      'index': a.index.toString(),
    }).toList();
  }
}
