import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';

import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';

class OutcomeScreen extends StatefulWidget {
  final Map<String, dynamic>? analysisResult;
  const OutcomeScreen({super.key, this.analysisResult});

  @override
  State<OutcomeScreen> createState() => _OutcomeScreenState();
}

class _OutcomeScreenState extends State<OutcomeScreen> with TickerProviderStateMixin {
  late AnimationController _counterController;
  bool _showBaseline = false;

  // Extract real or use mock data
  Map<String, dynamic> get _sim => (widget.analysisResult?['simulation'] as Map<String, dynamic>?) ?? {
    'congestion_level_before': 88,
    'congestion_level_after': 32,
    'alerts_sent': 34320,
    'emergency_units_dispatched': 6,
    'roads_rerouted': ['Srinagar Highway', 'G-10 Markaz Road'],
    'hospitals_notified': 2,
    'population_helped': 28600,
    'response_time_minutes': 8,
    'emergency_tickets': ['DISP-A3F7C2', 'RTE-B8E2D1', 'ALT-C5F1A9', 'MED-D2E3B1'],
    'execution_logs': [
      '[08:15:05] ✅ Rescue 1122: Dispatch order #DISP-A3F7C2 issued. 3 units en route.',
      '[08:15:17] ✅ Traffic Police: Road reroute #RTE-B8E2D1 activated. 2 roads reconfigured.',
      '[08:15:29] ✅ PEMRA/PTA: Alert #ALT-C5F1A9 broadcast. 34,320 citizens notified.',
      '[08:15:41] ✅ PIMS Hospital: Medical alert #MED-D2E3B1. 2 facilities on standby.',
      '[08:20:00] 📊 POST-RESPONSE: Congestion ↓56pts | 28,600 residents assisted',
    ],
  };

  Map<String, dynamic> get _result => widget.analysisResult ?? {
    'crisis_type': 'FLOODING',
    'location': 'G-10, Islamabad',
    'severity': 'CRITICAL',
    'confidence': 0.82,
    'total_execution_time_ms': 3284,
    'action_plan': [],
  };

  @override
  void initState() {
    super.initState();
    _counterController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..forward();
  }

