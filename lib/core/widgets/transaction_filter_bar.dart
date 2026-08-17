import 'package:flutter/material.dart';

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
        final created = DateTime.tryParse(
          row['created_at']?.toString() ?? '',
        )?.toLocal();
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
              prefixIcon: Icon(Icons.calendar_today_rounded),
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
            avatar: const Icon(Icons.date_range_rounded, size: 18),
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
                prefixIcon: Icon(Icons.badge_outlined),
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
              prefixIcon: Icon(Icons.payments_outlined),
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
