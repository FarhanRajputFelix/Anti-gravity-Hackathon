/// SAHARA AI — Agent 2: Verification Agent
/// Cross-references crisis signal with weather, traffic, and multi-source data.

import 'dart:math';
import '../base_agent.dart';
import '../agent_memory.dart';

class VerificationAgent extends BaseAgent {
  @override String get name => 'Verification Agent';
  @override int get index => 2;
  @override String get description => 'Cross-references signal with weather, traffic, and multi-source corroboration';
  @override List<String> get tools => ['weather_api', 'traffic_api', 'signal_correlation_engine'];

  // Simulated weather data per crisis type
  static final _weatherProfiles = {
    'FLOODING': {'rainfall_mm': 87.3, 'alert': 'HEAVY_RAIN', 'wind_kph': 35, 'humidity': 94, 'source': 'PMD'},
    'HEATWAVE': {'temperature_c': 48.2, 'alert': 'EXTREME_HEAT', 'humidity': 12, 'uv_index': 11, 'source': 'PMD'},
    'EARTHQUAKE': {'seismic_activity': true, 'magnitude': 5.2, 'alert': 'SEISMIC_WARNING', 'source': 'USGS'},
    'ACCIDENT': {'visibility': 'GOOD', 'road_condition': 'DRY', 'alert': 'NONE', 'source': 'MET'},
    'FIRE': {'temperature_c': 42.0, 'humidity': 15, 'wind_kph': 28, 'alert': 'FIRE_RISK', 'source': 'PMD'},
  };

  // Simulated traffic data
  static final _trafficProfiles = {
    'FLOODING': {'congestion': 87, 'incidents': 14, 'roads_blocked': 3, 'avg_speed_kph': 8},
    'HEATWAVE': {'congestion': 45, 'incidents': 3, 'roads_blocked': 0, 'avg_speed_kph': 35},
    'EARTHQUAKE': {'congestion': 92, 'incidents': 23, 'roads_blocked': 7, 'avg_speed_kph': 5},
    'ACCIDENT': {'congestion': 72, 'incidents': 8, 'roads_blocked': 2, 'avg_speed_kph': 15},
    'FIRE': {'congestion': 65, 'incidents': 5, 'roads_blocked': 1, 'avg_speed_kph': 22},
  };

  @override
  Future<AgentMemory> execute(AgentMemory memory, {AgentProgressCallback? onProgress}) async {
    final sw = Stopwatch()..start();
    final observations = <String>[];
    final reasoning = <String>[];
    final toolCalls = <Map<String, dynamic>>[];
    final rng = Random();

    // ── Tool 1: Weather API ──
    onProgress?.call(name, 'Querying weather API...', 0.15);
    await simulateLatency(340);

    final weatherProfile = _weatherProfiles[memory.crisisType] ?? _weatherProfiles['ACCIDENT']!;
    memory.weatherData = Map<String, dynamic>.from(weatherProfile);

    if (memory.crisisType == 'FLOODING') {
      observations.add('Weather API: ${weatherProfile['rainfall_mm']}mm rainfall, ${weatherProfile['alert']} alert issued by ${weatherProfile['source']}.');
      reasoning.add('✓ Weather CONSISTENT: ${weatherProfile['rainfall_mm']}mm/3h rainfall aligns with flooding claim.');
    } else if (memory.crisisType == 'HEATWAVE') {
      observations.add('Weather API: ${weatherProfile['temperature_c']}°C recorded, ${weatherProfile['alert']} issued by ${weatherProfile['source']}.');
      reasoning.add('✓ Weather CONSISTENT: ${weatherProfile['temperature_c']}°C confirms extreme heat conditions.');
    } else {
      observations.add('Weather API: conditions noted — ${weatherProfile['alert']} (${weatherProfile['source']}).');
      reasoning.add('Weather data retrieved — conditions ${weatherProfile['alert'] == 'NONE' ? 'neutral' : 'corroborating'}.');
    }
    toolCalls.add(makeToolCall('mock_weather_api', 340));

    // ── Tool 2: Traffic API ──
    onProgress?.call(name, 'Querying traffic API...', 0.5);
    await simulateLatency(280);

    final trafficProfile = _trafficProfiles[memory.crisisType] ?? _trafficProfiles['ACCIDENT']!;
    memory.trafficData = Map<String, dynamic>.from(trafficProfile);
    memory.congestionBefore = (trafficProfile['congestion'] as int?) ?? 50;

    observations.add('Traffic API: congestion ${trafficProfile['congestion']}/100, ${trafficProfile['incidents']} incidents, ${trafficProfile['roads_blocked']} roads blocked.');
    reasoning.add('✓ Traffic CONSISTENT: Congestion ${trafficProfile['congestion']}/100 + ${trafficProfile['incidents']} incidents corroborate report.');
    toolCalls.add(makeToolCall('mock_traffic_api', 280));

    // ── Tool 3: Signal Correlation ──
    onProgress?.call(name, 'Correlating multi-source signals...', 0.8);
    await simulateLatency(150);

    memory.corroboratedSources = 2 + rng.nextInt(2); // 2-3 sources
    memory.isVerified = true;
    memory.verificationConfidence = min(0.95, memory.signalConfidence + 0.05 * memory.corroboratedSources);

    observations.add('${memory.corroboratedSources} correlated signals from 2+ independent sources within 30 min.');
    reasoning.add('Multi-source corroboration: citizen + weather + traffic all confirm event.');
    toolCalls.add(makeToolCall('signal_correlation_engine', 150));

    sw.stop();
    final execTime = sw.elapsedMilliseconds;

    memory.agentTraces.add(AgentTrace(
      agentName: name,
      agentIndex: index,
      confidence: memory.verificationConfidence,
      executionTimeMs: execTime,
      decision: 'Crisis CONFIRMED — weather + traffic + multi-source corroboration. Confidence: ${(memory.verificationConfidence * 100).toStringAsFixed(0)}%.',
      observations: observations,
      reasoningSteps: reasoning,
      toolCalls: toolCalls,
    ));

    onProgress?.call(name, 'Complete ✓', 1.0);
    return memory;
  }
}
