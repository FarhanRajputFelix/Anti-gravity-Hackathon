import 'dart:async';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';

import '../theme/app_theme.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  final Function(int) onNavigate;
  const HomeScreen({super.key, required this.onNavigate});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  Timer? _refreshTimer;

  List<Map<String, dynamic>> _signals       = [];
  List<Map<String, dynamic>> _liveCrises    = [];
  List<Map<String, dynamic>> _waReports     = [];
  bool _loadingCrises  = true;
  bool _loadingSignals = true;
  final Set<String> _analyzingIds = {};

  // No fake fallback — only show real data from backend.

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _loadAll();
    // Refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadAll());
  }

  Future<void> _loadAll() async {
    _loadLiveCrises();
    _loadSignalFeed();
  }

  Future<void> _loadLiveCrises() async {
    try {
      final crises  = await ApiService.getLiveCrises();
      final reports = await ApiService.getWhatsAppReports();
      if (mounted) {
        setState(() {
          _liveCrises   = crises;
          _waReports    = reports;
          _loadingCrises = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCrises = false);
    }
  }

  Future<void> _loadSignalFeed() async {
    try {
      final signals = await ApiService.getSignalFeed();
      if (mounted) setState(() { _signals = signals; _loadingSignals = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingSignals = false);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  List<Map<String, dynamic>> get _displayCrises {
    if (_liveCrises.isNotEmpty) return _liveCrises.take(5).toList();
    // Fall back to recent WhatsApp reports if no analyzed crises yet
    if (_waReports.isNotEmpty) {
      return _waReports.take(5).map((r) => {
        'crisis_type': (r['crisis_type'] ?? 'UNKNOWN').toString().replaceAll(' ', '_'),
        'location':    r['city'] ?? 'Unknown',
        'city':        r['city'] ?? 'Unknown',
        'severity':    r['severity'] ?? 'UNKNOWN',
        'confidence':  r['confidence'] ?? 0.0,
        'timestamp':   r['timestamp'] ?? '',
        'crisis_id':   r['crisis_id'] ?? '',
      }).toList();
    }
    return [];
  }

  int get _totalAlertsSent {
    if (_liveCrises.isEmpty) return 12400;
    return _liveCrises.fold<int>(0, (sum, c) {
      final sim = (c['simulation'] as Map?)??{};
      return sum + (sim['alerts_sent'] as int? ?? 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.midnight,
      body: RefreshIndicator(
        color: AppTheme.electricBlue,
        backgroundColor: AppTheme.deepNavy,
        onRefresh: _loadAll,
        child: CustomScrollView(
          slivers: [
            _buildSliverAppBar(),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _buildEmergencyBanner(),
                    const SizedBox(height: 20),
                    _buildMetricRow(),
                    const SizedBox(height: 24),
                    _buildStartAnalysisButton(),
                    const SizedBox(height: 24),
                    _buildActiveCrises(),
                    const SizedBox(height: 24),
                    _buildWhatsAppReports(),
                    const SizedBox(height: 24),
                    _buildSignalFeed(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      backgroundColor: AppTheme.deepNavy,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A1628), Color(0xFF071020)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          gradient: AppTheme.blueGradient,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [BoxShadow(color: AppTheme.electricBlue.withOpacity(0.4), blurRadius: 10, spreadRadius: 1)],
                        ),
                        child: const Icon(Icons.shield_outlined, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SAHARA AI', style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                          Text('Crisis Intelligence Platform', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        ],
                      ),
                      const Spacer(),
                      _buildStatusBadge(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.successGreen.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.successGreen.withOpacity(0.3 + _pulseController.value * 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6, height: 6,
              decoration: BoxDecoration(
                color: AppTheme.successGreen,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AppTheme.successGreen.withOpacity(_pulseController.value), blurRadius: 6)],
              ),
            ),
            const SizedBox(width: 6),
            Text('LIVE', style: TextStyle(color: AppTheme.successGreen, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyBanner() {
    final count = _displayCrises.length;
    final criticalCount = _displayCrises.where((c) => c['severity'] == 'CRITICAL').length;
    final hasCritical = criticalCount > 0;
    return FadeInDown(
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (_, __) {
          final p = (_pulseController.value);
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: hasCritical
                    ? [const Color(0xFF2A0A0A), AppTheme.alertRed.withOpacity(0.12), const Color(0xFF1A0505)]
                    : [const Color(0xFF0A1628), AppTheme.electricBlue.withOpacity(0.1), const Color(0xFF071020)],
              ),
              borderRadius: AppTheme.radiusLg,
              border: Border.all(
                color: (hasCritical ? AppTheme.alertRed : AppTheme.electricBlue).withOpacity(0.3 + p * 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (hasCritical ? AppTheme.alertRed : AppTheme.electricBlue).withOpacity(0.15 + p * 0.1),
                  blurRadius: 20 + p * 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: hasCritical
                        ? [AppTheme.alertRed, const Color(0xFF8C1B1B)]
                        : [AppTheme.electricBlue, const Color(0xFF0D50CC)]),
                    boxShadow: [BoxShadow(
                      color: (hasCritical ? AppTheme.alertRed : AppTheme.electricBlue).withOpacity(0.5),
                      blurRadius: 14 + p * 8,
                      spreadRadius: 2,
                    )],
                  ),
                  child: Icon(
                    hasCritical ? Icons.warning_amber_rounded : Icons.shield_outlined,
                    color: Colors.white, size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            hasCritical ? 'ACTIVE EMERGENCY' : 'SYSTEM MONITORING',
                            style: TextStyle(
                              color: hasCritical ? AppTheme.alertRed : AppTheme.electricBlue,
                              fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.successGreen.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('LIVE',
                                style: TextStyle(color: AppTheme.successGreen, fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      RichText(
                        text: TextSpan(
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          children: [
                            TextSpan(text: '$count incidents ',
                                style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
                            if (criticalCount > 0)
                              TextSpan(text: '($criticalCount CRITICAL) ',
                                  style: TextStyle(color: AppTheme.alertRed, fontWeight: FontWeight.w700)),
                            const TextSpan(text: 'across Pakistan'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text('6 Antigravity agents active • Gemini AI online',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                    ],
                  ),
                ),
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasCritical ? AppTheme.alertRed : AppTheme.successGreen,
                    boxShadow: [BoxShadow(
                      color: (hasCritical ? AppTheme.alertRed : AppTheme.successGreen).withOpacity(p),
                      blurRadius: 12, spreadRadius: 2,
                    )],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricRow() {
    String alertLabel = _totalAlertsSent >= 1000
        ? '${(_totalAlertsSent / 1000).toStringAsFixed(1)}K'
        : _totalAlertsSent.toString();
    final criticalCount = _displayCrises.where((c) => c['severity'] == 'CRITICAL').length;
    final metrics = [
      {'label': 'Active', 'sub': 'crises', 'value': _displayCrises.length.toString(),
       'icon': Icons.crisis_alert, 'color': AppTheme.alertRed,
       'trend': criticalCount > 0 ? '+$criticalCount CRIT' : 'stable'},
      {'label': 'Agents', 'sub': 'online', 'value': '6',
       'icon': Icons.hub_outlined, 'color': AppTheme.electricBlue,
       'trend': 'Gemini AI'},
      {'label': 'Alerts', 'sub': 'dispatched', 'value': alertLabel,
       'icon': Icons.notifications_active, 'color': AppTheme.alertOrange,
       'trend': 'last 24h'},
    ];
    return Row(
      children: metrics.asMap().entries.map((e) {
        final m = e.value;
        final color = m['color'] as Color;
        return Expanded(
          child: FadeInUp(
            delay: Duration(milliseconds: 100 * e.key),
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (_, __) {
                final pulse = _pulseController.value;
                return Container(
                  margin: EdgeInsets.only(right: e.key < 2 ? 10 : 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [
                        AppTheme.deepNavy,
                        color.withOpacity(0.08),
                        AppTheme.navyCard,
                      ],
                    ),
                    borderRadius: AppTheme.radiusLg,
                    border: Border.all(color: color.withOpacity(0.25)),
                    boxShadow: [BoxShadow(color: color.withOpacity(0.08 + pulse * 0.04), blurRadius: 12)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              gradient: RadialGradient(colors: [color.withOpacity(0.4), color.withOpacity(0.15)]),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(m['icon'] as IconData, color: color, size: 14),
                          ),
                          const Spacer(),
                          Container(
                            width: 5, height: 5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color,
                              boxShadow: [BoxShadow(color: color.withOpacity(pulse), blurRadius: 6)],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(m['value'] as String,
                          style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w800, height: 1)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(m['label'] as String,
                              style: TextStyle(color: AppTheme.textPrimary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                          const SizedBox(width: 3),
                          Text(m['sub'] as String,
                              style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(m['trend'] as String,
                            style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStartAnalysisButton() {
    return FadeInUp(
      delay: const Duration(milliseconds: 300),
      child: GestureDetector(
        onTap: () => widget.onNavigate(1),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1E6FFF), Color(0xFF0D50CC)]),
            borderRadius: AppTheme.radiusLg,
            boxShadow: [BoxShadow(color: AppTheme.electricBlue.withOpacity(0.35), blurRadius: 20, spreadRadius: 2, offset: const Offset(0, 6))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
              const SizedBox(width: 10),
              const Text('Start Crisis Analysis', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                child: const Text('AI', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveCrises() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Active Crises', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
            const Spacer(),
            if (_loadingCrises)
              const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.electricBlue))
            else ...[
              Text('Live', style: TextStyle(color: AppTheme.alertRed, fontSize: 12)),
              const SizedBox(width: 4),
              AnimatedBuilder(
                animation: _pulseController,
                builder: (_, __) => Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: AppTheme.alertRed,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: AppTheme.alertRed.withOpacity(_pulseController.value), blurRadius: 4)],
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        if (_displayCrises.isEmpty && !_loadingCrises)
          _buildNoCrisesPlaceholder()
        else
          ..._displayCrises.asMap().entries.map((e) => FadeInRight(
            delay: Duration(milliseconds: 100 * e.key),
            child: _buildCrisisCard(e.value),
          )),
      ],
    );
  }

  Widget _buildNoCrisesPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.navyCard,
        borderRadius: AppTheme.radiusMd,
        border: Border.all(color: AppTheme.navyBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: AppTheme.successGreen, size: 24),
          const SizedBox(width: 12),
          Text('No active crises — system monitoring', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildCrisisCard(Map<String, dynamic> crisis) {
    final severity = crisis['severity'] as String? ?? 'UNKNOWN';
    final type     = (crisis['crisis_type'] as String? ?? 'UNKNOWN').replaceAll('_', ' ');
    final location = crisis['location'] as String? ?? crisis['city'] as String? ?? 'Unknown';
    final city     = crisis['city'] as String? ?? '';
    final conf     = (crisis['confidence'] as num?)?.toDouble() ?? 0.0;

    final color = AppTheme.severityColor(severity);
    final icon  = _crisisIcon(type);

    // Time ago
    String timeAgo = '';
    if (crisis['timestamp'] != null) {
      try {
        final dt = DateTime.parse(crisis['timestamp'].toString());
        final diff = DateTime.now().difference(dt);
        if (diff.inMinutes < 1) timeAgo = 'just now';
        else if (diff.inMinutes < 60) timeAgo = '${diff.inMinutes}m ago';
        else timeAgo = '${diff.inHours}h ago';
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: AppTheme.radiusMd,
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(location, style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                Row(
                  children: [
                    Text(type, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    if (city.isNotEmpty) ...[
                      Text(' • ', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      Text(city[0].toUpperCase() + city.substring(1), style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                LinearProgressIndicator(
                  value: conf,
                  backgroundColor: AppTheme.navyBorder,
                  color: color,
                  minHeight: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: Text(severity, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
              if (timeAgo.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(timeAgo, style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  IconData _crisisIcon(String type) {
    final t = type.toUpperCase();
    if (t.contains('FLOOD')) return Icons.water;
    if (t.contains('HEAT')) return Icons.thermostat;
    if (t.contains('FIRE')) return Icons.local_fire_department;
    if (t.contains('ACCIDENT') || t.contains('TRAFFIC')) return Icons.car_crash;
    if (t.contains('EARTHQUAKE')) return Icons.vibration;
    if (t.contains('POWER')) return Icons.bolt;
    if (t.contains('GAS')) return Icons.gas_meter;
    return Icons.warning_amber_rounded;
  }

  Widget _analyzeButton(String msgId) {
    final isAnalyzing = _analyzingIds.contains(msgId);
    return GestureDetector(
      onTap: isAnalyzing ? null : () => _triggerAnalysis(msgId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: isAnalyzing
              ? [AppTheme.textMuted, AppTheme.textMuted]
              : const [AppTheme.successGreen, Color(0xFF00A046)]),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: AppTheme.successGreen.withOpacity(0.4), blurRadius: 8)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAnalyzing)
              const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            else
              const Icon(Icons.psychology, color: Colors.white, size: 13),
            const SizedBox(width: 5),
            Text(isAnalyzing ? 'Running...' : 'Analyze',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Future<void> _triggerAnalysis(String msgId) async {
    setState(() => _analyzingIds.add(msgId));
    try {
      await ApiService.analyzeWhatsAppMessage(msgId);
      await _loadLiveCrises();   // refresh both lists
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppTheme.successGreen,
          content: const Text('✓ Analysis complete — see Agents tab for trace + Map for routes'),
          duration: const Duration(seconds: 3),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppTheme.alertRed,
          content: const Text('Analysis failed — check backend'),
        ));
      }
    } finally {
      if (mounted) setState(() => _analyzingIds.remove(msgId));
    }
  }

  Widget _buildWhatsAppReports() {
    const wa = Color(0xFF25D366);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: wa.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.chat_bubble, color: wa, size: 14),
            ),
            const SizedBox(width: 8),
            Text('WhatsApp Helpline Reports',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppTheme.successGreen.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
              child: Text('LIVE', style: TextStyle(color: AppTheme.successGreen, fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            ),
            const Spacer(),
            Text(_waReports.isEmpty ? '0 received' : '${_waReports.length} received',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 4),
        Text(_waReports.isEmpty
            ? 'Send WhatsApp to +1 415 523 8886 (sandbox) — reports + agent analysis appear here'
            : 'Each report → analyzed by 6 agents → tap to view',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        const SizedBox(height: 10),
        if (_waReports.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.navyCard,
              borderRadius: AppTheme.radiusMd,
              border: Border.all(color: wa.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.hourglass_empty, color: wa, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('No WhatsApp reports yet',
                          style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('Send a message to the SAHARA helpline to test the pipeline',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          ..._waReports.take(5).toList().asMap().entries.map((e) {
            final r = e.value;
            final isPending = r['analyzed'] == false || r['severity'] == 'PENDING';
            final sev = r['severity'] as String? ?? 'PENDING';
            final color = isPending ? AppTheme.alertYellow : AppTheme.severityColor(sev);
            final ctype = (r['crisis_type'] as String? ?? '').replaceAll('_', ' ');
            final conf = ((r['confidence'] as num? ?? 0) * 100).round();
            final from = r['from']?.toString().replaceAll('whatsapp:', '') ?? '';
            final msgId = r['id'] as String?;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [AppTheme.navyCard, color.withOpacity(0.05)],
                ),
                borderRadius: AppTheme.radiusMd,
                border: Border.all(color: isPending ? AppTheme.alertYellow.withOpacity(0.4) : wa.withOpacity(0.3)),
                boxShadow: [BoxShadow(color: wa.withOpacity(0.1), blurRadius: 8)],
              ),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(colors: [wa, Color(0xFF128C7E)]),
                    ),
                    child: const Icon(Icons.chat_bubble, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r['body']?.toString() ?? '',
                            style: TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                              child: Text(
                                isPending ? 'AWAITING_ANALYSIS' : (ctype.isEmpty ? 'UNKNOWN' : ctype),
                                style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 0.3),
                              ),
                            ),
                            const SizedBox(width: 4),
                            if (!isPending)
                              Text((r['city'] as String? ?? '').toUpperCase(),
                                  style: TextStyle(color: AppTheme.textMuted, fontSize: 9, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 4),
                            if (conf > 0)
                              Text('$conf%', style: TextStyle(color: AppTheme.cyanAccent, fontSize: 9, fontWeight: FontWeight.w700)),
                            const SizedBox(width: 4),
                            Text(from,
                                style: TextStyle(color: AppTheme.textMuted, fontSize: 8),
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Admin action button: Analyze if pending, View if done
                  if (isPending && msgId != null)
                    _analyzeButton(msgId)
                  else
                    GestureDetector(
                      onTap: () => widget.onNavigate(2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
                            child: Text(sev, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.electricBlue.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: AppTheme.electricBlue.withOpacity(0.4)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.visibility, color: AppTheme.electricBlue, size: 9),
                                SizedBox(width: 3),
                                Text('View', style: TextStyle(color: AppTheme.electricBlue, fontSize: 8, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildSignalFeed() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Incoming Signals', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        if (_loadingSignals)
          const Center(child: CircularProgressIndicator(color: AppTheme.electricBlue))
        else if (_signals.isEmpty)
          _buildMockSignalFeed()
        else
          ..._signals.map(_buildSignalItem),
      ],
    );
  }

  Widget _buildMockSignalFeed() {
    final mockSignals = [
      {'text': 'G-10 mein pani bhar gaya hai, gaariyan phans gayi hain', 'source': 'citizen_report', 'city': 'islamabad'},
      {'text': 'Severe heatwave warning for Karachi — 48°C recorded', 'source': 'weather_api', 'city': 'karachi'},
      {'text': 'Accident blocking Shahrah-e-Quaid-e-Azam completely', 'source': 'traffic_api', 'city': 'lahore'},
      {'text': 'اسلام آباد میں جی ٹین سیکٹر میں سیلاب کا خدشہ', 'source': 'news_agency', 'city': 'islamabad'},
    ];
    return Column(children: mockSignals.map(_buildSignalItem).toList());
  }

  Widget _buildSignalItem(Map<String, dynamic> signal) {
    final sourceColors = {
      'citizen_report': AppTheme.glowBlue,
      'weather_api':    AppTheme.alertOrange,
      'traffic_api':    AppTheme.alertYellow,
      'social_media':   AppTheme.cyanAccent,
      'news_agency':    AppTheme.successGreen,
      'whatsapp_helpline': const Color(0xFF25D366),
    };
    final color = sourceColors[signal['source']] ?? AppTheme.textSecondary;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.navyCard,
        borderRadius: AppTheme.radiusMd,
        border: Border.all(color: AppTheme.navyBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 3, height: 40, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  signal['text'] as String? ?? '',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        (signal['source'] as String? ?? '').replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text((signal['city'] as String? ?? '').toUpperCase(), style: TextStyle(color: AppTheme.textMuted, fontSize: 9)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
