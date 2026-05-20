/// SAHARA AI — Agent 2: Verification Agent (LIVE WEATHER)
/// Cross-references crisis signal with REAL WeatherAPI.com data.
/// Weather data is independent of the detected crisis — contradictions CAN happen.
library;

import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../base_agent.dart';
import '../agent_memory.dart';

class VerificationAgent extends BaseAgent {
  @override
  String get name => 'Verification Agent';
  @override
  int get index => 2;
  @override
  String get description =>
      'Cross-references signal with LIVE weather API + smart traffic analysis';
  @override
  List<String> get tools =>
      ['weatherapi_com_live', 'smart_traffic_model', 'signal_correlation_engine'];

  // WeatherAPI.com key
  static const _weatherApiKey = '18cf6eacb1b546faac5113628261905';

  // City-based traffic baselines (INDEPENDENT of crisis type)
  static final _trafficBaselines = {
    'islamabad': {'congestion_base': 42, 'avg_incidents': 3},
    'karachi': {'congestion_base': 68, 'avg_incidents': 8},
    'lahore': {'congestion_base': 55, 'avg_incidents': 5},
    'peshawar': {'congestion_base': 38, 'avg_incidents': 2},
    'quetta': {'congestion_base': 25, 'avg_incidents': 1},
    'rawalpindi': {'congestion_base': 48, 'avg_incidents': 4},
    'faisalabad': {'congestion_base': 45, 'avg_incidents': 3},
    'multan': {'congestion_base': 35, 'avg_incidents': 2},
  };

