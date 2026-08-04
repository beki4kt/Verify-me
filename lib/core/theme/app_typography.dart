import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Typography system. Uses Inter (via google_fonts) with:
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

  /// App-bar title style.
  static TextStyle appBarTitle() => GoogleFonts.inter(
        fontWeight: FontWeight.w800,
        fontSize: 16,
        letterSpacing: -0.1,
        color: AppColors.textPrimary,
      );

  /// Money / amount text with tabular figures so columns align.
  static TextStyle money({
    double size = 18,
    FontWeight weight = FontWeight.w800,
    Color color = AppColors.textPrimary,
  }) =>
      GoogleFonts.inter(
        fontWeight: weight,
        fontSize: size,
        letterSpacing: -0.2,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// Uppercase micro-label (e.g. "PENDING", "REF").
  static TextStyle microLabel({Color color = AppColors.textMuted}) =>
      GoogleFonts.inter(
        fontWeight: FontWeight.w700,
        fontSize: 10,
        letterSpacing: 1.2,
        color: color,
      );

  /// Bank tag label (uppercase, bold).
  static TextStyle bankTag({Color color = AppColors.textMuted}) =>
      GoogleFonts.inter(
        fontWeight: FontWeight.w900,
        fontSize: 10,
        letterSpacing: 1,
        color: color,
      );
}
