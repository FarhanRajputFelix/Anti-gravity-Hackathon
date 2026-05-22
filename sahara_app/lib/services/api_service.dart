/// SAHARA AI — Unified API Service
/// Connects to the live FastAPI backend (with in-app orchestrator fallback).

import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../engine/orchestrator.dart';

class ApiService {
  /// Toggle: false = call live FastAPI backend (recommended for demo)
  ///         true  = use in-app Antigravity engine (offline demo)
  static bool useMockData = false;

  static final AntigravityOrchestrator _orchestrator = AntigravityOrchestrator();

  static const String _envBase = String.fromEnvironment(
    'SAHARA_API_BASE_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    if (_envBase.isNotEmpty) return _envBase;
    if (kIsWeb) {
      // Use the current page's origin so the deployed web app
      // automatically talks to its own backend (e.g. HF Spaces).
      // Falls back to localhost for plain `flutter run -d chrome`.
      try {
        final origin = Uri.base.origin;
        if (origin.isNotEmpty && !origin.startsWith('null')) return origin;
      } catch (_) {}
      return 'http://localhost:8000';
    }
    // Mobile/native — must be set via --dart-define=SAHARA_API_BASE_URL=...
    return 'http://10.0.2.2:8000';
  }

  // ── Analysis ──────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> analyzeSignal({
    required String text,
    String source = 'citizen_report',
    String? locationHint,
    OrchestratorProgressCallback? onProgress,
  }) async {
    if (useMockData) {
      return _orchestrator.analyze(
        text: text,
        source: source,
        locationHint: locationHint,
        onProgress: onProgress,
      );
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/analyze'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text,
          'source': source,
          if (locationHint != null) 'location_hint': locationHint,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw Exception('Backend error: ${response.statusCode}');
    } catch (e) {
      return _orchestrator.analyze(
        text: text,
        source: source,
        locationHint: locationHint,
        onProgress: onProgress,
      );
    }
  }

  static List<Map<String, String>> getPipelineDescription() {
    return _orchestrator.getPipelineDescription();
  }

  // ── Live Crises (map + home screen) ───────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getLiveCrises() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/live-crises'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(body['crises'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  // ── WhatsApp Reports ──────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getWhatsAppReports() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/whatsapp/reports'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(body['reports'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  // ── Hospitals ─────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getHospitals(
    String city, {
    double? lat,
    double? lon,
  }) async {
    try {
      final params = {'city': city};
      if (lat != null) params['lat'] = lat.toString();
      if (lon != null) params['lon'] = lon.toString();
      final uri = Uri.parse('$baseUrl/api/hospitals/$city').replace(
        queryParameters: lat != null ? {'lat': lat.toString(), 'lon': lon.toString()} : null,
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(body['hospitals'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  // ── Signal Feed ───────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getSignalFeed() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/feed'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(body['signals'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  // ── Logs ──────────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getLogs() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/logs'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(body['logs'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  // ── Crisis by ID ──────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getCrisis(String crisisId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/crisis/$crisisId'),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Crisis not found: $crisisId');
  }

  static Future<List<Map<String, dynamic>>> getScenarios() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/scenarios'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(body['scenarios'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  // ── Weather ───────────────────────────────────────────────────────────────

  // ── WhatsApp Admin Trigger ────────────────────────────────────────────────

  static Future<Map<String, dynamic>> analyzeWhatsAppMessage(String msgId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/whatsapp/analyze/$msgId'),
      ).timeout(const Duration(seconds: 90));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      return {'error': e.toString()};
    }
    return {'error': 'failed'};
  }

  // ── Earthquakes (USGS real-time) ──────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getLiveEarthquakes() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/earthquakes'),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(body['earthquakes'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  // ── Monitor status ────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getMonitorStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/monitor/status'),
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {};
  }

  static Future<Map<String, dynamic>> getWeather(String city) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/weather/$city'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {};
  }
}
