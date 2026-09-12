import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_colors.dart';
import '../config/app_variant.dart';
import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// A modern sliding-pill segmented control. Replaces the underline `TabBar` in
/// the Waiter/Cashier/Admin screens with a single rounded track and an animated
/// pill that springs between options, plus a light selection haptic.
class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.tabs,
    required this.index,
    required this.onChanged,
  });

  final List<String> tabs;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final segmentWidth = constraints.maxWidth / tabs.length;
        final iPhone = AppVariant.usesIPhoneUi;
        final scheme = Theme.of(context).colorScheme;
        return Container(
          height: iPhone ? 48 : 44,
          padding: EdgeInsets.all(iPhone ? 5 : 4),
          decoration: ShapeDecoration(
            color: scheme.surfaceContainerHigh.withValues(alpha: .82),
            shape: AppShapes.pill,
          ),
          child: Stack(
            children: [
              // Sliding active pill.
              AnimatedPositioned(
                duration: AppMotion.base,
                curve: Curves.easeOutCubic,
                left: segmentWidth * index,
                top: 0,
                bottom: 0,
                width: segmentWidth,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: iPhone ? scheme.surface : AppColors.primary,
                    shape: AppShapes.pill,
                    shadows: const [
                      BoxShadow(
                        color: Color(0x26000000),
                        blurRadius: 10,
                        spreadRadius: -3,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
              // Labels.
              Row(
                children: List.generate(tabs.length, (i) {
                  final active = i == index;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (i == index) return;
                        HapticFeedback.selectionClick();
                        onChanged(i);
                      },
                      child: Center(
                        child: MotorScale(
                          scale: active ? 1 : .96,
                          child: Text(
                            iPhone ? _sentenceCase(tabs[i]) : tabs[i],
                            style: iPhone
                                ? Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(
                                        color: active
                                            ? scheme.onSurface
                                            : scheme.onSurfaceVariant,
                                        fontWeight: active
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      )
                                : AppTypography.microLabel(
                                    color: active
                                        ? Colors.white
                                        : scheme.onSurfaceVariant,
                                  ).copyWith(fontSize: 11),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ).animate().fadeIn(duration: AppMotion.base);
      },
    );
  }

  String _sentenceCase(String value) {
    if (value.isEmpty || value != value.toUpperCase()) return value;
    final lower = value.toLowerCase();
    return '${lower[0].toUpperCase()}${lower.substring(1)}';
  }
}

/// Stand-alone container for a segmented tab bar with a small surrounding
/// page-padding. Optional: renders nothing if fewer than 2 tabs.
class SegmentedTabBar extends StatelessWidget {
  const SegmentedTabBar({
    super.key,
    required this.tabs,
    required this.index,
    required this.onChanged,
  });

  final List<String> tabs;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    if (tabs.length < 2) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: SegmentedTabs(tabs: tabs, index: index, onChanged: onChanged),
    );
  }
}
