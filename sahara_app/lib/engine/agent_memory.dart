/// SAHARA AI — Antigravity Shared Memory
/// This is the shared context that flows between all 6 agents in the pipeline.
/// Each agent reads from and writes to this memory, creating a visible chain of reasoning.
library;

class AgentMemory {
  // ── Input Signal ──
  String rawText = '';
  String source = '';
  String? locationHint;
  DateTime timestamp = DateTime.now();

  // ── Agent 1: Signal Ingestion ──
  String? detectedLanguage;
  String? crisisType;
  String? extractedLocation;
  double signalConfidence = 0.0;
  List<String> keywords = [];
  bool isDuplicate = false;

  // ── Agent 2: Verification ──
  bool isVerified = false;
  double verificationConfidence = 0.0;
  String verificationStatus = 'PENDING';  // CONFIRMED, UNCERTAIN, CONTRADICTED, UNVERIFIED
  List<String> contradictions = [];
  Map<String, dynamic> weatherData = {};
  Map<String, dynamic> trafficData = {};
  int corroboratedSources = 0;

  // ── Agent 3: Severity Analysis ──
  String severity = 'UNKNOWN';
  String urgency = 'UNKNOWN';
  int populationAffected = 0;
  int roadsImpacted = 0;
  List<String> affectedRoads = [];
  List<String> affectedInfrastructure = [];

  // ── Agent 4: Response Planning ──
  List<Map<String, dynamic>> actionPlan = [];
  int departmentsNotified = 0;
  int rescueTeamsAvailable = 0;
  int ambulancesAvailable = 0;
  int estimatedResponseMinutes = 0;

  // ── Agent 5: Execution Simulation ──
  int congestionBefore = 0;
  int congestionAfter = 0;
  int alertsSent = 0;
  int unitsDispatched = 0;
  int populationHelped = 0;
  int hospitalsNotified = 0;
  List<String> emergencyTickets = [];
  List<String> executionLogs = [];
  List<String> roadsRerouted = [];

  // ── Agent 6: Fallback & Recovery ──
  bool fallbackTriggered = false;
  int fallbackCount = 0;
  List<String> fallbackStrategies = [];
  double systemResilience = 1.0;

  // ── Pipeline Meta ──
  List<AgentTrace> agentTraces = [];
  int totalExecutionTimeMs = 0;
  double overallConfidence = 0.0;
  String systemMessage = '';
  String pipelineStatus = 'PROCESSING';  // PROCESSING, COMPLETED, UNVERIFIED, REJECTED

  /// Convert to the JSON format expected by all Flutter screens
  Map<String, dynamic> toResult() {
    return {
      'crisis_id': 'CRS-${DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase().substring(0, 8)}',
      'status': pipelineStatus,
      'crisis_type': crisisType ?? 'UNKNOWN',
      'location': extractedLocation ?? locationHint ?? 'Unknown',
      'severity': severity,
      'verification_status': verificationStatus,
      'confidence': overallConfidence,
      'total_execution_time_ms': totalExecutionTimeMs,
      'verified': isVerified,
      'contradictions': contradictions,
      'system_message': systemMessage,
      'agent_traces': agentTraces.map((t) => t.toJson()).toList(),
      'action_plan': actionPlan,
      'simulation': {
        'congestion_level_before': congestionBefore,
        'congestion_level_after': congestionAfter,
        'alerts_sent': alertsSent,
        'emergency_units_dispatched': unitsDispatched,
        'roads_rerouted': roadsRerouted,
        'hospitals_notified': hospitalsNotified,
        'population_helped': populationHelped,
        'response_time_minutes': estimatedResponseMinutes,
        'emergency_tickets': emergencyTickets,
        'execution_logs': executionLogs,
      },
      'shared_memory': {
        'detected_language': detectedLanguage,
        'keywords': keywords,
        'weather_data': weatherData,
        'traffic_data': trafficData,
        'corroborated_sources': corroboratedSources,
        'population_affected': populationAffected,
        'roads_impacted': roadsImpacted,
        'affected_roads': affectedRoads,
        'fallback_triggered': fallbackTriggered,
        'fallback_count': fallbackCount,
        'system_resilience': systemResilience,
      },
      'analyzed_at': DateTime.now().toIso8601String(),
    };
  }
}

/// Represents a single agent's trace through the pipeline
class AgentTrace {
  final String agentName;
  final int agentIndex;
  final double confidence;
  final int executionTimeMs;
  final bool fallbackTriggered;
  final String decision;
  final List<String> observations;
  final List<String> reasoningSteps;
  final List<Map<String, dynamic>> toolCalls;

  AgentTrace({
    required this.agentName,
    required this.agentIndex,
    required this.confidence,
    required this.executionTimeMs,
    this.fallbackTriggered = false,
    required this.decision,
    required this.observations,
    required this.reasoningSteps,
    required this.toolCalls,
  });

  Map<String, dynamic> toJson() => {
        'agent_name': agentName,
        'agent_index': agentIndex,
        'confidence': confidence,
        'execution_time_ms': executionTimeMs,
        'fallback_triggered': fallbackTriggered,
        'decision': decision,
        'observations': observations,
        'reasoning_steps': reasoningSteps,
        'tool_calls': toolCalls,
      };
}
