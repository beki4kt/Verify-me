import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_shapes.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// App-wide [ThemeData]. Design-system v2: tonal dark surfaces, Inter
/// typography with tabular figures, continuous (squircle) corners.
class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.success,
        surface: AppColors.surface,
        surfaceContainerLowest: AppColors.surfaceContainerLowest,
        surfaceContainerLow: AppColors.surfaceLow,
        surfaceContainer: AppColors.surfaceContainer,
        surfaceContainerHigh: AppColors.surfaceContainerHigh,
        surfaceContainerHighest: AppColors.surfaceHighest,
        error: AppColors.danger,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.white,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.white,
        centerTitle: false,
        titleTextStyle: AppTypography.appBarTitle(),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceContainerHigh,
        modalBackgroundColor: AppColors.surfaceContainerHigh,
        shape: AppShapes.sheet,
      ),
      tabBarTheme: const TabBarThemeData(
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textMuted,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.hairline, thickness: 1, space: 1),
      iconTheme: const IconThemeData(color: AppColors.primary),
      textTheme: AppTypography.darkTextTheme(),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: AppTypography.microLabel(),
        hintStyle: AppTypography.microLabel(color: AppColors.textFaint),
        filled: true,
        fillColor: AppColors.surfaceLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: AppShapes.button,
          textStyle: AppTypography.microLabel(color: Colors.white).copyWith(fontSize: 14),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceContainerHigh,
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        shape: const ContinuousRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppSpacing.radius)),
        ),
      ),
    );
  }
}
