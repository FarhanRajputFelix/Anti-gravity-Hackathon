import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/crisis_input_screen.dart';
import 'screens/agent_trace_screen.dart';
import 'screens/map_screen.dart';
import 'screens/outcome_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppTheme.deepNavy,
  ));
  runApp(const SaharaApp());
}

class SaharaApp extends StatelessWidget {
  const SaharaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SAHARA AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  Map<String, dynamic>? _analysisResult;

  void _onAnalysisComplete(Map<String, dynamic> result) {
    setState(() {
      _analysisResult = result;
      _currentIndex = 2; // Go to Agent Trace screen
    });
  }

  void _navigateTo(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onNavigate: _navigateTo),
      CrisisInputScreen(onAnalysisComplete: _onAnalysisComplete),
      AgentTraceScreen(analysisResult: _analysisResult),
      MapScreen(analysisResult: _analysisResult),
      OutcomeScreen(analysisResult: _analysisResult),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    final items = [
      {'icon': Icons.home_outlined, 'active': Icons.home, 'label': 'Dashboard'},
      {'icon': Icons.add_alert_outlined, 'active': Icons.add_alert, 'label': 'Input'},
      {'icon': Icons.hub_outlined, 'active': Icons.hub, 'label': 'Agents'},
      {'icon': Icons.map_outlined, 'active': Icons.map, 'label': 'Map'},
      {'icon': Icons.bar_chart_outlined, 'active': Icons.bar_chart, 'label': 'Outcome'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.deepNavy,
        border: const Border(top: BorderSide(color: AppTheme.navyBorder, width: 1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: items.asMap().entries.map((e) {
              final i = e.key;
              final item = e.value;
              final isActive = _currentIndex == i;
              final hasResult = _analysisResult != null;

              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _currentIndex = i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isActive ? AppTheme.electricBlue.withOpacity(0.15) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isActive ? item['active'] as IconData : item['icon'] as IconData,
                              color: isActive ? AppTheme.electricBlue : AppTheme.textMuted,
                              size: 22,
                            ),
                          ),
                          // Badge for Agent & Outcome screens when result available
                          if (hasResult && (i == 2 || i == 4))
                            Positioned(
                              top: -2, right: -2,
                              child: Container(
                                width: 8, height: 8,
                                decoration: const BoxDecoration(color: AppTheme.successGreen, shape: BoxShape.circle),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item['label'] as String,
                        style: TextStyle(
                          color: isActive ? AppTheme.electricBlue : AppTheme.textMuted,
                          fontSize: 10,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
