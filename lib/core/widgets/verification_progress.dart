import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum VerificationProgressStage {
  checkingProvider,
  confirmingPayment,
  savingTicket,
}

extension VerificationProgressStageCopy on VerificationProgressStage {
  String get label => switch (this) {
    VerificationProgressStage.checkingProvider => 'Checking provider',
    VerificationProgressStage.confirmingPayment =>
      'Confirming destination and amount',
    VerificationProgressStage.savingTicket => 'Saving ticket',
  };
}

class VerificationProgress extends StatelessWidget {
  const VerificationProgress({
    super.key,
    required this.stage,
    this.takingLonger = false,
  });

  final VerificationProgressStage stage;
  final bool takingLonger;

  @override
  Widget build(BuildContext context) {
    final activeIndex = VerificationProgressStage.values.indexOf(stage);
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      liveRegion: true,
      label: stage.label,
      child: Container(
        key: const Key('verification-progress'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (
              var index = 0;
              index < VerificationProgressStage.values.length;
              index++
            ) ...[
              _ProgressRow(
                label: VerificationProgressStage.values[index].label,
                isComplete: index < activeIndex,
                isActive: index == activeIndex,
                textColor: colors.onSurface,
              ),
              if (index < VerificationProgressStage.values.length - 1)
                const SizedBox(height: 9),
            ],
            if (takingLonger) ...[
              const SizedBox(height: 12),
              Text(
                'Taking longer than usual. Keep CHEKMI open while we finish.',
                key: const Key('verification-taking-longer'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.isComplete,
    required this.isActive,
    required this.textColor,
  });

  final String label;
  final bool isComplete;
  final bool isActive;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox.square(
          dimension: 18,
          child: isComplete
              ? const Icon(
                  Icons.check_circle,
                  size: 18,
                  color: AppColors.success,
                )
              : isActive
              ? const CircularProgressIndicator(strokeWidth: 2)
              : Icon(
                  Icons.circle_outlined,
                  size: 17,
                  color: textColor.withValues(alpha: 0.35),
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: textColor.withValues(
                alpha: isActive || isComplete ? 1 : .5,
              ),
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
