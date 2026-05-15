import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Full-screen animated loading overlay during Antigravity reasoning.
class LoadingOverlay extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<String> steps;
  final bool visible;

  const LoadingOverlay({
    super.key,
    this.title = 'Antigravity Reasoning...',
    this.subtitle = '6 agents analyzing crisis signal',
    this.steps = const [
      'Signal Ingestion',
      'Verification',
      'Severity Analysis',
      'Response Planning',
      'Simulation',
      'Fallback Check',
    ],
    this.visible = true,
  });

  @override
  State<LoadingOverlay> createState() => _LoadingOverlayState();
}

class _LoadingOverlayState extends State<LoadingOverlay>
    with TickerProviderStateMixin {
  late AnimationController _spinController;
  late AnimationController _stepsController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _stepsController = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.steps.length),
    )..repeat();
  }

  @override
  void dispose() {
    _spinController.dispose();
    _stepsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();

    return Container(
      color: AppTheme.midnight.withValues(alpha: 0.92),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Spinning orb
            SizedBox(
              width: 80,
              height: 80,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _spinController,
                    builder: (_, __) => Transform.rotate(
                      angle: _spinController.value * 6.28,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(
                            colors: [
                              AppTheme.electricBlue,
                              AppTheme.electricBlue.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 65,
                    height: 65,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.midnight,
                    ),
                    child: const Icon(
                      Icons.hub_outlined,
                      color: AppTheme.electricBlue,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.title,
              style: GoogleFonts.outfit(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.subtitle,
              style: GoogleFonts.outfit(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            // Animated step indicators
            AnimatedBuilder(
              animation: _stepsController,
              builder: (_, __) {
                final progress = _stepsController.value * widget.steps.length;
                return Column(
                  children: widget.steps.asMap().entries.map((entry) {
                    final isActive = entry.key <= progress;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isActive
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: isActive
                                ? AppTheme.successGreen
                                : AppTheme.textMuted,
                            size: 14,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            entry.value,
                            style: GoogleFonts.outfit(
                              color: isActive
                                  ? AppTheme.textPrimary
                                  : AppTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
