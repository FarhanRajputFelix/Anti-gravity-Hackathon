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
  late AnimationController _loadingController;

  // Real-time agent progress from orchestrator
  int _currentAgentIndex = 0;
  String _currentAgentName = '';
  String _currentAgentStatus = '';
  double _overallProgress = 0.0;
  final List<_AgentStep> _completedSteps = [];

  final List<Map<String, dynamic>> _scenarios = [
    {
      'key': 'islamabad_flood',
      'label': '🌊 Islamabad Flooding',
      'text': 'G-10 mein pani bhar gaya hai, gaariyan phans gayi hain aur logon ke ghar zabardast baarish ki wajah se doob rahe hain. Rescue ki zaroorat hai!',
      'source': 'citizen_report',
      'location': 'G-10, Islamabad',
    },
    {
      'key': 'karachi_heatwave',
      'label': '🌡️ Karachi Heatwave',
      'text': 'Severe heatwave warning for Karachi. Temperature reaching 48°C. Multiple heat stroke cases reported near Saddar area. Hospitals running out of beds.',
      'source': 'weather_api',
      'location': 'Saddar, Karachi',
    },
    {
      'key': 'lahore_accident',
      'label': '🚗 Lahore Accident',
      'text': 'Bada accident hua hai Shahrah-e-Quaid-e-Azam pe. Teen gaariyan takra gayi hain, road completely block hai. Ambulance aur traffic police chahiye.',
      'source': 'social_media',
      'location': 'Shahrah-e-Quaid-e-Azam, Lahore',
    },
    {
      'key': 'quetta_earthquake',
      'label': '🏚️ Quetta Earthquake',
      'text': 'Earthquake felt in Quetta, magnitude approximately 5.2. Buildings cracked in Satellite Town area. People running out of homes. Need immediate rescue.',
      'source': 'news_agency',
      'location': 'Satellite Town, Quetta',
    },
  ];

  final List<String> _sources = ['citizen_report', 'weather_api', 'traffic_api', 'social_media', 'news_agency'];

  @override
  void initState() {
    super.initState();
    _loadingController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
  }

  @override
  void dispose() {
    _textController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  Future<void> _runAnalysis() async {
    if (_textController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter a crisis report or load a sample scenario.');
      return;
    }
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
        text: _textController.text.trim(),
        source: _selectedSource,
        onProgress: (agentIndex, agentName, status, progress) {
          if (mounted) {
            setState(() {
              _currentAgentIndex = agentIndex;
              _currentAgentName = agentName;
              _currentAgentStatus = status;
              _overallProgress = progress;
              // Track completed agents
              if (status == 'Complete ✓' && !_completedSteps.any((s) => s.index == agentIndex)) {
                _completedSteps.add(_AgentStep(index: agentIndex, name: agentName));
              }
            });
          }
        },
      );
      widget.onAnalysisComplete(result);
    } catch (e) {
      setState(() => _errorMessage = 'Analysis failed: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.midnight,
      appBar: AppBar(
        title: const Text('Crisis Input'),
        backgroundColor: AppTheme.deepNavy,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: ApiService.useMockData
                  ? AppTheme.alertOrange.withOpacity(0.15)
                  : AppTheme.successGreen.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: ApiService.useMockData
                    ? AppTheme.alertOrange.withOpacity(0.4)
                    : AppTheme.successGreen.withOpacity(0.4),
              ),
            ),
            child: GestureDetector(
              onTap: () => setState(() => ApiService.useMockData = !ApiService.useMockData),
              child: Text(
                ApiService.useMockData ? 'DEMO MODE' : 'LIVE MODE',
                style: TextStyle(
                  color: ApiService.useMockData ? AppTheme.alertOrange : AppTheme.successGreen,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.navyBorder),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FadeInDown(child: _buildInputHeader()),
                const SizedBox(height: 20),
                FadeInUp(delay: const Duration(milliseconds: 100), child: _buildTextInput()),
                const SizedBox(height: 16),
                FadeInUp(delay: const Duration(milliseconds: 150), child: _buildSourceSelector()),
                const SizedBox(height: 24),
                FadeInUp(delay: const Duration(milliseconds: 200), child: _buildScenarioLoader()),
                const SizedBox(height: 24),
                if (_errorMessage != null) FadeIn(child: _buildError()),
                FadeInUp(delay: const Duration(milliseconds: 250), child: _buildAnalyzeButton()),
                const SizedBox(height: 80),
              ],
            ),
          ),
          if (_isAnalyzing) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildInputHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: AppTheme.radiusMd,
        border: Border.all(color: AppTheme.navyBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(gradient: AppTheme.blueGradient, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.hub_outlined, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Antigravity Intake', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                Text('Enter report in English, Urdu, or Roman Urdu', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Crisis Report', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.navyCard,
            borderRadius: AppTheme.radiusMd,
            border: Border.all(color: AppTheme.navyBorder),
          ),
          child: TextField(
            controller: _textController,
            maxLines: 6,
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'G-10 mein pani bhar gaya hai...\nor: Flood alert in G-10 Islamabad\nیا: اسلام آباد میں سیلاب',
              hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSourceSelector() {
    final sourceIcons = {
      'citizen_report': Icons.person,
      'weather_api': Icons.cloud,
      'traffic_api': Icons.traffic,
      'social_media': Icons.share,
      'news_agency': Icons.newspaper,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Signal Source', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _sources.map((s) {
            final selected = _selectedSource == s;
            return GestureDetector(
              onTap: () => setState(() => _selectedSource = s),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.electricBlue.withOpacity(0.15) : AppTheme.navyCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: selected ? AppTheme.electricBlue : AppTheme.navyBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(sourceIcons[s] ?? Icons.input, color: selected ? AppTheme.electricBlue : AppTheme.textMuted, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      s.replaceAll('_', ' '),
                      style: TextStyle(color: selected ? AppTheme.electricBlue : AppTheme.textSecondary, fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildScenarioLoader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Load Demo Scenario', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.cyanAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${_scenarios.length} scenarios', style: TextStyle(color: AppTheme.cyanAccent, fontSize: 10)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ..._scenarios.map((s) => GestureDetector(
          onTap: () {
            _textController.text = s['text'] as String;
            setState(() => _selectedSource = s['source'] as String);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: AppTheme.cardGradient,
              borderRadius: AppTheme.radiusMd,
              border: Border.all(color: AppTheme.navyBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s['label'] as String, style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(s['location'] as String, style: TextStyle(color: AppTheme.cyanAccent, fontSize: 11)),
                      const SizedBox(height: 2),
                      Text(s['text'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppTheme.electricBlue.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.upload_rounded, color: AppTheme.electricBlue, size: 16),
                ),
              ],
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildError() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppTheme.alertRed.withOpacity(0.1), borderRadius: AppTheme.radiusMd, border: Border.all(color: AppTheme.alertRed.withOpacity(0.3))),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.alertRed, size: 16),
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

  Widget _buildAnalyzeButton() {
    return GestureDetector(
      onTap: _isAnalyzing ? null : _runAnalysis,
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
            const Icon(Icons.analytics_outlined, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Text('Run Antigravity Analysis', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
              child: Text('6 Agents', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    final agentNames = [
      'Signal Ingestion',
      'Verification',
      'Severity Analysis',
      'Response Planning',
      'Execution Simulation',
      'Fallback & Recovery',
    ];

    return Container(
      color: AppTheme.midnight.withOpacity(0.95),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated spinner with agent index
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
                        child: Text(
                          '$_currentAgentIndex/6',
                          style: TextStyle(color: AppTheme.electricBlue, fontSize: 20, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              Text('Antigravity Orchestration', style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                _currentAgentName.isNotEmpty ? _currentAgentName : 'Initializing pipeline...',
                style: TextStyle(color: AppTheme.electricBlue, fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                _currentAgentStatus,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),

              const SizedBox(height: 20),

              // Progress bar
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.navyBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
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

              // Agent steps with real-time status
              ...agentNames.asMap().entries.map((e) {
                final i = e.key;
                final agentName = e.value;
                final isCompleted = _completedSteps.any((s) => s.index == i + 1);
                final isActive = _currentAgentIndex == i + 1 && !isCompleted;
                final isPending = _currentAgentIndex < i + 1;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        child: isCompleted
                            ? const Icon(Icons.check_circle, color: AppTheme.successGreen, size: 16)
                            : isActive
                                ? SizedBox(
                                    width: 14, height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.electricBlue,
                                    ),
                                  )
                                : Icon(Icons.radio_button_unchecked, color: AppTheme.textMuted, size: 14),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Agent ${i + 1}: $agentName',
                        style: TextStyle(
                          color: isCompleted
                              ? AppTheme.successGreen
                              : isActive
                                  ? AppTheme.textPrimary
                                  : AppTheme.textMuted,
                          fontSize: 12,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      if (isActive && _currentAgentStatus.isNotEmpty) ...[
                        const Spacer(),
                        Text(
                          _currentAgentStatus,
                          style: TextStyle(color: AppTheme.cyanAccent, fontSize: 10),
                        ),
                      ],
                    ],
                  ),
                );
              }),

              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Powered by ', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                  Text('Google Antigravity', style: TextStyle(color: AppTheme.electricBlue, fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
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
