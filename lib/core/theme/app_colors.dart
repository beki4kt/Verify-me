import 'package:flutter/material.dart';

/// CHEKMI's hospitality-fintech palette.
///
/// Near-black graphite is the foundation. Violet and cyan are reserved for
/// meaning, focus, and ambient light instead of being used as surface colors.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF8B5CF6);
  static const Color primaryDeep = Color(0xFF6D28D9);
  static const Color primarySoft = Color(0xFFC4B5FD);
  static const Color violet = Color(0xFF7C3AED);
  static const Color brandBlue = Color(0xFF22D3EE);
  static const Color brandOrange = Color(0xFFFB7185);
  static const Color success = Color(0xFF34D399);
  static const Color warning = Color(0xFFFBBF24);
  static const Color danger = Color(0xFFFB7185);
  static const Color aqua = Color(0xFF22D3EE);
  static const Color pink = Color(0xFFA78BFA);
  static const Color citrus = Color(0xFFBEF264);

  // Night palette.
  static const Color bg = Color(0xFF08090B);
  static const Color surface = Color(0xFF0E1015);
  static const Color surfaceLow = Color(0xFF0B0D12);
  static const Color surfaceContainer = Color(0xFF131620);
  static const Color surfaceContainerHigh = Color(0xFF1A1E2B);
  static const Color surfaceHighest = Color(0xFF242938);
  static const Color surfaceContainerLowest = Color(0xFF050607);
  static const Color glass = Color(0x8A11141C);

  // Day palette. Warm neutrals prevent the washed-out "white sheet" look.
  static const Color lightBg = Color(0xFFFFF3F7);
  static const Color lightSurface = Color(0xFFFFFBFD);
  static const Color lightSurfaceLow = Color(0xFFFFF6FA);
  static const Color lightSurfaceContainer = Color(0xFFFFFAFC);
  static const Color lightSurfaceHigh = Color(0xFFF3E8F2);
  static const Color lightSurfaceHighest = Color(0xFFE7D8E6);
  static const Color lightInk = Color(0xFF30202F);
  static const Color lightInkSecondary = Color(0xFF624E60);
  static const Color lightInkMuted = Color(0xFF806A7D);

  static const Color hairline = Color(0x1FFFFFFF);
  static const Color hairlineStrong = Color(0x30FFFFFF);
  static const Color topHighlight = Color(0x24FFFFFF);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFD8DCE7);
  static const Color textMuted = Color(0xFFA6ADBD);
  static const Color textFaint = Color(0xFF737B8E);
  static const Color textDisabled = Color(0xFF555D70);

  static const Color telebirr = Color(0xFF21C7D9);
  static const Color cbe = Color(0xFFA45BEC);
  static const Color dashen = Color(0xFFF1A33C);

  static Color bank(String? bank) {
    final value = (bank ?? '').toLowerCase();
    if (value.contains('telebirr')) return telebirr;
    if (value.contains('cbe')) return cbe;
    if (value.contains('dashen')) return dashen;
    return textMuted;
  }
}
