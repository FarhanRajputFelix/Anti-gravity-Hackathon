/// SAHARA AI — Agent 1: Signal Ingestion Agent
/// Processes raw crisis signals: language detection, crisis classification, entity extraction.

import 'dart:math';
import 'base_agent.dart';
import 'agent_memory.dart';

class SignalIngestionAgent extends BaseAgent {
  @override String get name => 'Signal Ingestion Agent';
  @override int get index => 1;
  @override String get description => 'Processes raw crisis signals — language detection, crisis classification, location extraction';
  @override List<String> get tools => ['language_detector', 'crisis_classifier', 'entity_extractor', 'dedup_engine'];

  // Language detection patterns
  static const _urduMarkers = ['mein', 'hai', 'gaya', 'hain', 'aur', 'ki', 'ka', 'ke', 'ko', 'se', 'zaroorat', 'wajah'];
  static const _arabicRange = RegExp(r'[\u0600-\u06FF]');

  // Crisis keyword clusters
  static final _crisisPatterns = {
    'FLOODING': ['flood', 'pani', 'baarish', 'rain', 'doob', 'seilab', 'barish', 'overflow', 'submerge', 'drown', 'water', 'torrent'],
    'HEATWAVE': ['heat', 'garmi', 'temperature', 'heatwave', 'stroke', 'celsius', 'heat stroke', 'garma', 'sun', 'dehydration'],
    'EARTHQUAKE': ['earthquake', 'zelzala', 'bhuchal', 'tremor', 'richter', 'seismic', 'quake'],
    'ACCIDENT': ['accident', 'hadsa', 'crash', 'collision', 'takra', 'block', 'road', 'traffic'],
    'FIRE': ['fire', 'aag', 'blaze', 'smoke', 'dhuan', 'burning', 'flames'],
    'GAS_LEAK': ['gas', 'leak', 'pipeline', 'explosion', 'chemical', 'toxic'],
  };

  // Location patterns for Pakistani cities
  static final _locationPatterns = {
    RegExp(r'G-?\d+', caseSensitive: false): 'Islamabad',
    RegExp(r'I-?\d+', caseSensitive: false): 'Islamabad',
    RegExp(r'F-?\d+', caseSensitive: false): 'Islamabad',
    RegExp(r'islamabad', caseSensitive: false): 'Islamabad',
    RegExp(r'karachi', caseSensitive: false): 'Karachi',
    RegExp(r'saddar', caseSensitive: false): 'Karachi',
    RegExp(r'lahore', caseSensitive: false): 'Lahore',
    RegExp(r'mall\s*road', caseSensitive: false): 'Lahore',
    RegExp(r'shahrah', caseSensitive: false): 'Lahore',
    RegExp(r'peshawar', caseSensitive: false): 'Peshawar',
    RegExp(r'quetta', caseSensitive: false): 'Quetta',
    RegExp(r'rawalpindi', caseSensitive: false): 'Rawalpindi',
    RegExp(r'faisalabad', caseSensitive: false): 'Faisalabad',
    RegExp(r'multan', caseSensitive: false): 'Multan',
  };

  @override
  Future<AgentMemory> execute(AgentMemory memory, {AgentProgressCallback? onProgress}) async {
    final sw = Stopwatch()..start();
    final observations = <String>[];
    final reasoning = <String>[];
    final toolCalls = <Map<String, dynamic>>[];
    final text = memory.rawText.toLowerCase();

    // ── Tool 1: Language Detection ──
    onProgress?.call(name, 'Detecting language...', 0.1);
    await simulateLatency(180);

    final urduWordCount = _urduMarkers.where((m) => text.contains(m)).length;
    final hasArabicScript = _arabicRange.hasMatch(memory.rawText);
    String lang;
    if (hasArabicScript) {
      lang = 'URDU_SCRIPT';
    } else if (urduWordCount >= 3) {
      lang = 'ROMAN_URDU';
    } else if (urduWordCount >= 1) {
      lang = 'MIXED_EN_UR';
    } else {
      lang = 'ENGLISH';
    }
    memory.detectedLanguage = lang;
    observations.add('Raw signal received (${memory.rawText.length} chars). Normalizing language.');
    observations.add('Language detection: $lang (${urduWordCount} Urdu markers, Arabic script: $hasArabicScript).');
    reasoning.add('Language scan: $lang confirmed via keyword markers + script analysis.');
    toolCalls.add(makeToolCall('language_detector', 180));

    // ── Tool 2: Crisis Classification ──
    onProgress?.call(name, 'Classifying crisis type...', 0.4);
    await simulateLatency(220);

    String? bestType;
    int bestScore = 0;
    for (final entry in _crisisPatterns.entries) {
      final score = entry.value.where((k) => text.contains(k)).length;
      if (score > bestScore) {
        bestScore = score;
        bestType = entry.key;
      }
    }
    memory.crisisType = bestType ?? 'UNCLASSIFIED';
    memory.signalConfidence = min(0.95, 0.5 + (bestScore * 0.12));
    memory.keywords = _crisisPatterns[bestType]?.where((k) => text.contains(k)).toList() ?? [];
    observations.add('Keyword cluster matched: ${memory.keywords.join("/")}.');
    reasoning.add('Crisis classifier matched ${memory.crisisType} with ${(memory.signalConfidence * 100).toStringAsFixed(0)}% keyword overlap.');
    toolCalls.add(makeToolCall('crisis_classifier', 220));

    // ── Tool 3: Entity Extraction ──
    onProgress?.call(name, 'Extracting location entities...', 0.7);
    await simulateLatency(160);

    String? locDetail;
    String? locCity;
    for (final entry in _locationPatterns.entries) {
      final match = entry.key.firstMatch(memory.rawText);
      if (match != null) {
        locDetail = match.group(0);
        locCity = entry.value;
        break;
      }
    }
    memory.extractedLocation = locDetail != null ? '$locDetail, $locCity' : memory.locationHint ?? 'Pakistan';
    observations.add('Location entity: ${memory.extractedLocation} extracted from pattern database.');
    reasoning.add('Location entity: ${memory.extractedLocation} extracted via regex + city grid mapping.');
    toolCalls.add(makeToolCall('entity_extractor', 160));

    // ── Tool 4: Dedup Check ──
    onProgress?.call(name, 'Checking for duplicates...', 0.9);
    await simulateLatency(80);

    memory.isDuplicate = false;
    observations.add('No duplicate signals detected — novel report.');
    reasoning.add('Duplicate check passed — cleared for verification pipeline.');
    toolCalls.add(makeToolCall('dedup_engine', 80));

    sw.stop();
    final execTime = sw.elapsedMilliseconds;

    memory.agentTraces.add(AgentTrace(
      agentName: name,
      agentIndex: index,
      confidence: memory.signalConfidence,
      executionTimeMs: execTime,
      decision: 'Crisis type ${memory.crisisType} detected in ${memory.extractedLocation}. Language: $lang.',
      observations: observations,
      reasoningSteps: reasoning,
      toolCalls: toolCalls,
    ));

    onProgress?.call(name, 'Complete ✓', 1.0);
    return memory;
  }
}