  @override
  void dispose() {
    _counterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.midnight,
      appBar: AppBar(
        title: const Text('Crisis Response Outcome'),
        backgroundColor: AppTheme.deepNavy,
        actions: [
          GestureDetector(
            onTap: () => setState(() => _showBaseline = !_showBaseline),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.alertYellow.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.alertYellow.withOpacity(0.3)),
              ),
              child: Text(_showBaseline ? 'Show SAHARA' : 'vs Traditional', style: TextStyle(color: AppTheme.alertYellow, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: AppTheme.navyBorder, height: 1)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeInDown(child: _buildHeaderCard()),
            const SizedBox(height: 16),
            if (_showBaseline) ...[
              FadeInUp(child: _buildBaselineComparison()),
              const SizedBox(height: 16),
            ],
            FadeInUp(delay: const Duration(milliseconds: 100), child: _buildBeforeAfterComparison()),
            const SizedBox(height: 16),
            FadeInUp(delay: const Duration(milliseconds: 150), child: _buildCongestionChart()),
            const SizedBox(height: 16),
            FadeInUp(delay: const Duration(milliseconds: 200), child: _buildImpactMetrics()),
            const SizedBox(height: 16),
            FadeInUp(delay: const Duration(milliseconds: 250), child: _buildTicketList()),
            const SizedBox(height: 16),
            FadeInUp(delay: const Duration(milliseconds: 300), child: _buildExecutionLog()),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    final severity = _result['severity'] as String? ?? 'CRITICAL';
    final color = AppTheme.severityColor(severity);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppTheme.navyCard, AppTheme.navyCard.withOpacity(0.8)]),
        borderRadius: AppTheme.radiusLg,
        border: Border.all(color: AppTheme.successGreen.withOpacity(0.3)),
      ),
      child: Column(children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppTheme.successGreen.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.check_circle, color: AppTheme.successGreen, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Response Complete', style: TextStyle(color: AppTheme.successGreen, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            Text('${_result['crisis_type']} • ${_result['location']}', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.3))),
            child: Text(severity, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 12),
        Container(height: 1, color: AppTheme.navyBorder),
        const SizedBox(height: 12),
        Row(children: [
          _buildQuickStat('Execution', '${((_result['total_execution_time_ms'] as num?)?.toInt() ?? 3284)}ms', AppTheme.glowBlue),
          _buildQuickStat('Confidence', '${((((_result['confidence'] as num?)?.toDouble() ?? 0.82) * 100).toStringAsFixed(0))}%', AppTheme.successGreen),
          _buildQuickStat('Response', '${(_sim['response_time_minutes'] as num?)?.toInt() ?? 8} min', AppTheme.alertOrange),
        ]),
      ]),
    );
  }

  Widget _buildQuickStat(String label, String value, Color color) {
    return Expanded(child: Column(children: [
      Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w700)),
      Text(label, style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
    ]));
  }

  Widget _buildBeforeAfterComparison() {
    final before = (_sim['congestion_level_before'] as num?)?.toInt() ?? 88;
    final after = (_sim['congestion_level_after'] as num?)?.toInt() ?? 32;
    final popHelped = (_sim['population_helped'] as num?)?.toInt() ?? 28600;
    final alertsSent = (_sim['alerts_sent'] as num?)?.toInt() ?? 34320;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Before vs After', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _buildStateCard('BEFORE', [
            {'label': 'Congestion', 'value': '$before%', 'color': AppTheme.alertRed},
            {'label': 'Responders', 'value': '0', 'color': AppTheme.textMuted},
            {'label': 'Alerts Sent', 'value': '0', 'color': AppTheme.textMuted},
            {'label': 'Helped', 'value': '0', 'color': AppTheme.textMuted},
          ], AppTheme.alertRed, Icons.warning_amber_rounded)),
          const SizedBox(width: 12),
          Expanded(child: _buildStateCard('AFTER', [
            {'label': 'Congestion', 'value': '$after%', 'color': AppTheme.successGreen},
            {'label': 'Responders', 'value': '${(_sim['emergency_units_dispatched'] as num?)?.toInt() ?? 6}', 'color': AppTheme.electricBlue},
            {'label': 'Alerts Sent', 'value': _formatNum(alertsSent), 'color': AppTheme.glowBlue},
            {'label': 'Helped', 'value': _formatNum(popHelped), 'color': AppTheme.successGreen},
          ], AppTheme.successGreen, Icons.check_circle_outline)),
        ]),
      ],
    );
  }

  Widget _buildStateCard(String label, List<Map<String, dynamic>> metrics, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color.withOpacity(0.08), AppTheme.navyCard]),
        borderRadius: AppTheme.radiusMd,
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
        ]),
        const SizedBox(height: 12),
        ...metrics.map((m) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(children: [
            Text(m['value'] as String, style: TextStyle(color: m['color'] as Color, fontSize: 18, fontWeight: FontWeight.w700)),
            Text(m['label'] as String, style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
          ]),
        )).toList(),
      ]),
    );
  }

  Widget _buildCongestionChart() {
    final before = (_sim['congestion_level_before'] as num?)?.toDouble() ?? 88;
    final after = (_sim['congestion_level_after'] as num?)?.toDouble() ?? 32;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(gradient: AppTheme.cardGradient, borderRadius: AppTheme.radiusMd, border: Border.all(color: AppTheme.navyBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Congestion Reduction', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('${(before - after).toStringAsFixed(0)} point improvement — ${((before - after) / before * 100).toStringAsFixed(0)}% reduction', style: TextStyle(color: AppTheme.successGreen, fontSize: 12)),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: BarChart(BarChartData(
            barGroups: [
              BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: before, color: AppTheme.alertRed, width: 40, borderRadius: BorderRadius.circular(4))]),
              BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: after, color: AppTheme.successGreen, width: 40, borderRadius: BorderRadius.circular(4))]),
            ],
            borderData: FlBorderData(show: false),
            gridData: FlGridData(show: false),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) => Text(v == 0 ? 'Before' : 'After', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)))),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            maxY: 100,
          )),
        ),
      ]),
    );
  }

  Widget _buildImpactMetrics() {
    final metrics = [
      {'label': 'Population Helped', 'value': _formatNum((_sim['population_helped'] as num?)?.toInt() ?? 28600), 'icon': Icons.people, 'color': AppTheme.electricBlue},
      {'label': 'Alerts Sent', 'value': _formatNum((_sim['alerts_sent'] as num?)?.toInt() ?? 34320), 'icon': Icons.notifications_active, 'color': AppTheme.alertOrange},
      {'label': 'Tickets Generated', 'value': '${((_sim['emergency_tickets'] as List?)?.length ?? 4)}', 'icon': Icons.confirmation_number, 'color': AppTheme.cyanAccent},
      {'label': 'Hospitals Notified', 'value': '${(_sim['hospitals_notified'] as num?)?.toInt() ?? 2}', 'icon': Icons.local_hospital, 'color': AppTheme.successGreen},
    ];
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.0,
      children: metrics.asMap().entries.map((e) {
        final m = e.value;
        return FadeInUp(
          delay: Duration(milliseconds: 50 * e.key),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(gradient: AppTheme.cardGradient, borderRadius: AppTheme.radiusMd, border: Border.all(color: AppTheme.navyBorder)),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: (m['color'] as Color).withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Icon(m['icon'] as IconData, color: m['color'] as Color, size: 18)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(m['value'] as String, style: TextStyle(color: m['color'] as Color, fontSize: 16, fontWeight: FontWeight.w700)),
                Text(m['label'] as String, style: TextStyle(color: AppTheme.textMuted, fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
            ]),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBaselineComparison() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppTheme.alertYellow.withOpacity(0.05), AppTheme.navyCard]),
        borderRadius: AppTheme.radiusMd,
        border: Border.all(color: AppTheme.alertYellow.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('SAHARA AI vs Traditional Systems', style: TextStyle(color: AppTheme.alertYellow, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        _buildCompRow('Detection Time', 'Manual reporting: 25-45 min', 'SAHARA: < 8 seconds'),
        _buildCompRow('Coordination', '5+ phone calls between depts', 'Automated: instant notification'),
        _buildCompRow('Accuracy', 'Single source, unverified', 'Multi-source verified: 82% confidence'),
        _buildCompRow('Coverage', 'City-by-city, no automation', 'Pakistan-wide: multi-city monitoring'),
        _buildCompRow('Fallback', 'No recovery plan', 'Automatic API fallback + recovery'),
      ]),
    );
  }

  Widget _buildCompRow(String label, String before, String after) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppTheme.alertRed.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
            child: Text(before, style: TextStyle(color: AppTheme.alertRed.withOpacity(0.8), fontSize: 10)))),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.arrow_forward, color: AppTheme.textMuted, size: 14)),
          Expanded(child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppTheme.successGreen.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
            child: Text(after, style: TextStyle(color: AppTheme.successGreen, fontSize: 10)))),
        ]),
      ]),
    );
  }

  Widget _buildTicketList() {
    final tickets = (_sim['emergency_tickets'] as List?)?.cast<String>() ?? ['DISP-A3F7', 'RTE-B8E2', 'ALT-C5F1', 'MED-D2E3'];
    final icons = [Icons.medical_services, Icons.alt_route, Icons.notifications_active, Icons.local_hospital];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Emergency Tickets (${tickets.length})', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8, runSpacing: 8,
        children: tickets.asMap().entries.map((e) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(gradient: AppTheme.cardGradient, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.navyBorder)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icons[e.key % icons.length], color: AppTheme.electricBlue, size: 12),
            const SizedBox(width: 6),
            Text(e.value, style: TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w600, fontFeatures: [])),
          ]),
        )).toList(),
      ),
    ]);
  }

  Widget _buildExecutionLog() {
    final logs = (_sim['execution_logs'] as List?)?.cast<String>() ?? [];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Execution Log', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: AppTheme.radiusMd, border: Border.all(color: AppTheme.navyBorder)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: logs.map((log) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(log, style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, height: 1.5)),
          )).toList(),
        ),
      ),
    ]);
  }

  String _formatNum(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}
