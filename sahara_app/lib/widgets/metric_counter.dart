import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Animated counter widget — animates from 0 to target value.
/// Great for outcome/metrics screens.
class MetricCounter extends StatefulWidget {
  final int targetValue;
  final String label;
  final Color color;
  final IconData icon;
  final String? suffix;
  final Duration duration;
  final double valueFontSize;

  const MetricCounter({
    super.key,
    required this.targetValue,
    required this.label,
    required this.color,
    required this.icon,
    this.suffix,
    this.duration = const Duration(milliseconds: 1200),
    this.valueFontSize = 20,
  });

  @override
  State<MetricCounter> createState() => _MetricCounterState();
}

class _MetricCounterState extends State<MetricCounter> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void didUpdateWidget(MetricCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetValue != widget.targetValue) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final currentValue = (_animation.value * widget.targetValue).toInt();
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: AppTheme.cardGradient,
            borderRadius: AppTheme.radiusMd,
            border: Border.all(color: AppTheme.navyBorder),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.icon, color: widget.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${_formatNumber(currentValue)}${widget.suffix ?? ''}',
                      style: GoogleFonts.outfit(
                        color: widget.color,
                        fontSize: widget.valueFontSize,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      widget.label,
                      style: GoogleFonts.outfit(
                        color: AppTheme.textMuted,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
