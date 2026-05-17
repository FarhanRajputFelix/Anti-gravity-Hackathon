/// SAHARA AI — Cinematic Splash Screen
/// 3-second animated intro with shield logo, tagline, and agent initialization.

import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _pulseController;
  late AnimationController _textController;
  late AnimationController _agentController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;
  late Animation<double> _agentOpacity;
  int _agentCount = 0;

  final _agentNames = [
    'Signal Ingestion',
    'Verification',
    'Severity Analysis',
    'Response Planning',
    'Execution Simulation',
    'Fallback & Recovery',
  ];

  @override
  void initState() {
    super.initState();

    // Logo animation
    _logoController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _logoController, curve: Curves.elasticOut));
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _logoController, curve: const Interval(0.0, 0.5, curve: Curves.easeIn)));

    // Pulse glow
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);

    // Text fade
    _textController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _textController, curve: Curves.easeIn));

    // Agent count-up
    _agentController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _agentOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(_agentController);

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _logoController.forward();

    await Future.delayed(const Duration(milliseconds: 900));
    _textController.forward();

    await Future.delayed(const Duration(milliseconds: 600));
    _agentController.forward();

    // Animate agent count-up
    for (int i = 1; i <= 6; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) setState(() => _agentCount = i);
    }

    // Hold for a moment then transition
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) widget.onComplete();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _pulseController.dispose();
    _textController.dispose();
    _agentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.midnight,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 1.2,
            colors: [Color(0xFF0F2847), Color(0xFF070E1A), Color(0xFF040810)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Animated Logo ──
              AnimatedBuilder(
                animation: Listenable.merge([_logoController, _pulseController]),
                builder: (_, __) => Opacity(
                  opacity: _logoOpacity.value,
                  child: Transform.scale(
                    scale: _logoScale.value,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: AppTheme.blueGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.electricBlue.withOpacity(0.3 + _pulseController.value * 0.3),
                            blurRadius: 40 + _pulseController.value * 20,
                            spreadRadius: 5 + _pulseController.value * 10,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.shield_outlined, color: Colors.white, size: 56),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ── Title ──
              AnimatedBuilder(
                animation: _textController,
                builder: (_, __) => Opacity(
                  opacity: _textOpacity.value,
                  child: Column(
                    children: [
                      Text(
                        'SAHARA AI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 4,
                          shadows: [
                            Shadow(color: AppTheme.electricBlue.withOpacity(0.5), blurRadius: 20),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Pakistan's First Agentic Urban Crisis\nResponse Operating System",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          height: 1.5,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // ── Agent Initialization ──
              AnimatedBuilder(
                animation: _agentController,
                builder: (_, __) => Opacity(
                  opacity: _agentOpacity.value,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.electricBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: AppTheme.electricBlue.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _agentCount >= 6 ? AppTheme.successGreen : AppTheme.electricBlue,
                                value: _agentCount >= 6 ? 1.0 : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _agentCount >= 6
                                  ? 'Antigravity Engine Ready'
                                  : 'Initializing Agent $_agentCount/6...',
                              style: TextStyle(
                                color: _agentCount >= 6 ? AppTheme.successGreen : AppTheme.electricBlue,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_agentCount > 0) ...[
                        const SizedBox(height: 16),
                        ...List.generate(min(_agentCount, 6), (i) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: AppTheme.successGreen,
                                size: 12,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _agentNames[i],
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 50),

              // ── Powered by ──
              AnimatedBuilder(
                animation: _textController,
                builder: (_, __) => Opacity(
                  opacity: _textOpacity.value * 0.6,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Powered by ', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                      Text('Google Antigravity', style: TextStyle(color: AppTheme.electricBlue, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
