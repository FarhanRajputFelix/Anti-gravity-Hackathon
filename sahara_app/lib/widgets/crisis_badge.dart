import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Severity badge widget — displays crisis severity level with color coding.
class CrisisBadge extends StatelessWidget {
  final String severity;
  final double fontSize;
  final EdgeInsets padding;

  const CrisisBadge({
    super.key,
    required this.severity,
    this.fontSize = 11,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.severityColor(severity);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        severity.toUpperCase(),
        style: GoogleFonts.outfit(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Crisis type badge with icon.
class CrisisTypeBadge extends StatelessWidget {
  final String crisisType;
  final String location;
  final String severity;

  const CrisisTypeBadge({
    super.key,
    required this.crisisType,
    required this.location,
    required this.severity,
  });

  static IconData _crisisIcon(String type) {
    switch (type.toUpperCase()) {
      case 'FLOODING':
        return Icons.water;
      case 'HEATWAVE':
        return Icons.thermostat;
      case 'TRAFFIC_ACCIDENT':
        return Icons.car_crash;
      case 'INFRASTRUCTURE_FAILURE':
        return Icons.domain_disabled;
      case 'FIRE':
        return Icons.local_fire_department;
      default:
        return Icons.warning_amber_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.severityColor(severity);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.12), AppTheme.navyCard],
        ),
        borderRadius: AppTheme.radiusMd,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_crisisIcon(crisisType), color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  crisisType.replaceAll('_', ' '),
                  style: GoogleFonts.outfit(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  location,
                  style: GoogleFonts.outfit(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          CrisisBadge(severity: severity),
        ],
      ),
    );
  }
}
