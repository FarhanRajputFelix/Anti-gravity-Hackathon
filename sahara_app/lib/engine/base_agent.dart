/// SAHARA AI — Base Agent Interface
/// All 6 Antigravity agents implement this interface.
/// Each agent receives shared memory, performs reasoning, and writes back.

import 'agent_memory.dart';

/// Callback for streaming agent progress to the UI in real-time
typedef AgentProgressCallback = void Function(String agentName, String status, double progress);

/// Base class for all Antigravity pipeline agents
abstract class BaseAgent {
  String get name;
  int get index;
  String get description;
  List<String> get tools;

  /// Execute the agent's reasoning on the shared memory.
  /// Returns the updated memory with this agent's contributions.
  Future<AgentMemory> execute(AgentMemory memory, {AgentProgressCallback? onProgress});

  /// Helper: create a tool call record
  Map<String, dynamic> makeToolCall(String toolName, int latencyMs) {
    return {'tool_name': toolName, 'latency_ms': latencyMs};
  }

  /// Helper: simulate processing delay for realistic agent behavior
  Future<void> simulateLatency(int ms) async {
    await Future.delayed(Duration(milliseconds: ms));
  }
}