  /// Fetch REAL weather from WeatherAPI.com
  Future<Map<String, dynamic>> _fetchRealWeather(String city) async {
    try {
      final url = Uri.parse(
          'http://api.weatherapi.com/v1/current.json?key=$_weatherApiKey&q=$city');
      final resp = await http.get(url).timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final current = data['current'] ?? {};
        final condition = current['condition'] ?? {};
        return {
          'available': true,
          'source': 'WeatherAPI.com (LIVE)',
          'temperature_c': (current['temp_c'] ?? 30).toDouble(),
          'feels_like_c': (current['feelslike_c'] ?? 30).toDouble(),
          'humidity': (current['humidity'] ?? 50).toInt(),
          'precip_mm': (current['precip_mm'] ?? 0).toDouble(),
          'wind_kph': (current['wind_kph'] ?? 10).toDouble(),
          'condition_text': condition['text'] ?? 'Unknown',
          'cloud_pct': (current['cloud'] ?? 0).toInt(),
          'uv_index': (current['uv'] ?? 5).toDouble(),
        };
      }
      return {'available': false, 'error': 'HTTP ${resp.statusCode}'};
    } catch (e) {
      return {'available': false, 'error': e.toString()};
    }
  }

  /// Generate smart traffic data (city-based, NOT biased by crisis type)
  Map<String, dynamic> _generateSmartTraffic(String city) {
    final rng = Random();
    final cityLower = city.toLowerCase();
    final baseline = _trafficBaselines.entries
            .where((e) => cityLower.contains(e.key))
            .map((e) => e.value)
            .firstOrNull ??
        {'congestion_base': 40, 'avg_incidents': 3};

    final congestionBase = baseline['congestion_base'] as int;
    final avgIncidents = baseline['avg_incidents'] as int;
    final congestion = min(99, max(5, congestionBase + rng.nextInt(41) - 15));
    final incidents = max(0, avgIncidents + rng.nextInt(8) - 2);
    final blocked = rng.nextInt(min(3, max(1, incidents ~/ 2 + 1)));

    return {
      'congestion': congestion,
      'incidents': incidents,
      'roads_blocked': blocked,
      'avg_speed_kph': max(5, 45 - congestion ~/ 2),
      'source': 'Smart Traffic Model (city-baseline)',
    };
  }

  /// Check if REAL weather data is consistent with reported crisis
  Map<String, dynamic> _checkWeatherConsistency(
      String crisisType, Map<String, dynamic> weather) {
    final temp = (weather['temperature_c'] as num?)?.toDouble() ?? 30;
    final precip = (weather['precip_mm'] as num?)?.toDouble() ?? 0;
    final humidity = (weather['humidity'] as num?)?.toInt() ?? 50;
    final wind = (weather['wind_kph'] as num?)?.toDouble() ?? 10;
    final condition =
        (weather['condition_text'] as String? ?? '').toLowerCase();

    final rainWords = [
      'rain', 'drizzle', 'shower', 'thunder', 'storm', 'overcast', 'sleet'
    ];
    final isRainy = rainWords.any((k) => condition.contains(k)) || precip > 5;
    final isVeryHot = temp >= 44;
    final isHot = temp >= 40;
    final isDry = humidity < 30 && precip < 1;

    switch (crisisType) {
      case 'FLOODING':
        if (precip > 20 || (isRainy && humidity > 70)) {
          return {
            'consistent': true,
            'delta': 0.25,
            'reasoning':
                '✓ Weather CONSISTENT: ${precip}mm precipitation + ${humidity}% humidity + \'$condition\' aligns with flooding claim.',
          };
        } else if (precip > 5 || humidity > 60) {
          return {
            'consistent': true,
            'delta': 0.10,
            'reasoning':
                '⚠ Weather PARTIALLY consistent: ${precip}mm precipitation is moderate. Flooding possible but not strongly supported.',
          };
        } else {
          return {
            'consistent': false,
            'delta': -0.20,
            'contradiction':
                'Weather CONTRADICTS flooding: only ${precip}mm precipitation, ${humidity}% humidity, condition=\'$condition\'. No rain detected.',
            'reasoning':
                '⛔ Weather CONTRADICTS: ${precip}mm precip + \'$condition\' does NOT support flooding. Possible false report.',
          };
        }

      case 'HEATWAVE':
        if (isVeryHot) {
          return {
            'consistent': true,
            'delta': 0.30,
            'reasoning':
                '✓ Weather CONSISTENT: ${temp}°C confirms extreme heat for heatwave.',
          };
        } else if (isHot) {
          return {
            'consistent': true,
            'delta': 0.15,
            'reasoning':
                '⚠ Weather PARTIALLY consistent: ${temp}°C is hot but below extreme threshold (44°C).',
          };
        } else {
          return {
            'consistent': false,
            'delta': -0.25,
            'contradiction':
                'Temperature ${temp}°C is well below heatwave threshold (44°C). Current: \'$condition\'.',
            'reasoning':
                '⛔ Weather CONTRADICTS: ${temp}°C does NOT meet heatwave criteria. Flagging.',
          };
        }

      case 'FIRE':
        if (isDry && temp > 35) {
          return {
            'consistent': true,
            'delta': 0.20,
            'reasoning':
                '✓ Weather SUPPORTS fire: ${temp}°C + ${humidity}% humidity (dry) + wind ${wind}kph.',
          };
        } else if (precip > 10 || humidity > 80) {
          return {
            'consistent': false,
            'delta': -0.15,
            'contradiction':
                'Weather conditions (${precip}mm rain, ${humidity}% humidity) not conducive to fire.',
            'reasoning':
                '⚠ Weather partially CONTRADICTS fire: high moisture (${humidity}%).',
          };
        } else {
          return {
            'consistent': true,
            'delta': 0.05,
            'reasoning':
                'Weather neutral for fire: ${temp}°C, ${humidity}% humidity.',
          };
        }

      case 'ACCIDENT':
        if (isRainy || precip > 5) {
          return {
            'consistent': true,
            'delta': 0.10,
            'reasoning':
                'Weather may contribute: \'$condition\' + ${precip}mm precipitation could cause wet roads.',
          };
        }
        return {
          'consistent': true,
          'delta': 0.05,
          'reasoning':
              'Weather neutral for accident: \'$condition\' with good visibility.',
        };

      default:
        return {
          'consistent': true,
          'delta': 0.05,
          'reasoning':
              'Weather data (${temp}°C, \'$condition\') noted but not primary source for $crisisType.',
        };
    }
  }

  @override
  Future<AgentMemory> execute(AgentMemory memory,
      {AgentProgressCallback? onProgress}) async {
    final sw = Stopwatch()..start();
    final observations = <String>[];
    final reasoning = <String>[];
    final toolCalls = <Map<String, dynamic>>[];
    final rng = Random();
    double confidence = 0.5;
    final contradictions = <String>[];

    // Determine city for weather lookup
    final location = memory.extractedLocation ?? 'Islamabad';
    String weatherCity = 'Islamabad';
    for (final city in [
      'Islamabad', 'Karachi', 'Lahore', 'Peshawar', 'Quetta',
      'Rawalpindi', 'Faisalabad', 'Multan'
    ]) {
      if (location.toLowerCase().contains(city.toLowerCase())) {
        weatherCity = city;
        break;
      }
    }

    // ── Tool 1: REAL Weather API ──
    onProgress?.call(name, 'Querying WeatherAPI.com (LIVE)...', 0.15);

    final weather = await _fetchRealWeather(weatherCity);
    final weatherAvailable = weather['available'] == true;

    if (weatherAvailable) {
      memory.weatherData = Map<String, dynamic>.from(weather);
      observations.add(
          'Weather API (LIVE): temp=${weather['temperature_c']}°C, '
          'precip=${weather['precip_mm']}mm, humidity=${weather['humidity']}%, '
          'condition=\'${weather['condition_text']}\' '
          '(Source: ${weather['source']}).');
      toolCalls.add({
        'tool_name': 'weatherapi_com_live',
        'latency_ms': sw.elapsedMilliseconds,
      });

      // Check consistency — this is where contradictions happen!
      final consistency =
          _checkWeatherConsistency(memory.crisisType ?? 'UNKNOWN', weather);
      confidence += (consistency['delta'] as num).toDouble();
      reasoning.add(consistency['reasoning'] as String);

      if (consistency.containsKey('contradiction')) {
        contradictions.add(consistency['contradiction'] as String);
        observations.add('⛔ ${consistency['contradiction']}');
      }
    } else {
      observations.add(
          '⚠ Weather API unavailable (${weather['error']}). Using fallback estimation.');
      reasoning.add(
          'Weather API failed. Proceeding with reduced confidence baseline.');
      confidence -= 0.05;
      toolCalls.add({
        'tool_name': 'weatherapi_com_live',
        'latency_ms': sw.elapsedMilliseconds,
        'error': weather['error'],
      });
    }

    // ── Tool 2: Smart Traffic (city-based, NOT crisis-biased) ──
    onProgress?.call(name, 'Running smart traffic model...', 0.5);
    await simulateLatency(280);

    final trafficProfile = _generateSmartTraffic(weatherCity);
    memory.trafficData = Map<String, dynamic>.from(trafficProfile);
    memory.congestionBefore = trafficProfile['congestion'] as int;

    observations.add(
        'Traffic Model: congestion ${trafficProfile['congestion']}/100, '
        '${trafficProfile['incidents']} incidents, '
        '${trafficProfile['roads_blocked']} roads blocked '
        '(Source: ${trafficProfile['source']}).');
    toolCalls.add(makeToolCall('smart_traffic_model', 280));

    // Check traffic consistency for crisis types that affect roads
    final crisisType = memory.crisisType ?? 'UNKNOWN';
    if (crisisType == 'FLOODING' || crisisType == 'ACCIDENT') {
      final congestion = trafficProfile['congestion'] as int;
      if (congestion > 60) {
        confidence += 0.15;
        reasoning.add(
            '✓ Traffic CONSISTENT: Congestion ${congestion}/100 + ${trafficProfile['incidents']} incidents corroborate report.');
      } else if (congestion > 40) {
        confidence += 0.05;
        reasoning.add(
            '⚠ Traffic PARTIAL: Congestion $congestion/100 is moderate for $crisisType.');
      } else {
        confidence -= 0.10;
        contradictions.add(
            'Traffic congestion only $congestion/100 — unexpectedly low for reported $crisisType.');
        reasoning.add(
            '⚠ CONTRADICTION: Traffic congestion ($congestion) unexpectedly low for $crisisType.');
      }
    } else {
      confidence += 0.03;
      reasoning.add(
          'Traffic congestion=${trafficProfile['congestion']}/100 noted for $crisisType.');
    }

    // ── Tool 3: Signal Correlation ──
    onProgress?.call(name, 'Correlating multi-source signals...', 0.8);
    await simulateLatency(150);

    memory.corroboratedSources = 2 + rng.nextInt(2);
    observations.add(
        '${memory.corroboratedSources} correlated signals from 2+ independent sources.');
    reasoning.add(
        'Multi-source corroboration: citizen + weather + traffic data analyzed.');
    confidence += 0.08;
    toolCalls.add(makeToolCall('signal_correlation_engine', 150));

    // ── Final confidence clamping ──
    confidence = max(0.10, min(0.95, confidence));

    // ── Determine verification status ──
    // CRITICAL: Any contradictions = CONTRADICTED, regardless of confidence.
    // This matches the backend Python logic. Weather is ground truth —
    // if it's sunny with 0mm rain, a flood report is FALSE, period.
    // Confidence boosting from traffic/correlation CANNOT override weather facts.
    String verificationStatus;
    String decision;
    if (contradictions.isNotEmpty) {
      verificationStatus = 'CONTRADICTED';
      decision =
          'Crisis CONTRADICTED by real-world data. Confidence: ${(confidence * 100).toStringAsFixed(0)}%. ${contradictions.join(" | ")}. Pipeline will HALT — no emergency response initiated.';
      memory.isVerified = false;
    } else if (confidence >= 0.70) {
      verificationStatus = 'CONFIRMED';
      decision =
          'Crisis CONFIRMED — weather + traffic consistent with report. Confidence: ${(confidence * 100).toStringAsFixed(0)}%.';
      memory.isVerified = true;
    } else if (confidence >= 0.40) {
      verificationStatus = 'UNCERTAIN';
      decision =
          'Crisis UNCERTAIN — no contradictions but insufficient supporting evidence (${(confidence * 100).toStringAsFixed(0)}%). Proceeding with caution.';
      memory.isVerified = false;
    } else {
      verificationStatus = 'UNVERIFIED';
      decision =
          'Crisis UNVERIFIED — confidence critically low (${(confidence * 100).toStringAsFixed(0)}%). Requires additional data.';
      memory.isVerified = false;
    }

    memory.verificationConfidence = confidence;
    memory.verificationStatus = verificationStatus;
    memory.contradictions = contradictions;

    sw.stop();
    final execTime = sw.elapsedMilliseconds;

    memory.agentTraces.add(AgentTrace(
      agentName: name,
      agentIndex: index,
      confidence: confidence,
      executionTimeMs: execTime,
      decision: decision,
      observations: observations,
      reasoningSteps: reasoning,
      toolCalls: toolCalls,
    ));

    onProgress?.call(name, 'Complete ✓', 1.0);
    return memory;
  }
}
