import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';

import '../theme/app_theme.dart';

class AgentTraceScreen extends StatefulWidget {
  final Map<String, dynamic>? analysisResult;
  const AgentTraceScreen({super.key, this.analysisResult});

  @override
  State<AgentTraceScreen> createState() => _AgentTraceScreenState();
}

class _AgentTraceScreenState extends State<AgentTraceScreen>
    with TickerProviderStateMixin {
  late AnimationController _timelineController;
  final Set<int> _expandedCards = {};
  int _visibleCount = 0;

  final List<Map<String, dynamic>> _mockTraces = [
    {
      'agent_name': 'Signal Ingestion Agent',
      'agent_index': 1,
      'confidence': 0.88,
      'execution_time_ms': 312,
      'fallback_triggered': false,
      'decision':
          'Crisis type FLOODING detected in G-10, Islamabad. Language: Roman Urdu.',
      'observations': [
        'Raw signal received (187 chars). Normalizing language.',
        'Arabic/Roman Urdu markers detected. Language: ROMAN_URDU.',
        'Keyword cluster matched: flood/pani/baarish.',
        'No duplicate signals detected — novel report.'
      ],
      'reasoning_steps': [
        'Language scan: Roman Urdu confirmed via keyword markers.',
        'Crisis classifier matched FLOODING with 87% keyword overlap.',
        'Location entity: G-10, Islamabad extracted from pattern database.',
        'Duplicate check passed — cleared for verification pipeline.'
      ],
      'tool_calls': [
        {'tool_name': 'language_detector', 'latency_ms': 120},
        {'tool_name': 'crisis_classifier', 'latency_ms': 200},
        {'tool_name': 'entity_extractor', 'latency_ms': 180},
      ],
    },
    {
      'agent_name': 'Verification Agent',
      'agent_index': 2,
      'confidence': 0.82,
      'execution_time_ms': 743,
      'fallback_triggered': false,
      'decision':
          'Crisis CONFIRMED — weather + traffic + multi-source corroboration. Confidence: 82%.',
      'observations': [
        'Weather API: 87.3mm rainfall, HEAVY_RAIN alert issued by PMD.',
        'Traffic API: congestion 87/100, 14 incidents, 3 roads blocked.',
        '3 correlated signals from 2+ independent sources within 30 min.'
      ],
      'reasoning_steps': [
        '✓ Weather CONSISTENT: 87.3mm/3h rainfall aligns with flooding claim.',
        '✓ Traffic CONSISTENT: Congestion 87/100 + 14 incidents corroborate report.',
        'Multi-source corroboration: citizen + weather + traffic all confirm event.'
      ],
      'tool_calls': [
        {'tool_name': 'mock_weather_api', 'latency_ms': 340},
        {'tool_name': 'mock_traffic_api', 'latency_ms': 280},
        {'tool_name': 'signal_correlation_engine', 'latency_ms': 150},
      ],
    },
    {
      'agent_name': 'Fallback & Recovery Agent',
      'agent_index': 3,
      'confidence': 0.82,
      'execution_time_ms': 198,
      'fallback_triggered': true,
      'decision':
          '2 fallback strategies applied: API substitution + rule-based NLP fallback.',
      'observations': [
        '⚠ Traffic API unavailable. Switching to historical congestion baseline.',
        'Historical pattern for Lahore: typical congestion = 65/100. Accuracy: ±15%.',
        'Gemini NLP API: DEGRADED — rule-based engine substituted at 92% accuracy.'
      ],
      'reasoning_steps': [
        'FALLBACK 1: Live traffic → historical average (65/100, ±15% margin).',
        'FALLBACK 2: Gemini API timeout → rule-based NLP (92% accuracy, 45ms).',
        'Pipeline continuity maintained through 2 failure scenarios.'
      ],
      'tool_calls': [
        {'tool_name': 'historical_traffic_db', 'latency_ms': 180},
        {'tool_name': 'rule_based_nlp_fallback', 'latency_ms': 45},
      ],
    },
    {
      'agent_name': 'Severity Analysis Agent',
      'agent_index': 4,
      'confidence': 0.78,
      'execution_time_ms': 541,
      'fallback_triggered': false,
      'decision':
          'Severity = CRITICAL. Affected: 44,000 citizens. Roads impacted: 3. Urgency: IMMEDIATE.',
      'observations': [
        'Population impact model: 44,000 citizens in affected zone (4% of Islamabad).',
        'Road network: Srinagar Hwy, G-10 Markaz Rd, Murree Rd — 3 of 5 arteries disrupted.',
        'Infrastructure: stormwater systems overwhelmed, underground utilities at risk.'
      ],
      'reasoning_steps': [
        'Crisis type FLOODING + confidence 82% + pop 44,000 → CRITICAL threshold met.',
        'G-10 location covers 3 major road arteries per Islamabad grid analysis.',
        'CRITICAL severity → IMMEDIATE urgency → full resource allocation triggered.'
      ],
      'tool_calls': [
        {'tool_name': 'population_impact_model', 'latency_ms': 210},
        {'tool_name': 'road_network_analyzer', 'latency_ms': 190},
      ],
    },
    {
      'agent_name': 'Response Planning Agent',
      'agent_index': 5,
      'confidence': 0.74,
      'execution_time_ms': 623,
      'fallback_triggered': false,
      'decision':
          '5 coordinated response actions generated. 5 departments alerted. ETA: 8 min.',
      'observations': [
        'Resource inventory: 8 rescue teams, 14 ambulances, 23 traffic wardens available.',
        'CRITICAL severity → Full resource allocation, no sharing with secondary incidents.',
        '5 departments notified via Emergency Management Network.'
      ],
      'reasoning_steps': [
        'Action playbook v3.2 loaded for FLOODING scenario.',
        'Priority order: Life Safety → Access Control → Mitigation → Comms → Medical.',
        'Dept coordination: Rescue 1122 + Traffic Police + WASA + PEMRA + PIMS alerted.'
      ],
      'tool_calls': [
        {'tool_name': 'resource_inventory_api', 'latency_ms': 260},
        {'tool_name': 'department_notification_api', 'latency_ms': 310},
      ],
    },
    {
      'agent_name': 'Execution Simulation Agent',
      'agent_index': 6,
      'confidence': 0.92,
      'execution_time_ms': 867,
      'fallback_triggered': false,
      'decision':
          'All 5 actions EXECUTED. Congestion: 88→32. 34,320 alerts sent. 28,600 citizens helped.',
      'observations': [
        'BEFORE: congestion 88/100, 0 responders, 0 alerts sent.',
        'P1: Rescue 1122 — 3 units dispatched to G-10. Ticket DISP-A3F7C2.',
        'P2: Traffic Police — roads rerouted via I-8. Ticket RTE-B8E2D1.',
        'AFTER: congestion 32/100, 6 units active, 34,320 alerts, 28,600 helped.'
      ],
      'reasoning_steps': [
        'Pre-simulation state snapshot taken at 08:15:00.',
        'Actions executed in priority order with 12-second stagger intervals.',
        'Google Maps rerouting API updated — 2 alternate routes activated, ETA -18 min.'
      ],
      'tool_calls': [
        {'tool_name': 'system_state_snapshot', 'latency_ms': 90},
        {'tool_name': 'google_maps_rerouting_api', 'latency_ms': 430},
        {'tool_name': 'system_state_snapshot', 'latency_ms': 110},
      ],
    },
  ];

  List<Map<String, dynamic>> get _traces {
    final result = widget.analysisResult;
    if (result != null && result['agent_traces'] != null) {
      return List<Map<String, dynamic>>.from(result['agent_traces']);
    }
    return _mockTraces;
  }

  @override
  void initState() {
    super.initState();
    _timelineController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300))
      ..forward();
    _animateCards();
  }

  void _animateCards() async {
    for (int i = 0; i <= _traces.length; i++) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) setState(() => _visibleCount = i);
    }
  }

  @override
  void dispose() {
    _timelineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.midnight,
      appBar: AppBar(
        title: const Text('Agent Reasoning Trace'),
        backgroundColor: AppTheme.deepNavy,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppTheme.navyBorder, height: 1),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.electricBlue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.electricBlue.withOpacity(0.4)),
            ),
            child: Text('${_traces.length} Agents',
                style: const TextStyle(
                    color: AppTheme.electricBlue,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildCrisisSummaryBanner(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
              itemCount: _traces.length,
              itemBuilder: (context, i) {
                if (i >= _visibleCount) return const SizedBox.shrink();
                return _buildAgentCard(i, _traces[i]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCrisisSummaryBanner() {
    final result = widget.analysisResult;
    final severity = result?['severity'] ?? 'CRITICAL';
    final crisisType = result?['crisis_type'] ?? 'FLOODING';
    final location = result?['location'] ?? 'G-10, Islamabad';
    final confidence =
        ((result?['confidence'] ?? 0.82) * 100).toStringAsFixed(0);
    final color = AppTheme.severityColor(severity);

    return FadeInDown(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [color.withOpacity(0.12), AppTheme.navyCard]),
          borderRadius: AppTheme.radiusMd,
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Crisis Detected',
                  style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 10,
                      letterSpacing: 0.8)),
              Text('$crisisType • $location',
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ]),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.4))),
              child: Text(severity,
                  style: TextStyle(
                      color: color, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: AppTheme.successGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20)),
              child: Text('$confidence% conf.',
                  style: const TextStyle(
                      color: AppTheme.successGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgentCard(int index, Map<String, dynamic> trace) {
    final isExpanded = _expandedCards.contains(index);
    final isFallback = trace['fallback_triggered'] == true;
    final confidence = (trace['confidence'] as num?)?.toDouble() ?? 0.8;
    final agentColor =
        isFallback ? AppTheme.alertOrange : AppTheme.electricBlue;

    return FadeInUp(
      duration: const Duration(milliseconds: 300),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline column
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: isFallback
                          ? [AppTheme.alertOrange, const Color(0xFFCC5A00)]
                          : [AppTheme.electricBlue, const Color(0xFF0D50CC)]),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: agentColor.withOpacity(0.35), blurRadius: 8)
                  ],
                ),
                child: Center(
                    child: Text('${trace['agent_index']}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700))),
              ),
              if (index < _traces.length - 1)
                Container(width: 2, height: 20, color: AppTheme.navyBorder),
            ],
          ),
          const SizedBox(width: 12),
          // Card
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                if (isExpanded) {
                  _expandedCards.remove(index);
                } else {
                  _expandedCards.add(index);
                }
              }),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  gradient: AppTheme.cardGradient,
                  borderRadius: AppTheme.radiusMd,
                  border: Border.all(
                      color: isFallback
                          ? AppTheme.alertOrange.withOpacity(0.3)
                          : AppTheme.navyBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCardHeader(
                        trace, isFallback, agentColor, confidence, isExpanded),
                    if (isExpanded) _buildCardBody(trace),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardHeader(Map<String, dynamic> trace, bool isFallback,
      Color agentColor, double confidence, bool isExpanded) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(trace['agent_name'] ?? '',
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              if (isFallback)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppTheme.alertOrange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: AppTheme.alertOrange.withOpacity(0.3))),
                  child: const Text('FALLBACK',
                      style: TextStyle(
                          color: AppTheme.alertOrange,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5)),
                ),
              Icon(isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: AppTheme.textMuted, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          Text(trace['decision'] ?? '',
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              maxLines: isExpanded ? 5 : 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 10),
          Row(children: [
            _buildConfidencePill(confidence, agentColor),
            const SizedBox(width: 8),
            _buildTimePill(trace['execution_time_ms'] ?? 0),
            const SizedBox(width: 8),
            _buildToolsPill(trace),
          ]),
        ],
      ),
    );
  }

  Widget _buildConfidencePill(double confidence, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.verified_outlined, color: color, size: 10),
        const SizedBox(width: 4),
        Text('${(confidence * 100).toStringAsFixed(0)}%',
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _buildTimePill(int ms) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: AppTheme.navyBorder.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.timer_outlined, color: AppTheme.textMuted, size: 10),
        const SizedBox(width: 4),
        Text('${ms}ms',
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
      ]),
    );
  }

  Widget _buildToolsPill(Map<String, dynamic> trace) {
    final tools = trace['tool_calls'] as List? ?? [];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: AppTheme.cyanAccent.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.api_outlined, color: AppTheme.cyanAccent, size: 10),
        const SizedBox(width: 4),
        Text('${tools.length} calls',
            style: const TextStyle(color: AppTheme.cyanAccent, fontSize: 10)),
      ]),
    );
  }

  Widget _buildCardBody(Map<String, dynamic> trace) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.navyBorder)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSection('Observations', trace['observations'] as List? ?? [],
              Icons.remove_red_eye_outlined, AppTheme.glowBlue),
          const SizedBox(height: 12),
          _buildSection(
              'Reasoning Steps',
              trace['reasoning_steps'] as List? ?? [],
              Icons.psychology_outlined,
              AppTheme.cyanAccent),
          const SizedBox(height: 12),
          _buildToolCalls(trace['tool_calls'] as List? ?? []),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List items, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(title,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
        ]),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                    margin: const EdgeInsets.only(top: 5),
                    width: 4,
                    height: 4,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(item.toString(),
                        style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                            height: 1.5))),
              ]),
            )),
      ],
    );
  }

  Widget _buildToolCalls(List tools) {
    if (tools.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(children: [
          Icon(Icons.api_outlined, color: AppTheme.cyanAccent, size: 14),
          SizedBox(width: 6),
          Text('Tool / API Calls',
              style: TextStyle(
                  color: AppTheme.cyanAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 8),
        ...tools.map((t) {
          final tool = t as Map<String, dynamic>;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppTheme.cyanAccent.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.cyanAccent.withOpacity(0.15)),
            ),
            child: Row(children: [
              const Icon(Icons.code, color: AppTheme.cyanAccent, size: 12),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(tool['tool_name'] ?? '',
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500))),
              Text('${tool['latency_ms']}ms',
                  style:
                      const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
            ]),
          );
        }),
      ],
    );
  }
}
