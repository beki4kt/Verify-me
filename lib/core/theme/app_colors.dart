import 'package:flutter/material.dart';

/// CHEKMI's premium hospitality-fintech palette.
///
/// The palette is derived from the supplied glass-morphism reference: vivid
/// orchid, aqua, coral, and citrus color fields over neutral plum/graphite.
/// There is deliberately no navy or blue-black foundation.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFFC64CFF);
  static const Color primaryDeep = Color(0xFF8E2FC6);
  static const Color primarySoft = Color(0xFFE3A7FF);
  static const Color violet = Color(0xFF9B5CFF);
  static const Color brandBlue = Color(0xFF21D4C2);
  static const Color brandOrange = Color(0xFFFF7D66);
  static const Color success = Color(0xFF15B98F);
  static const Color warning = Color(0xFFF5A623);
  static const Color danger = Color(0xFFF04F78);
  static const Color aqua = Color(0xFF35D8E8);
  static const Color pink = Color(0xFFFF4FB8);
  static const Color citrus = Color(0xFFD7ED59);

  // Night palette.
  static const Color bg = Color(0xFF171018);
  static const Color surface = Color(0xFF241A25);
  static const Color surfaceLow = Color(0xFF1D151E);
  static const Color surfaceContainer = Color(0xFF2B202D);
  static const Color surfaceContainerHigh = Color(0xFF352739);
  static const Color surfaceHighest = Color(0xFF49364B);
  static const Color surfaceContainerLowest = Color(0xFF100B11);
  static const Color glass = Color(0x662F2332);

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
  static const Color textSecondary = Color(0xFFF1DFEE);
  static const Color textMuted = Color(0xFFC7AECA);
  static const Color textFaint = Color(0xFF9E879D);
  static const Color textDisabled = Color(0xFF745F73);

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
