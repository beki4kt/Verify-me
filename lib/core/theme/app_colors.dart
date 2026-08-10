import 'package:flutter/material.dart';

/// CHEKMI's premium hospitality-fintech palette.
///
/// Cobalt carries trust, jade communicates successful payment, and the warm
/// tangerine accent keeps the product human. The light palette uses warm
/// porcelain instead of pure white; the dark palette uses blue-black rather
/// than flat black so translucent surfaces retain depth.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF5968F2);
  static const Color primaryDeep = Color(0xFF3E4ACB);
  static const Color primarySoft = Color(0xFF9DA7FF);
  static const Color violet = Color(0xFF8A63E8);
  static const Color brandBlue = Color(0xFF2474D8);
  static const Color brandOrange = Color(0xFFFF9858);
  static const Color success = Color(0xFF18A979);
  static const Color warning = Color(0xFFF1A33C);
  static const Color danger = Color(0xFFE75565);

  // Night palette.
  static const Color bg = Color(0xFF07101D);
  static const Color surface = Color(0xFF101B2B);
  static const Color surfaceLow = Color(0xFF0B1523);
  static const Color surfaceContainer = Color(0xFF152237);
  static const Color surfaceContainerHigh = Color(0xFF1B2B43);
  static const Color surfaceHighest = Color(0xFF263A57);
  static const Color surfaceContainerLowest = Color(0xFF050B14);
  static const Color glass = Color(0xD9162439);

  // Day palette. Warm neutrals prevent the washed-out "white sheet" look.
  static const Color lightBg = Color(0xFFF2F3F8);
  static const Color lightSurface = Color(0xFFFFFDF9);
  static const Color lightSurfaceLow = Color(0xFFF7F5F1);
  static const Color lightSurfaceContainer = Color(0xFFFBFAF7);
  static const Color lightSurfaceHigh = Color(0xFFE9ECF4);
  static const Color lightSurfaceHighest = Color(0xFFDCE1ED);
  static const Color lightInk = Color(0xFF172033);
  static const Color lightInkSecondary = Color(0xFF49556B);
  static const Color lightInkMuted = Color(0xFF6F7A8E);

  static const Color hairline = Color(0x1FFFFFFF);
  static const Color hairlineStrong = Color(0x30FFFFFF);
  static const Color topHighlight = Color(0x24FFFFFF);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFD7E0ED);
  static const Color textMuted = Color(0xFFA2AEC0);
  static const Color textFaint = Color(0xFF718097);
  static const Color textDisabled = Color(0xFF536177);

  static const Color telebirr = Color(0xFF2D9CDB);
  static const Color cbe = Color(0xFF9966E8);
  static const Color dashen = Color(0xFFF1A33C);

  static Color bank(String? bank) {
    final value = (bank ?? '').toLowerCase();
    if (value.contains('telebirr')) return telebirr;
    if (value.contains('cbe')) return cbe;
    if (value.contains('dashen')) return dashen;
    return textMuted;
  }
}
