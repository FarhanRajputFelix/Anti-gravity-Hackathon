import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Reusable expandable agent card with timeline dot indicator.
/// Used in the Agent Trace screen.
class AgentCard extends StatelessWidget {
  final int index;
  final String agentName;
  final int agentIndex;
  final String decision;
  final double confidence;
  final int executionTimeMs;
  final bool isFallback;
  final bool isExpanded;
  final List<String> observations;
  final List<String> reasoningSteps;
  final List<Map<String, dynamic>> toolCalls;
  final VoidCallback onToggle;
  final bool isLast;

  const AgentCard({
    super.key,
    required this.index,
    required this.agentName,
    required this.agentIndex,
    required this.decision,
    required this.confidence,
    required this.executionTimeMs,
    required this.isFallback,
    required this.isExpanded,
    required this.observations,
    required this.reasoningSteps,
    required this.toolCalls,
    required this.onToggle,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final agentColor = isFallback ? AppTheme.alertOrange : AppTheme.electricBlue;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline column
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isFallback
                      ? [AppTheme.alertOrange, const Color(0xFFCC5A00)]
                      : [AppTheme.electricBlue, const Color(0xFF0D50CC)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: agentColor.withValues(alpha: 0.35),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '$agentIndex',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (!isLast)
              Container(width: 2, height: 20, color: AppTheme.navyBorder),
          ],
        ),
        const SizedBox(width: 12),
        // Card body
        Expanded(
          child: GestureDetector(
            onTap: onToggle,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                gradient: AppTheme.cardGradient,
                borderRadius: AppTheme.radiusMd,
                border: Border.all(
                  color: isFallback
                      ? AppTheme.alertOrange.withValues(alpha: 0.3)
                      : AppTheme.navyBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(agentColor),
                  if (isExpanded) _buildBody(agentColor),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(Color agentColor) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  agentName,
                  style: GoogleFonts.outfit(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isFallback)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.alertOrange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: AppTheme.alertOrange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'FALLBACK',
                    style: GoogleFonts.outfit(
                      color: AppTheme.alertOrange,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              Icon(
                isExpanded ? Icons.expand_less : Icons.expand_more,
                color: AppTheme.textMuted,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            decision,
            style: GoogleFonts.outfit(color: AppTheme.textSecondary, fontSize: 11),
            maxLines: isExpanded ? 5 : 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildPill(
                '${(confidence * 100).toStringAsFixed(0)}%',
                Icons.verified_outlined,
                agentColor,
              ),
              const SizedBox(width: 8),
              _buildPill(
                '${executionTimeMs}ms',
                Icons.timer_outlined,
                AppTheme.textMuted,
              ),
              const SizedBox(width: 8),
              _buildPill(
                '${toolCalls.length} calls',
                Icons.api_outlined,
                AppTheme.cyanAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPill(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 10),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.outfit(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(Color agentColor) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.navyBorder)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSection('Observations', observations, Icons.remove_red_eye_outlined, AppTheme.glowBlue),
          const SizedBox(height: 12),
          _buildSection('Reasoning Steps', reasoningSteps, Icons.psychology_outlined, AppTheme.cyanAccent),
          const SizedBox(height: 12),
          _buildToolCallsList(),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<String> items, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Text(
              title,
              style: GoogleFonts.outfit(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 5),
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: GoogleFonts.outfit(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolCallsList() {
    if (toolCalls.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.api_outlined, color: AppTheme.cyanAccent, size: 14),
            const SizedBox(width: 6),
            Text(
              'Tool / API Calls',
              style: GoogleFonts.outfit(
                color: AppTheme.cyanAccent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...toolCalls.map(
          (tool) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppTheme.cyanAccent.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.cyanAccent.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.code, color: AppTheme.cyanAccent, size: 12),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tool['tool_name'] ?? '',
                    style: GoogleFonts.outfit(
                      color: AppTheme.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  '${tool['latency_ms']}ms',
                  style: GoogleFonts.outfit(color: AppTheme.textMuted, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
