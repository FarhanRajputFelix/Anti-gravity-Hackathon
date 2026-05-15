import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Change this to your deployed backend URL or use 10.0.2.2 for Android emulator
  static const String baseUrl = 'http://10.0.2.2:8000';
  // For physical device: use your machine's local IP e.g. http://192.168.1.x:8000

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
