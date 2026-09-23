import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../config/app_variant.dart';
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
    if (AppVariant.usesIPhoneUi) {
      final theme = Theme.of(context);
      return GlassPanel(
        padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
        borderRadius: 22,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _sentenceCase(title),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  width: 22,
                  height: 6,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .88),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -.6,
              ),
            ),
          ],
        ),
      );
    }
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

  String _sentenceCase(String value) {
    if (value.isEmpty || value != value.toUpperCase()) return value;
    final lower = value.toLowerCase();
    return '${lower[0].toUpperCase()}${lower.substring(1)}';
  }
}
