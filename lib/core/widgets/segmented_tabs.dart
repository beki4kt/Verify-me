import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_colors.dart';
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
        return Container(
          height: 44,
          padding: const EdgeInsets.all(4),
          decoration: ShapeDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh
                .withValues(alpha: .72),
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
                child: const DecoratedBox(
                  decoration: ShapeDecoration(
                    color: AppColors.primary,
                    shape: AppShapes.pill,
                    shadows: [
                      BoxShadow(
                        color: AppColors.primary,
                        blurRadius: 12,
                        spreadRadius: -4,
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
                            tabs[i],
                            style: AppTypography.microLabel(
                              color: active
                                  ? Colors.white
                                  : Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
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
