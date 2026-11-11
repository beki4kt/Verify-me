import 'package:flutter_test/flutter_test.dart';
import 'package:verify_me/core/models/tip_balance.dart';

void main() {
  test('paid withdrawals remain deducted from the available tip balance', () {
    final available = calculateWithdrawableTips(
      tickets: const [
        {'status': 'settled', 'tip_amount': 100},
        {'status': 'settled', 'tip_amount': 25.5},
        {'status': 'pending', 'tip_amount': 50},
      ],
      withdrawals: const [
        {'status': 'paid', 'amount': 60},
        {'status': 'approved', 'amount': 20},
        {'status': 'pending', 'amount': 10},
        {'status': 'rejected', 'amount': 30},
      ],
    );

    expect(available, 35.5);
  });

  test('available tip balance never becomes negative', () {
    final available = calculateWithdrawableTips(
      tickets: const [
        {'status': 'settled', 'tip_amount': 10},
      ],
      withdrawals: const [
        {'status': 'paid', 'amount': 20},
      ],
    );

    expect(available, 0);
  });

  test('explicit allocated tips count only after a payment completes', () {
    expect(
      calculateWithdrawableTips(
        tickets: const [
          {'status': 'settled', 'tip_amount': 0, 'allocated_tip_amount': 18},
          {'status': 'pending', 'tip_amount': 0, 'allocated_tip_amount': 12},
          {
            'status': 'settled',
            'financial_state': 'refunded',
            'tip_amount': 0,
            'allocated_tip_amount': 9,
          },
        ],
        withdrawals: const [],
      ),
      18,
    );
  });
}
