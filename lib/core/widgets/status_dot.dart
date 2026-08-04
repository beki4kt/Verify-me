import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Lightweight status indicator: a colored dot + uppercase label.
/// Replaces the bordered `StatusPill` for in-list status (lighter, scannable).
class StatusDot extends StatelessWidget {
  const StatusDot({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null)
          Icon(icon, color: color, size: 12)
        else
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: AppTypography.microLabel(color: color),
        ),
      ],
    );
  }
}

/// A small filled, bordered bank-identity chip (e.g. "TELEBIRR").
class BankChip extends StatelessWidget {
  const BankChip({super.key, required this.bank, required this.color});
  final String bank;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: ShapeDecoration(
        color: color.withValues(alpha: 0.12),
        shape: const ContinuousRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
      child: Text(
        bank.toUpperCase(),
        style: AppTypography.bankTag(color: color),
      ),
    );
  }
}
