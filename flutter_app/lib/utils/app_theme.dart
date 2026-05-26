import 'package:flutter/material.dart';

class AppTheme {
  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  // ─── Theme Colors ──────────────────────────────────────────────────────────

  static Color scaffoldBg(BuildContext context) =>
      isDark(context) ? const Color(0xFF0D0D1A) : const Color(0xFFF3F4F6);

  static Color cardBg(BuildContext context) =>
      isDark(context) ? const Color(0xFF16162A) : Colors.white;

  static Color activeBg(BuildContext context) =>
      isDark(context) ? const Color(0xFF1E1E38) : const Color(0xFFF3F4F6);

  static Color inputBg(BuildContext context) =>
      isDark(context) ? const Color(0xFF252545) : Colors.white;

  static Color border(BuildContext context) =>
      isDark(context) ? const Color(0xFF2A2A4A) : const Color(0xFFE5E7EB);

  static Color borderPronounced(BuildContext context) =>
      isDark(context) ? const Color(0xFF3A3A5C) : const Color(0xFFD1D5DB);

  static Color textPrimary(BuildContext context) =>
      isDark(context) ? const Color(0xFFE8E6F0) : const Color(0xFF111827);

  static Color textSecondary(BuildContext context) =>
      isDark(context) ? const Color(0xFFA8A6B8) : const Color(0xFF374151);

  static Color textFaint(BuildContext context) =>
      isDark(context) ? const Color(0xFF6B6988) : const Color(0xFF9CA3AF);

  // ─── Core Accent / Brand Colors (consistent across themes) ──────────────────

  static const Color primaryPink = Color(0xFFEC4899);
  static const Color secondaryOrange = Color(0xFFFF6B35);
  static const Color brandPinkAlt = Color(0xFFFF4E8A);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryPink, Color(0xFFDB2777)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient brandGradient = LinearGradient(
    colors: [brandPinkAlt, secondaryOrange],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
