import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_shell.dart';

/// A left-accented metric card (revenue, active bills, etc.).
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    this.accent = AppColors.primary,
  });

  final String title;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return HoverSurface(
      accent: accent,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.microLabel()),
          const SizedBox(height: AppSpacing.md),
          Text(value, style: AppTypography.money(size: 24)),
        ],
      ),
    );
  }
}
