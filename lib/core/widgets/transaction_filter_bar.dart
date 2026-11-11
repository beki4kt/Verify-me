import 'package:flutter/material.dart';
import 'package:verify_me/core/theme/app_icons.dart';

import '../config/app_variant.dart';
import '../theme/app_spacing.dart';
import 'payment_brand.dart';

enum TransactionPeriod { daily, weekly, custom, all }

extension TransactionPeriodLabel on TransactionPeriod {
  String get label => switch (this) {
    TransactionPeriod.daily => 'Daily',
    TransactionPeriod.weekly => 'Weekly',
    TransactionPeriod.custom => 'Custom range',
    TransactionPeriod.all => 'All time',
  };
}

List<Map<String, dynamic>> filterTransactions(
  List<Map<String, dynamic>> rows, {
  required TransactionPeriod period,
  DateTimeRange? customRange,
  String? staffNumber,
  String? paymentMethod,
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  final start = switch (period) {
    TransactionPeriod.daily => today,
    TransactionPeriod.weekly => today.subtract(const Duration(days: 6)),
    TransactionPeriod.custom =>
      customRange == null
          ? null
          : DateTime(
              customRange.start.year,
              customRange.start.month,
              customRange.start.day,
            ),
    TransactionPeriod.all => null,
  };
  final endExclusive = period == TransactionPeriod.custom && customRange != null
      ? DateTime(
          customRange.end.year,
          customRange.end.month,
          customRange.end.day + 1,
        )
      : null;

  return rows
      .where((row) {
        if (staffNumber != null &&
            staffNumber.isNotEmpty &&
            row['waiter_id']?.toString() != staffNumber) {
          return false;
        }
        if (paymentMethod != null &&
            paymentMethod.isNotEmpty &&
            row['bank']?.toString().toLowerCase() !=
                paymentMethod.toLowerCase()) {
          return false;
        }
        if (start == null) return true;
        final created = DateTime.tryParse(row['created_at']?.toString() ?? '')
            ?.toLocal();
        if (created == null || created.isBefore(start)) return false;
        if (endExclusive != null && !created.isBefore(endExclusive)) {
          return false;
        }
        return true;
      })
      .toList(growable: false);
}

class TransactionFilterBar extends StatelessWidget {
  const TransactionFilterBar({
    super.key,
    required this.period,
    required this.onPeriodChanged,
    required this.paymentMethods,
    required this.paymentMethod,
    required this.onPaymentMethodChanged,
    this.staffMembers = const {},
    this.staffNumber,
    this.onStaffChanged,
    this.customRange,
  });

  final TransactionPeriod period;
  final ValueChanged<TransactionPeriod> onPeriodChanged;
  final List<String> paymentMethods;
  final String? paymentMethod;
  final ValueChanged<String?> onPaymentMethodChanged;
  final Map<String, String> staffMembers;
  final String? staffNumber;
  final ValueChanged<String?>? onStaffChanged;
  final DateTimeRange? customRange;

  @override
  Widget build(BuildContext context) {
    final rangeLabel = customRange == null
        ? 'Choose dates'
        : '${_shortDate(customRange!.start)} – ${_shortDate(customRange!.end)}';
    if (AppVariant.usesIPhoneUi) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        clipBehavior: Clip.none,
        child: Row(
          children: [
            _IPhoneFilterPill<TransactionPeriod>(
              icon: AppIcons.calendar,
              label: period.label,
              values: TransactionPeriod.values,
              itemLabel: (value) => value.label,
              onSelected: onPeriodChanged,
            ),
            if (period == TransactionPeriod.custom) ...[
              const SizedBox(width: 8),
              _IPhoneFilterAction(
                icon: AppIcons.calendar,
                label: rangeLabel,
                onTap: () => onPeriodChanged(TransactionPeriod.custom),
              ),
            ],
            if (onStaffChanged != null) ...[
              const SizedBox(width: 8),
              _IPhoneFilterPill<String>(
                icon: AppIcons.staffBadge,
                label: staffNumber == null
                    ? 'All staff'
                    : (staffMembers[staffNumber] ?? 'Staff $staffNumber'),
                values: ['', ...staffMembers.keys],
                itemLabel: (value) => value.isEmpty
                    ? 'All staff'
                    : (staffMembers[value] ?? 'Staff $value'),
                onSelected: (value) =>
                    onStaffChanged!(value.isEmpty ? null : value),
              ),
            ],
            const SizedBox(width: 8),
            _IPhoneFilterPill<String>(
              icon: AppIcons.money,
              label: paymentMethod ?? 'All methods',
              values: ['', ...paymentMethods],
              itemLabel: (value) => value.isEmpty ? 'All methods' : value,
              onSelected: (value) =>
                  onPaymentMethodChanged(value.isEmpty ? null : value),
            ),
          ],
        ),
      );
    }
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        SizedBox(
          width: 170,
          child: DropdownButtonFormField<TransactionPeriod>(
            isExpanded: true,
            initialValue: period,
            decoration: const InputDecoration(
              labelText: 'Time',
              prefixIcon: Icon(AppIcons.calendar),
            ),
            items: TransactionPeriod.values
                .map(
                  (value) =>
                      DropdownMenuItem(value: value, child: Text(value.label)),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) onPeriodChanged(value);
            },
          ),
        ),
        if (period == TransactionPeriod.custom)
          ActionChip(
            avatar: const Icon(AppIcons.calendar, size: 18),
            label: Text(rangeLabel),
            onPressed: () => onPeriodChanged(TransactionPeriod.custom),
          ),
        if (onStaffChanged != null)
          SizedBox(
            width: 190,
            child: DropdownButtonFormField<String?>(
              isExpanded: true,
              initialValue: staffNumber,
              decoration: const InputDecoration(
                labelText: 'Staff member',
                prefixIcon: Icon(AppIcons.staffBadge),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All staff'),
                ),
                ...staffMembers.entries.map(
                  (entry) => DropdownMenuItem<String?>(
                    value: entry.key,
                    child: Text(entry.value, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: onStaffChanged,
            ),
          ),
        SizedBox(
          width: 190,
          child: DropdownButtonFormField<String?>(
            isExpanded: true,
            initialValue: paymentMethod,
            decoration: const InputDecoration(
              labelText: 'Payment method',
              prefixIcon: Icon(AppIcons.money),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All methods'),
              ),
              ...paymentMethods.map(
                (method) => DropdownMenuItem<String?>(
                  value: method,
                  child: PaymentBrand(
                    provider: method,
                    logoSize: 24,
                    compactName: true,
                  ),
                ),
              ),
            ],
            onChanged: onPaymentMethodChanged,
          ),
        ),
      ],
    );
  }

  static String _shortDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _IPhoneFilterPill<T> extends StatelessWidget {
  const _IPhoneFilterPill({
    required this.icon,
    required this.label,
    required this.values,
    required this.itemLabel,
    required this.onSelected,
  });

  final IconData icon;
  final String label;
  final List<T> values;
  final String Function(T value) itemLabel;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => PopupMenuButton<T>(
    position: PopupMenuPosition.under,
    tooltip: label,
    onSelected: onSelected,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    itemBuilder: (context) => [
      for (final value in values)
        PopupMenuItem<T>(value: value, child: Text(itemLabel(value))),
    ],
    child: _IPhoneFilterSurface(icon: icon, label: label, showChevron: true),
  );
}

class _IPhoneFilterAction extends StatelessWidget {
  const _IPhoneFilterAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: _IPhoneFilterSurface(icon: icon, label: label),
  );
}

class _IPhoneFilterSurface extends StatelessWidget {
  const _IPhoneFilterSurface({
    required this.icon,
    required this.label,
    this.showChevron = false,
  });

  final IconData icon;
  final String label;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: .88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: .42),
          width: .6,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: scheme.primary),
          const SizedBox(width: 9),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (showChevron) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );
  }
}
