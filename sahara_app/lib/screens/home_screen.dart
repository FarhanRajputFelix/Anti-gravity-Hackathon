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
  List<Map<String, dynamic>> _signals = [];
  bool _loadingSignals = true;

  final List<Map<String, dynamic>> _activeCrises = [
    {'type': 'FLOODING', 'location': 'G-10, Islamabad', 'severity': 'CRITICAL', 'time': '8 min ago'},
    {'type': 'HEATWAVE', 'location': 'Saddar, Karachi', 'severity': 'HIGH', 'time': '23 min ago'},
    {'type': 'ACCIDENT', 'location': 'Mall Road, Lahore', 'severity': 'MEDIUM', 'time': '47 min ago'},
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _loadSignalFeed();
  }

  Future<void> _loadSignalFeed() async {
    try {
      final signals = await ApiService.getSignalFeed();
      setState(() { _signals = signals; _loadingSignals = false; });
    } catch (_) {
      setState(() { _loadingSignals = false; });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.midnight,
      body: CustomScrollView(
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
                  _buildSignalFeed(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
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
                          Text("Crisis Intelligence Platform", style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
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
              decoration: BoxDecoration(color: AppTheme.successGreen, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AppTheme.successGreen.withOpacity(_pulseController.value), blurRadius: 6)]),
            ),
            const SizedBox(width: 6),
            Text('ONLINE', style: TextStyle(color: AppTheme.successGreen, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyBanner() {
    return FadeInDown(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF2A0A0A), Color(0xFF1A0505)]),
          borderRadius: AppTheme.radiusMd,
          border: Border.all(color: AppTheme.alertRed.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppTheme.alertRed.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.warning_amber_rounded, color: AppTheme.alertRed, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ACTIVE EMERGENCY', style: TextStyle(color: AppTheme.alertRed, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                  Text('3 crisis events detected across Pakistan — Antigravity agents monitoring', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow() {
    final metrics = [
      {'label': 'Active Crises', 'value': '3', 'icon': Icons.crisis_alert, 'color': AppTheme.alertRed},
      {'label': 'Agents Active', 'value': '6', 'icon': Icons.hub_outlined, 'color': AppTheme.electricBlue},
      {'label': 'Alerts Sent', 'value': '12.4K', 'icon': Icons.notifications_active, 'color': AppTheme.alertOrange},
    ];
    return Row(
      children: metrics.asMap().entries.map((e) {
        final m = e.value;
        return Expanded(
          child: FadeInUp(
            delay: Duration(milliseconds: 100 * e.key),
            child: Container(
              margin: EdgeInsets.only(right: e.key < 2 ? 10 : 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: AppTheme.cardGradient,
                borderRadius: AppTheme.radiusMd,
                border: Border.all(color: AppTheme.navyBorder),
              ),
              child: Column(
                children: [
                  Icon(m['icon'] as IconData, color: m['color'] as Color, size: 22),
                  const SizedBox(height: 8),
                  Text(m['value'] as String, style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
                  Text(m['label'] as String, style: TextStyle(color: AppTheme.textMuted, fontSize: 10), textAlign: TextAlign.center),
                ],
              ),
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
              Text('Start Crisis Analysis', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                child: Text('AI', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
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
            Text('Live', style: TextStyle(color: AppTheme.alertRed, fontSize: 12)),
            const SizedBox(width: 4),
            AnimatedBuilder(animation: _pulseController, builder: (_, __) => Container(
              width: 6, height: 6,
              decoration: BoxDecoration(color: AppTheme.alertRed, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AppTheme.alertRed.withOpacity(_pulseController.value), blurRadius: 4)]),
            )),
          ],
        ),
        const SizedBox(height: 12),
        ..._activeCrises.asMap().entries.map((e) => FadeInRight(
          delay: Duration(milliseconds: 100 * e.key),
          child: _buildCrisisCard(e.value),
        )).toList(),
      ],
    );
  }

  Widget _buildCrisisCard(Map<String, dynamic> crisis) {
    final color = AppTheme.severityColor(crisis['severity'] as String);
    final icons = {'FLOODING': Icons.water, 'HEATWAVE': Icons.thermostat, 'ACCIDENT': Icons.car_crash};
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
            child: Icon(icons[crisis['type']] ?? Icons.warning, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(crisis['location'] as String, style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                Text(crisis['type'] as String, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: Text(crisis['severity'] as String, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 4),
              Text(crisis['time'] as String, style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
            ],
          ),
        ],
      ),
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
          ..._signals.map((s) => _buildSignalItem(s)).toList(),
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
    return Column(children: mockSignals.map((s) => _buildSignalItem(s)).toList());
  }

  Widget _buildSignalItem(Map<String, dynamic> signal) {
    final sourceColors = {'citizen_report': AppTheme.glowBlue, 'weather_api': AppTheme.alertOrange, 'traffic_api': AppTheme.alertYellow, 'social_media': AppTheme.cyanAccent, 'news_agency': AppTheme.successGreen};
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
          Container(
            width: 3, height: 40,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(signal['text'] as String, style: TextStyle(color: AppTheme.textPrimary, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                      child: Text((signal['source'] as String).replaceAll('_', ' ').toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
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
