import 'package:flutter_test/flutter_test.dart';
import 'package:verify_me/core/config/payment_context.dart';

void main() {
  test(
    'all business references round trip through the existing text field',
    () {
      for (final kind in PaymentContextKind.values) {
        final stored = PaymentContext.encode(kind, '  ABC-1042  ', 'TX123');
        expect(stored, '${kind.label}: ABC-1042');
        expect(PaymentContext.display(stored), stored);
      }
    },
  );

  test(
    'walk-in payments use their bank reference without requiring a table',
    () {
      final stored = PaymentContext.encode(
        PaymentContextKind.invoice,
        ' ',
        ' tx123 ',
      );
      expect(stored, 'Payment: TX123');
      expect(PaymentContext.display(stored), 'Payment: TX123');
    },
  );

  test('existing restaurant references remain readable', () {
    expect(PaymentContext.display('08'), 'Table: 08');
    expect(PaymentContext.display('Patio A'), 'Table: Patio A');
    expect(PaymentContext.display(null), 'No business reference');
  });

  test(
    'business role labels preserve compatibility with existing accounts',
    () {
      expect(PaymentContext.roleLabel('waiter'), 'Payment staff');
      expect(PaymentContext.roleLabel('cashier'), 'Cashier');
      expect(PaymentContext.roleLabel('admin'), 'Administrator');
    },
  );
}
