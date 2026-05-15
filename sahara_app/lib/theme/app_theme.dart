import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Core Color Palette ─────────────────────────
  static const Color midnight = Color(0xFF050E1F);
  static const Color deepNavy = Color(0xFF0A1628);
  static const Color navyCard = Color(0xFF0D1F3C);
  static const Color navyBorder = Color(0xFF1A3050);

  static const Color electricBlue = Color(0xFF1E6FFF);
  static const Color glowBlue = Color(0xFF4D9FFF);
  static const Color cyanAccent = Color(0xFF00D4FF);

  static const Color alertRed = Color(0xFFFF3B3B);
  static const Color alertOrange = Color(0xFFFF7A00);
  static const Color alertYellow = Color(0xFFFFD600);
  static const Color successGreen = Color(0xFF00E676);

  static const Color textPrimary = Color(0xFFF0F6FF);
  static const Color textSecondary = Color(0xFF8BA5CC);
  static const Color textMuted = Color(0xFF4A6080);

  static const Color glassBg = Color(0x1A1E6FFF);
  static const Color glassStroke = Color(0x331E6FFF);

  // ── Severity Colors ─────────────────────────────
  static const Color severityCritical = Color(0xFFFF3B3B);
  static const Color severityHigh = Color(0xFFFF7A00);
  static const Color severityMedium = Color(0xFFFFD600);
  static const Color severityLow = Color(0xFF00E676);

  static Color severityColor(String level) {
    switch (level.toUpperCase()) {
      case 'CRITICAL': return severityCritical;
      case 'HIGH': return severityHigh;
      case 'MEDIUM': return severityMedium;
      case 'LOW': return severityLow;
      default: return glowBlue;
    }
  }

  // ── Gradients ────────────────────────────────────
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [midnight, Color(0xFF071428), Color(0xFF050E1F)],
  );

  static const LinearGradient blueGradient = LinearGradient(
    colors: [electricBlue, Color(0xFF0D50CC)],
  );

  static const LinearGradient alertGradient = LinearGradient(
    colors: [alertRed, Color(0xFFCC1A1A)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navyCard, Color(0xFF102035)],
  );

  // ── Border Radius ────────────────────────────────
  static final BorderRadius radiusMd = BorderRadius.circular(12);
  static final BorderRadius radiusLg = BorderRadius.circular(16);
  static final BorderRadius radiusXl = BorderRadius.circular(24);

  // ── ThemeData ────────────────────────────────────
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: midnight,
      colorScheme: const ColorScheme.dark(
        primary: electricBlue,
        secondary: cyanAccent,
        surface: navyCard,
        error: alertRed,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: textPrimary, fontSize: 32, fontWeight: FontWeight.bold, fontFamily: 'Roboto'),
        displayMedium: TextStyle(color: textPrimary, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Roboto'),
        titleLarge: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w600, fontFamily: 'Roboto'),
        titleMedium: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'Roboto'),
        bodyLarge: TextStyle(color: textPrimary, fontSize: 15, fontFamily: 'Roboto'),
        bodyMedium: TextStyle(color: textSecondary, fontSize: 13, fontFamily: 'Roboto'),
        labelSmall: TextStyle(color: textMuted, fontSize: 11, letterSpacing: 0.8, fontFamily: 'Roboto'),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: deepNavy,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          fontFamily: 'Roboto',
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: deepNavy,
        selectedItemColor: electricBlue,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: electricBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Roboto'),
        ),
      ),
    );
  }
}
