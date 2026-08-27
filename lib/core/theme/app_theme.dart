import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_shapes.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Premium glass-and-skeuomorphic Material 3 themes for CHEKMI.
class AppTheme {
  AppTheme._();

  static ThemeData dark() => _build(Brightness.dark);
  static ThemeData light() => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = dark
        ? const ColorScheme.dark(
            primary: AppColors.primarySoft,
            onPrimary: Color(0xFF32103E),
            primaryContainer: Color(0xFF6E2A86),
            onPrimaryContainer: Color(0xFFFFE8FF),
            secondary: Color(0xFF4CE7D5),
            onSecondary: Color(0xFF082B27),
            tertiary: AppColors.brandOrange,
            onTertiary: Color(0xFF3B120D),
            surface: AppColors.surface,
            onSurface: Color(0xFFFFF7FC),
            onSurfaceVariant: Color(0xFFD2BCD0),
            surfaceContainerLowest: AppColors.surfaceContainerLowest,
            surfaceContainerLow: AppColors.surfaceLow,
            surfaceContainer: AppColors.surfaceContainer,
            surfaceContainerHigh: AppColors.surfaceContainerHigh,
            surfaceContainerHighest: AppColors.surfaceHighest,
            outline: Color(0xFF92768F),
            outlineVariant: Color(0xFF543F55),
            error: AppColors.danger,
            onError: Colors.white,
          )
        : const ColorScheme.light(
            primary: AppColors.primaryDeep,
            onPrimary: Colors.white,
            primaryContainer: Color(0xFFF4D7FF),
            onPrimaryContainer: Color(0xFF5E1B72),
            secondary: Color(0xFF008D7B),
            onSecondary: Colors.white,
            tertiary: Color(0xFFC6533F),
            onTertiary: Colors.white,
            surface: AppColors.lightSurface,
            onSurface: AppColors.lightInk,
            onSurfaceVariant: AppColors.lightInkSecondary,
            surfaceContainerLowest: Color(0xFFFFFFFF),
            surfaceContainerLow: AppColors.lightSurfaceLow,
            surfaceContainer: AppColors.lightSurfaceContainer,
            surfaceContainerHigh: AppColors.lightSurfaceHigh,
            surfaceContainerHighest: AppColors.lightSurfaceHighest,
            outline: Color(0xFF8C7488),
            outlineVariant: Color(0xFFE2CEDF),
            error: Color(0xFFBA3346),
            onError: Colors.white,
          );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? AppColors.bg : AppColors.lightBg,
      visualDensity: VisualDensity.standard,
      splashFactory: InkRipple.splashFactory,
    );

    final textTheme = dark
        ? AppTypography.darkTextTheme()
        : AppTypography.lightTextTheme();
    final fieldFill = dark
        ? AppColors.surfaceLow.withValues(alpha: .88)
        : AppColors.lightSurface.withValues(alpha: .90);
    final subtleStroke = dark
        ? Colors.white.withValues(alpha: .11)
        : AppColors.lightInk.withValues(alpha: .10);

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      canvasColor: scheme.surface,
      focusColor: scheme.primary.withValues(alpha: .12),
      hoverColor: scheme.primary.withValues(alpha: .07),
      highlightColor: scheme.primary.withValues(alpha: .08),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        titleTextStyle: AppTypography.appBarTitle(color: scheme.onSurface),
        iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 21),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerHigh.withValues(alpha: .98),
        modalBackgroundColor: scheme.surfaceContainerHigh.withValues(
          alpha: .98,
        ),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        shape: AppShapes.sheet,
        showDragHandle: true,
        dragHandleColor: scheme.outlineVariant,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 18,
        shadowColor: Colors.black.withValues(alpha: dark ? .42 : .16),
        shape: AppShapes.card,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer.withValues(alpha: dark ? .90 : .94),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: dark ? .34 : .10),
        margin: EdgeInsets.zero,
        shape: AppShapes.card,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: dark ? .72 : .86),
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 21),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldFill,
        labelStyle: AppTypography.microLabel(color: scheme.onSurfaceVariant),
        floatingLabelStyle: AppTypography.microLabel(color: scheme.primary),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: .68),
        ),
        prefixIconColor: scheme.primary,
        suffixIconColor: scheme.onSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          borderSide: BorderSide(color: subtleStroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          borderSide: BorderSide(color: subtleStroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          elevation: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.pressed) ? 1 : 7,
          ),
          shadowColor: WidgetStatePropertyAll(
            AppColors.primary.withValues(alpha: dark ? .38 : .26),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return scheme.surfaceContainerHighest;
            }
            if (states.contains(WidgetState.pressed)) {
              return AppColors.primaryDeep;
            }
            if (states.contains(WidgetState.hovered)) {
              return const Color(0xFFD96CFF);
            }
            return AppColors.primary;
          }),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
          overlayColor: WidgetStatePropertyAll(
            Colors.white.withValues(alpha: .10),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          ),
          minimumSize: const WidgetStatePropertyAll(Size(48, 52)),
          shape: const WidgetStatePropertyAll(AppShapes.button),
          animationDuration: const Duration(milliseconds: 180),
          textStyle: WidgetStatePropertyAll(
            AppTypography.microLabel(color: Colors.white)
                .copyWith(inherit: false, fontSize: 12.5),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(scheme.primary),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.hovered)
                  ? scheme.primary
                  : scheme.outlineVariant,
            ),
          ),
          backgroundColor: WidgetStatePropertyAll(
            scheme.surface.withValues(alpha: dark ? .30 : .55),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
          shape: const WidgetStatePropertyAll(AppShapes.button),
          textStyle: WidgetStatePropertyAll(
            AppTypography.microLabel(color: scheme.primary)
                .copyWith(inherit: false, fontSize: 12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(scheme.primary),
          overlayColor: WidgetStatePropertyAll(
            scheme.primary.withValues(alpha: .08),
          ),
          shape: const WidgetStatePropertyAll(AppShapes.button),
          textStyle: WidgetStatePropertyAll(
            AppTypography.microLabel(color: scheme.primary)
                .copyWith(inherit: false, fontSize: 11.5),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(scheme.onSurfaceVariant),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return scheme.primary.withValues(alpha: .16);
            }
            if (states.contains(WidgetState.hovered)) {
              return scheme.primary.withValues(alpha: .10);
            }
            return scheme.surfaceContainerHigh.withValues(
              alpha: dark ? .56 : .70,
            );
          }),
          overlayColor: WidgetStatePropertyAll(
            scheme.primary.withValues(alpha: .08),
          ),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.hovered)
                  ? scheme.primary.withValues(alpha: .34)
                  : scheme.outlineVariant.withValues(alpha: .72),
            ),
          ),
          minimumSize: const WidgetStatePropertyAll(Size.square(42)),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(10)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          ),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: scheme.primary,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: scheme.onSurface,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: AppTypography.microLabel(color: scheme.onSurface),
        unselectedLabelStyle: AppTypography.microLabel(
          color: scheme.onSurfaceVariant,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: scheme.surfaceContainer.withValues(alpha: .92),
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: dark ? .23 : .14),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
            size: states.contains(WidgetState.selected) ? 22 : 21,
          ),
        ),
        labelTextStyle: WidgetStatePropertyAll(
          AppTypography.microLabel(color: scheme.onSurfaceVariant),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 7,
        focusElevation: 7,
        hoverElevation: 10,
        iconSize: 22,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.primary.withValues(alpha: dark ? .24 : .12)
                : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
          side: WidgetStatePropertyAll(
            BorderSide(color: scheme.outlineVariant),
          ),
          shape: const WidgetStatePropertyAll(AppShapes.pill),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.primary.withValues(alpha: .16),
        side: BorderSide(color: scheme.outlineVariant),
        shape: AppShapes.pill,
        labelStyle: AppTypography.microLabel(color: scheme.onSurfaceVariant),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.success
              : scheme.surfaceContainerHighest,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: scheme.surfaceContainerHighest,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? AppColors.surfaceHighest : AppColors.lightInk,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        elevation: 12,
        shape: AppShapes.cardSm,
        insetPadding: const EdgeInsets.all(16),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: ShapeDecoration(
          color: dark ? AppColors.surfaceHighest : AppColors.lightInk,
          shape: AppShapes.cardSm,
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: Colors.white),
        waitDuration: const Duration(milliseconds: 450),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withValues(alpha: .24),
        selectionHandleColor: scheme.primary,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
