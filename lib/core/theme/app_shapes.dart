import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

/// Shape presets. Uses [ContinuousRectangleBorder] (true squircle / continuous
/// corners) for a premium look — the single biggest "expensive" visual upgrade.
class AppShapes {
  AppShapes._();

  /// Large card (ledgers, tenant cards, metric cards).
  static const ShapeBorder card = ContinuousRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppSpacing.radiusLg)),
  );

  /// Small card (ticket rows, list items).
  static const ShapeBorder cardSm = ContinuousRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppSpacing.radius)),
  );

  /// Fully-rounded pill (segmented tabs, chips, status dots container).
  static const ShapeBorder pill = ContinuousRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(999)),
  );

  /// Bottom sheet (rounded top).
  static const ShapeBorder sheet = ContinuousRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
  );

  /// Buttons.
  static const ShapeBorder button = ContinuousRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppSpacing.radius)),
  );

  /// A [ShapeDecoration] helper for Container-based cards using the squircle,
  /// with a 1px top highlight for subtle dark-mode elevation.
  static ShapeDecoration cardDecoration({Color? color, ShapeBorder? shape}) =>
      ShapeDecoration(
        color: color ?? AppColors.surfaceContainer,
        shape: shape ?? card,
        // subtle top highlight (drawn via a gradient handled by callers if needed)
      );
}
