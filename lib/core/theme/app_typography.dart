import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_variant.dart';
import 'app_colors.dart';

/// Typography system. Manrope gives CHEKMI a warmer, more distinctive voice
/// than a default dashboard font while staying highly legible for amounts.
///  • negative letter-spacing on large headings (modern SaaS look)
///  • tabular figures everywhere money is displayed (so ledger columns align)
///  • lighter weight on uppercase micro-labels (less heavy than w900/1.5)
class AppTypography {
  AppTypography._();

  /// A full dark-mode [TextTheme] in Inter, with refined display/body styles.
  static TextTheme darkTextTheme() {
    final base = GoogleFonts.interTextTheme(Typography().white);
    return base.copyWith(
      // Big revenue / metric numbers.
      displayLarge: GoogleFonts.inter(
        fontWeight: FontWeight.w700,
        fontSize: 34,
        letterSpacing: -0.5,
        color: AppColors.textPrimary,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      displayMedium: GoogleFonts.inter(
        fontWeight: FontWeight.w700,
        fontSize: 28,
        letterSpacing: -0.4,
        color: AppColors.textPrimary,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      // Screen titles ("CASHIER DESK", etc.)
      titleLarge: GoogleFonts.inter(
        fontWeight: FontWeight.w800,
        fontSize: 18,
        letterSpacing: -0.2,
        color: AppColors.textPrimary,
      ),
      // Section labels (kept uppercase by callers).
      titleMedium: GoogleFonts.inter(
        fontWeight: FontWeight.w800,
        fontSize: 16,
        color: AppColors.textPrimary,
      ),
      labelLarge: GoogleFonts.inter(
        fontWeight: FontWeight.w600,
        fontSize: 11,
        letterSpacing: 1.2,
        color: AppColors.textMuted,
      ),
      bodyLarge: GoogleFonts.inter(
        fontWeight: FontWeight.w600,
        fontSize: 16,
        color: AppColors.textPrimary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontWeight: FontWeight.w500,
        fontSize: 14,
        color: AppColors.textSecondary,
      ),
      bodySmall: GoogleFonts.inter(
        fontWeight: FontWeight.w600,
        fontSize: 12,
        color: AppColors.textMuted,
      ),
    );
  }

  static TextTheme lightTextTheme() {
    final base = darkTextTheme();
    return base.apply(
      bodyColor: AppColors.lightInkSecondary,
      displayColor: AppColors.lightInk,
    );
  }

  /// App-bar title style.
  static TextStyle appBarTitle({Color? color}) => AppVariant.usesIPhoneUi
      ? _iphoneStyle(
          weight: FontWeight.w700,
          size: 20,
          letterSpacing: -.45,
          color: color,
        )
      : GoogleFonts.inter(
          fontWeight: FontWeight.w800,
          fontSize: 16,
          letterSpacing: -0.1,
          color: color,
        );

  /// Money / amount text with tabular figures so columns align.
  static TextStyle money({
    double size = 18,
    FontWeight weight = FontWeight.w800,
    Color? color,
  }) => AppVariant.usesIPhoneUi
      ? _iphoneStyle(
          weight: weight == FontWeight.w800 || weight == FontWeight.w900
              ? FontWeight.w700
              : weight,
          size: size,
          letterSpacing: -.35,
          color: color,
          tabular: true,
        )
      : GoogleFonts.inter(
          fontWeight: weight,
          fontSize: size,
          letterSpacing: -0.2,
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
        );

  /// Uppercase micro-label (e.g. "PENDING", "REF").
  static TextStyle microLabel({Color? color}) => AppVariant.usesIPhoneUi
      ? _iphoneStyle(weight: FontWeight.w600, size: 12, color: color)
      : GoogleFonts.inter(
          fontWeight: FontWeight.w700,
          fontSize: 10,
          letterSpacing: 1.2,
          color: color,
        );

  /// Bank tag label (uppercase, bold).
  static TextStyle bankTag({Color? color}) => AppVariant.usesIPhoneUi
      ? _iphoneStyle(weight: FontWeight.w700, size: 12, color: color)
      : GoogleFonts.inter(
          fontWeight: FontWeight.w900,
          fontSize: 10,
          letterSpacing: 1,
          color: color,
        );

  static TextStyle _iphoneStyle({
    required FontWeight weight,
    required double size,
    double letterSpacing = 0,
    Color? color,
    bool tabular = false,
  }) => TextStyle(
    fontFamily: '.SF Pro Text',
    fontFamilyFallback: const ['SF Pro Display', 'Helvetica Neue', 'Arial'],
    fontWeight: weight,
    fontSize: size,
    letterSpacing: letterSpacing,
    color: color,
    fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
  );
}
