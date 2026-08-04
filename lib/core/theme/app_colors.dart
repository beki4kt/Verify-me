import 'package:flutter/material.dart';

/// Single source of truth for the Verify-me brand palette + a tonal dark
/// surface ramp. Surfaces are hand-tuned (designer ramp) rather than
/// `ColorScheme.fromSeed`, so they stay `const`-usable in widget defaults.
class AppColors {
  AppColors._();

  // ── Brand accents (fixed) ──
  static const Color primary = Color(0xFF6366F1); // indigo
  static const Color primarySoft = Color(0xFF818CF8);
  static const Color violet = Color(0xFF8B5CF6);
  static const Color success = Color(0xFF10B981); // emerald
  static const Color warning = Color(0xFFF59E0B); // amber
  static const Color danger  = Color(0xFFEF4444);  // red

  // ── Tonal dark surface ramp ──
  static const Color bg                  = Color(0xFF0B1120); // scaffold base
  static const Color surface             = Color(0xFF111827);
  static const Color surfaceLow          = Color(0xFF0E1322);
  static const Color surfaceContainer   = Color(0xFF1A2336);
  static const Color surfaceContainerHigh = Color(0xFF222C42);
  static const Color surfaceHighest      = Color(0xFF2A3650);
  static const Color surfaceContainerLowest = Color(0xFF080D17);

  // 1px top highlight used on cards/sheets for "elevation" in dark mode.
  static const Color hairline        = Color(0x1FFFFFFF); // white @ 6%
  static const Color hairlineStrong  = Color(0x26FFFFFF); // white @ 15%
  static const Color topHighlight    = Color(0x0FFFFFFF); // white @ 6%

  // ── Text ──
  static const Color textPrimary   = Colors.white;
  static const Color textSecondary = Color(0xFFCBD5E1);
  static const Color textMuted     = Color(0xFF94A3B8);
  static const Color textFaint     = Color(0xFF64748B);

  // ── Bank brand accents ──
  static const Color telebirr = Color(0xFF0EA5E9);
  static const Color cbe      = Color(0xFFA855F7);
  static const Color dashen   = Color(0xFFF59E0B);

  /// Resolves the accent color for a bank name (case-insensitive, partial match).
  static Color bank(String? bank) {
    final b = (bank ?? '').toLowerCase();
    if (b.contains('telebirr')) return telebirr;
    if (b.contains('cbe')) return cbe;
    if (b.contains('dashen')) return dashen;
    return textMuted;
  }
}
