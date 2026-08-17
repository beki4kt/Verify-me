import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verify_me/core/widgets/transaction_filter_bar.dart';

void main() {
  final now = DateTime(2026, 8, 11, 15);
  final rows = <Map<String, dynamic>>[
    {
      'created_at': '2026-08-11T08:00:00',
      'waiter_id': '1001',
      'bank': 'Telebirr',
    },
    {'created_at': '2026-08-07T08:00:00', 'waiter_id': '1002', 'bank': 'CBE'},
    {
      'created_at': '2026-07-20T08:00:00',
      'waiter_id': '1001',
      'bank': 'M-Pesa',
    },
  ];

  test('daily and weekly periods filter without network refetching', () {
    expect(
      filterTransactions(rows, period: TransactionPeriod.daily, now: now),
      hasLength(1),
    );
    expect(
      filterTransactions(rows, period: TransactionPeriod.weekly, now: now),
      hasLength(2),
    );
  });

  test('custom date, staff, and payment filters compose', () {
    final result = filterTransactions(
      rows,
      period: TransactionPeriod.custom,
      customRange: DateTimeRange(
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 10),
      ),
      staffNumber: '1002',
      paymentMethod: 'cbe',
      now: now,
    );

    expect(result, hasLength(1));
    expect(result.single['waiter_id'], '1002');
  });

  testWidgets('filter dropdowns render with all options selected', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TransactionFilterBar(
            period: TransactionPeriod.all,
            onPeriodChanged: (_) {},
            staffMembers: const {'1001': 'Mimi'},
            onStaffChanged: (_) {},
            paymentMethods: const ['Telebirr', 'CBE'],
            paymentMethod: null,
            onPaymentMethodChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('All time'), findsOneWidget);
    expect(find.text('All staff'), findsOneWidget);
    expect(find.text('All methods'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
