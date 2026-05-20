import 'dart:async';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';

import '../theme/app_theme.dart';
import '../services/api_service.dart';

class CrisisInputScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) onAnalysisComplete;
  const CrisisInputScreen({super.key, required this.onAnalysisComplete});

  @override
  State<CrisisInputScreen> createState() => _CrisisInputScreenState();
}

class _CrisisInputScreenState extends State<CrisisInputScreen> with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  String _selectedSource = 'citizen_report';
  bool _isAnalyzing = false;
  String? _errorMessage;
  Map<String, dynamic>? _rejectionInfo;
  late AnimationController _loadingController;
  Timer? _refreshTimer;

  // Live data from backend
  List<Map<String, dynamic>> _liveNews     = [];
  List<Map<String, dynamic>> _earthquakes  = [];
  Map<String, dynamic>       _monitorStatus = {};
  bool _loadingLive = true;

  // Real-time agent progress
  int _currentAgentIndex = 0;
  String _currentAgentName = '';
  String _currentAgentStatus = '';
  double _overallProgress = 0.0;
  final List<_AgentStep> _completedSteps = [];

  @override
  void initState() {
    super.initState();
    _loadingController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
    _fetchLiveData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchLiveData());
  }

  Future<void> _fetchLiveData() async {
    final results = await Future.wait([
      ApiService.getSignalFeed(),
      ApiService.getLiveEarthquakes(),
      ApiService.getMonitorStatus(),
    ]);
    if (mounted) {
      setState(() {
        _liveNews      = results[0] as List<Map<String, dynamic>>;
        _earthquakes   = results[1] as List<Map<String, dynamic>>;
        _monitorStatus = results[2] as Map<String, dynamic>;
        _loadingLive   = false;
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _loadingController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _runAnalysisWithText(String text, String source) async {
    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
      _currentAgentIndex = 0;
      _currentAgentName = '';
      _currentAgentStatus = '';
      _overallProgress = 0.0;
      _completedSteps.clear();
    });

    try {
      final result = await ApiService.analyzeSignal(
        text: text,
        source: source,
        onProgress: (i, name, status, progress) {
          if (mounted) {
            setState(() {
              _currentAgentIndex = i;
              _currentAgentName = name;
              _currentAgentStatus = status;
              _overallProgress = progress;
              if (status == 'Complete ✓' && !_completedSteps.any((s) => s.index == i)) {
                _completedSteps.add(_AgentStep(index: i, name: name));
              }
            });
          }
        },
      );
      // ─── Check if Agent 1 rejected the input ─────────────────────
      // Backend returns status="REJECTED_INVALID_INPUT" when Signal Ingestion
      // can't extract any crisis type OR city. In that case, stay on this screen,
      // show a clear rejection banner, and do NOT navigate to the Map.
      final status = (result['status'] as String? ?? '').toUpperCase();
      final verification = (result['verification_status'] as String? ?? '').toUpperCase();
      if (status == 'REJECTED_INVALID_INPUT' || verification == 'REJECTED') {
        if (mounted) {
          setState(() {
            _rejectionInfo = result;
            _errorMessage = null;
          });
        }
        return;   // do NOT navigate — keep user on Input screen
      }
      // Clear any previous rejection and navigate forward
      if (mounted) setState(() => _rejectionInfo = null);
      widget.onAnalysisComplete(result);
    } catch (e) {
      setState(() => _errorMessage = 'Analysis failed: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _runManualAnalysis() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() => _errorMessage = 'Type a crisis report or click "Analyze" on a live signal below.');
      return;
    }
    await _runAnalysisWithText(text, _selectedSource);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.midnight,
      appBar: AppBar(
        title: const Text('Crisis Intake — LIVE'),
        backgroundColor: AppTheme.deepNavy,
        actions: [_liveBadge()],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.navyBorder),
        ),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            color: AppTheme.electricBlue,
            backgroundColor: AppTheme.deepNavy,
            onRefresh: _fetchLiveData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeInDown(child: _buildLiveStatusBar()),
                  const SizedBox(height: 16),
                  FadeInUp(delay: const Duration(milliseconds: 100), child: _buildManualInput()),
                  const SizedBox(height: 24),
                  if (_errorMessage != null) FadeIn(child: _buildError()),
                  if (_rejectionInfo != null) FadeIn(child: _buildRejectionBanner()),
                  FadeInUp(delay: const Duration(milliseconds: 200), child: _buildEarthquakeSection()),
                  const SizedBox(height: 22),
                  FadeInUp(delay: const Duration(milliseconds: 300), child: _buildLiveNewsSection()),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
          if (_isAnalyzing) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _liveBadge() {
    final running = _monitorStatus['running'] == true;
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (running ? AppTheme.successGreen : AppTheme.alertOrange).withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: (running ? AppTheme.successGreen : AppTheme.alertOrange).withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(color: running ? AppTheme.successGreen : AppTheme.alertOrange, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(running ? 'LIVE' : 'OFFLINE',
              style: TextStyle(
                color: running ? AppTheme.successGreen : AppTheme.alertOrange,
                fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8,
              )),
        ],
      ),
    );
  }

  Widget _buildLiveStatusBar() {
    final scans   = _monitorStatus['scans_total']   ?? 0;
    final signals = _monitorStatus['signals_found'] ?? 0;
    final lastScan = _monitorStatus['last_scan'];
    String timeAgo = '—';
    if (lastScan != null) {
      try {
        final dt = DateTime.parse(lastScan.toString());
        final diff = DateTime.now().difference(dt);
        timeAgo = diff.inSeconds < 60 ? '${diff.inSeconds}s ago' : '${diff.inMinutes}m ago';
      } catch (_) {}
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppTheme.deepNavy, AppTheme.navyCard.withOpacity(0.7)]),
        borderRadius: AppTheme.radiusMd,
        border: Border.all(color: AppTheme.electricBlue.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: AppTheme.electricBlue.withOpacity(0.15), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(gradient: AppTheme.blueGradient, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.satellite_alt, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('LIVE INTELLIGENCE FEED',
                        style: TextStyle(color: AppTheme.electricBlue, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                    Text('Pulling real-time data from Pakistani news + global feeds',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statPill(Icons.refresh, '$scans scans', 'monitor.run()'),
              const SizedBox(width: 8),
              _statPill(Icons.flag, '$signals signals', 'detected'),
              const SizedBox(width: 8),
              _statPill(Icons.access_time, timeAgo, 'last scan'),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: [
              _sourceBadge('Dawn News', AppTheme.alertRed),
              _sourceBadge('Geo TV', AppTheme.alertOrange),
              _sourceBadge('ARY News', AppTheme.alertYellow),
              _sourceBadge('The News', AppTheme.electricBlue),
              _sourceBadge('Tribune', AppTheme.cyanAccent),
              _sourceBadge('WeatherAPI', AppTheme.successGreen),
              _sourceBadge('USGS', AppTheme.glowBlue),
              _sourceBadge('Twilio WA', const Color(0xFF25D366)),
              _sourceBadge('Gemini AI', const Color(0xFFFFD600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statPill(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.navyCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.navyBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppTheme.electricBlue, size: 13),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(value, style: TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                  Text(label, style: TextStyle(color: AppTheme.textMuted, fontSize: 9), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sourceBadge(String name, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 5, height: 5, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(name, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildManualInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.edit_note, color: AppTheme.electricBlue, size: 16),
            const SizedBox(width: 6),
            Text('Type Your Own Crisis Report',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.navyCard,
            borderRadius: AppTheme.radiusMd,
            border: Border.all(color: AppTheme.electricBlue.withOpacity(0.3)),
          ),
          child: TextField(
            controller: _textController,
            maxLines: 4,
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'e.g. Flood in G-10 Islamabad / Karachi mein heat stroke / فوری مدد چاہیے',
              hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _isAnalyzing ? null : _runManualAnalysis,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF1E6FFF), Color(0xFF0D50CC)]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: AppTheme.electricBlue.withOpacity(0.3), blurRadius: 12)],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.analytics_outlined, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text('Run Antigravity Analysis',
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                        child: const Text('6 Agents',
                            style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRejectionBanner() {
    final r = _rejectionInfo!;
    final msg = r['system_message'] as String? ?? 'Input could not be classified.';
    final elapsed = r['total_execution_time_ms'] as int? ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [
            AppTheme.alertOrange.withOpacity(0.18),
            AppTheme.alertRed.withOpacity(0.12),
            AppTheme.deepNavy,
          ],
        ),
        borderRadius: AppTheme.radiusLg,
        border: Border.all(color: AppTheme.alertOrange.withOpacity(0.5), width: 1.5),
        boxShadow: [BoxShadow(color: AppTheme.alertOrange.withOpacity(0.25), blurRadius: 16)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppTheme.alertOrange, AppTheme.alertRed]),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(color: AppTheme.alertOrange.withOpacity(0.5), blurRadius: 10)],
                ),
                child: const Icon(Icons.block, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('AGENT 1 — FALLBACK TRIGGERED',
                            style: TextStyle(color: AppTheme.alertOrange, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.alertRed,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('REJECTED',
                              style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('Signal Ingestion Agent halted the pipeline',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _rejectionInfo = null),
                child: const Icon(Icons.close, color: AppTheme.textMuted, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.navyCard.withOpacity(0.6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.alertOrange.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Why the input was rejected:',
                    style: TextStyle(color: AppTheme.alertOrange, fontSize: 11, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(msg, style: TextStyle(color: AppTheme.textPrimary, fontSize: 12, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.timer_outlined, color: AppTheme.textMuted, size: 12),
              const SizedBox(width: 4),
              Text('${elapsed}ms · 1/6 agents · 5/6 skipped',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
              const Spacer(),
              Text('Agents 2-6: not invoked',
                  style: TextStyle(color: AppTheme.successGreen, fontSize: 10, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.electricBlue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.electricBlue.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.tips_and_updates_outlined, color: AppTheme.electricBlue, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('How to fix this report:',
                          style: TextStyle(color: AppTheme.electricBlue, fontSize: 11, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(
                        '• Mention what is happening (flood, fire, accident, heatwave...)\n'
                        '• Mention a Pakistani city (Karachi, Lahore, Dadu, anywhere)\n'
                        '• Example: "Fire emergency in Lahore Mall Road"',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.alertRed.withOpacity(0.1),
        borderRadius: AppTheme.radiusMd,
        border: Border.all(color: AppTheme.alertRed.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.alertRed, size: 14),
          const SizedBox(width: 8),
          Expanded(child: Text(_errorMessage!, style: TextStyle(color: AppTheme.alertRed, fontSize: 12))),
          GestureDetector(
            onTap: () => setState(() => _errorMessage = null),
            child: const Icon(Icons.close, color: AppTheme.alertRed, size: 14),
          ),
        ],
      ),
    );
  }

  // ─── USGS Earthquakes Section ─────────────────────────────────────────
  Widget _buildEarthquakeSection() {
    if (_earthquakes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.navyCard.withOpacity(0.5),
          borderRadius: AppTheme.radiusMd,
          border: Border.all(color: AppTheme.navyBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.vibration, color: AppTheme.textMuted, size: 16),
            const SizedBox(width: 8),
            Text('No earthquakes in the last 24h in Pakistan region',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: AppTheme.alertOrange.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.vibration, color: AppTheme.alertOrange, size: 14),
            ),
            const SizedBox(width: 8),
            Text('Live Earthquakes (USGS)',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppTheme.successGreen.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
              child: Text('REAL', style: TextStyle(color: AppTheme.successGreen, fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            ),
            const Spacer(),
            Text('${_earthquakes.length} in 24h',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 10),
        ..._earthquakes.take(4).map((eq) => _buildEarthquakeCard(eq)),
      ],
    );
  }

  Widget _buildEarthquakeCard(Map<String, dynamic> eq) {
    final sev = eq['severity'] as String? ?? 'LOW';
    final color = AppTheme.severityColor(sev);
    final mag = (eq['magnitude'] as num? ?? 0).toDouble();
    final place = eq['place'] as String? ?? 'Unknown';
    final depth = (eq['depth_km'] as num? ?? 0).toDouble();
    String timeAgo = '';
    if (eq['time'] != null) {
      try {
        final dt = DateTime.parse(eq['time'].toString());
        final diff = DateTime.now().difference(dt);
        if (diff.inMinutes < 60) timeAgo = '${diff.inMinutes}m ago';
        else if (diff.inHours < 24) timeAgo = '${diff.inHours}h ago';
        else timeAgo = '${diff.inDays}d ago';
      } catch (_) {}
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppTheme.deepNavy, color.withOpacity(0.05)]),
        borderRadius: AppTheme.radiusMd,
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [color, color.withOpacity(0.3)]),
            ),
            child: Center(
              child: Text(mag.toStringAsFixed(1),
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(place,
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text('M$mag • ${depth.toStringAsFixed(0)}km deep',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                    if (timeAgo.isNotEmpty) ...[
                      Text(' • ', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                      Text(timeAgo, style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _runAnalysisWithText(eq['text'] as String, 'usgs_realtime'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF1E6FFF), Color(0xFF0D50CC)]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flash_on, color: Colors.white, size: 12),
                  SizedBox(width: 4),
                  Text('Analyze', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Live News Section ───────────────────────────────────────────────
  Widget _buildLiveNewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: AppTheme.electricBlue.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.newspaper, color: AppTheme.electricBlue, size: 14),
            ),
            const SizedBox(width: 8),
            Text('Live Pakistan News Feed',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppTheme.successGreen.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
              child: Text('REAL', style: TextStyle(color: AppTheme.successGreen, fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            ),
            const Spacer(),
            Text('${_liveNews.length} signals',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 4),
        Text('Tap "Analyze" to run the 6-agent pipeline on any real headline',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        const SizedBox(height: 10),
        if (_loadingLive)
          const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppTheme.electricBlue)))
        else if (_liveNews.isEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('No live signals available yet — backend monitor is still scanning.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          )
        else
          ..._liveNews.take(12).map(_buildNewsCard),
      ],
    );
  }

  Widget _buildNewsCard(Map<String, dynamic> sig) {
    final text = sig['text'] as String? ?? '';
    final source = sig['source'] as String? ?? 'news_agency';
    final city = sig['city'] as String? ?? sig['location_hint'] as String? ?? '';
    final crisisType = sig['crisis_type'] as String? ?? '';
    final confidence = (sig['confidence'] as num?)?.toDouble() ?? 0;

    final sourceColors = {
      'news_agency': AppTheme.electricBlue,
      'citizen_report': AppTheme.cyanAccent,
      'weather_api': AppTheme.alertOrange,
      'social_media': AppTheme.alertYellow,
      'whatsapp_helpline': const Color(0xFF25D366),
    };
    final color = sourceColors[source] ?? AppTheme.glowBlue;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.navyCard,
        borderRadius: AppTheme.radiusMd,
        border: Border.all(color: AppTheme.navyBorder),
      ),
      child: Row(
        children: [
          Container(width: 3, height: 50,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text,
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 12, height: 1.3),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                      child: Text(source.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                    ),
                    if (crisisType.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: AppTheme.alertOrange.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                        child: Text(crisisType,
                            style: TextStyle(color: AppTheme.alertOrange, fontSize: 8, fontWeight: FontWeight.w700)),
                      ),
                    ],
                    if (city.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(city.toUpperCase(),
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 9, fontWeight: FontWeight.w600)),
                    ],
                    if (confidence > 0) ...[
                      const SizedBox(width: 4),
                      Text('${(confidence * 100).round()}%',
                          style: TextStyle(color: AppTheme.cyanAccent, fontSize: 9, fontWeight: FontWeight.w700)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _runAnalysisWithText(text, source),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF1E6FFF), Color(0xFF0D50CC)]),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: AppTheme.electricBlue.withOpacity(0.3), blurRadius: 8)],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flash_on, color: Colors.white, size: 12),
                  SizedBox(width: 4),
                  Text('Analyze',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Loading Overlay ─────────────────────────────────────────────────
  Widget _buildLoadingOverlay() {
    final agentNames = ['Signal Ingestion', 'Verification', 'Severity Analysis',
                        'Response Planning', 'Execution Simulation', 'Fallback & Recovery'];
    return Container(
      color: AppTheme.midnight.withOpacity(0.95),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 90, height: 90,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _loadingController,
                      builder: (_, __) => Transform.rotate(
                        angle: _loadingController.value * 6.28,
                        child: Container(
                          width: 90, height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: SweepGradient(colors: [AppTheme.electricBlue, AppTheme.electricBlue.withOpacity(0)]),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 72, height: 72,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.midnight),
                      child: Center(
                        child: Text('$_currentAgentIndex/6',
                            style: TextStyle(color: AppTheme.electricBlue, fontSize: 20, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Antigravity Orchestration',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(_currentAgentName.isNotEmpty ? _currentAgentName : 'Initializing pipeline...',
                  style: TextStyle(color: AppTheme.electricBlue, fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(_currentAgentStatus, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 20),
              Container(
                height: 4,
                width: 300,
                decoration: BoxDecoration(color: AppTheme.navyBorder, borderRadius: BorderRadius.circular(2)),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: _overallProgress.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF1E6FFF), Color(0xFF00E5FF)]),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ...agentNames.asMap().entries.map((e) {
                final i = e.key;
                final name = e.value;
                final isCompleted = _completedSteps.any((s) => s.index == i + 1);
                final isActive = _currentAgentIndex == i + 1 && !isCompleted;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        child: isCompleted
                            ? const Icon(Icons.check_circle, color: AppTheme.successGreen, size: 16)
                            : isActive
                                ? SizedBox(width: 14, height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.electricBlue))
                                : const Icon(Icons.radio_button_unchecked, color: AppTheme.textMuted, size: 14),
                      ),
                      const SizedBox(width: 10),
                      Text('Agent ${i + 1}: $name',
                          style: TextStyle(
                            color: isCompleted ? AppTheme.successGreen
                                : isActive ? AppTheme.textPrimary : AppTheme.textMuted,
                            fontSize: 12,
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                          )),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgentStep {
  final int index;
  final String name;
  _AgentStep({required this.index, required this.name});
}
