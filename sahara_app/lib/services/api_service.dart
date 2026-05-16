import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class ApiService {
  /// Override at build time:
  ///   flutter run --dart-define=SAHARA_API_BASE_URL=https://my-host.com
  static const String _envBase = String.fromEnvironment(
    'SAHARA_API_BASE_URL',
    defaultValue: '',
  );

  /// Platform-aware base URL.
  /// - Web/desktop  → http://localhost:8000
  /// - Android      → http://10.0.2.2:8000 (emulator loopback)
  /// - iOS sim/real → http://localhost:8000
  static String get baseUrl {
    if (_envBase.isNotEmpty) return _envBase;
    if (kIsWeb) return 'http://localhost:8000';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    } catch (_) {}
    return 'http://localhost:8000';
  }

  static Future<Map<String, dynamic>> analyzeSignal({
    required String text,
    String source = 'citizen_report',
    String? locationHint,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/analyze'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'text': text,
        'source': source,
        if (locationHint != null) 'location_hint': locationHint,
        'timestamp': DateTime.now().toIso8601String(),
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Backend error: ${response.statusCode} — ${response.body}');
    }
  }

  static Future<List<Map<String, dynamic>>> getLogs() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/logs'),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(body['logs'] ?? []);
    }
    return [];
  }

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
    final response = await http.get(
      Uri.parse('$baseUrl/api/scenarios'),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(body['scenarios'] ?? []);
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getSignalFeed() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/feed'),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(body['signals'] ?? []);
    }
    return [];
  }
}
