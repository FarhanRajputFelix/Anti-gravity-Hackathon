/// SAHARA AI — Unified API Service
/// Uses the in-app Antigravity Orchestrator for analysis (mock-first),
/// with optional HTTP fallback to the FastAPI backend.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../engine/orchestrator.dart';

class ApiService {
  /// Toggle: true = use in-app Antigravity engine (offline fallback)
  ///         false = call live FastAPI backend (RECOMMENDED — has proper gate logic)
  static bool useMockData = false;

  /// The in-app Antigravity orchestrator
  static final AntigravityOrchestrator _orchestrator =
      AntigravityOrchestrator();

  /// Override at build time:
  ///   flutter run --dart-define=SAHARA_API_BASE_URL=https://my-host.com
  static const String _envBase = String.fromEnvironment(
    'SAHARA_API_BASE_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    if (_envBase.isNotEmpty) return _envBase;
    if (kIsWeb) return 'http://localhost:8000';
    // For mobile, default to localhost — override via dart-define for prod
    return 'http://10.0.2.2:8000';
  }

  /// Main analysis function — uses orchestrator or backend
  static Future<Map<String, dynamic>> analyzeSignal({
    required String text,
    String source = 'citizen_report',
    String? locationHint,
    OrchestratorProgressCallback? onProgress,
  }) async {
    if (useMockData) {
      // Use the in-app Antigravity orchestration engine
      return _orchestrator.analyze(
        text: text,
        source: source,
        locationHint: locationHint,
        onProgress: onProgress,
      );
    }

    // Try live backend, fall back to orchestrator on failure
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/analyze'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'text': text,
              'source': source,
              if (locationHint != null) 'location_hint': locationHint,
              'timestamp': DateTime.now().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw Exception('Backend error: ${response.statusCode}');
    } catch (e) {
      // Graceful fallback to in-app orchestrator
      return _orchestrator.analyze(
        text: text,
        source: source,
        locationHint: locationHint,
        onProgress: onProgress,
      );
    }
  }

  /// Get the orchestrator's pipeline description (for UI visualization)
  static List<Map<String, String>> getPipelineDescription() {
    return _orchestrator.getPipelineDescription();
  }

  static Future<List<Map<String, dynamic>>> getLogs() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/logs'),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(body['logs'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  static Future<List<Map<String, dynamic>>> getSignalFeed() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/feed'),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(body['signals'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  static Future<Map<String, dynamic>> getCrisis(String crisisId) async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/api/crisis/$crisisId'),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Crisis not found: $crisisId');
  }

  static Future<List<Map<String, dynamic>>> getScenarios() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/scenarios'),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(body['scenarios'] ?? []);
      }
    } catch (_) {}
    return [];
  }
}
