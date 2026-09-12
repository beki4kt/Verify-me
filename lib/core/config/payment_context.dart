/// Business references share the existing text column so older records and
/// the deployed verification API remain readable during the UI transition.
enum PaymentContextKind {
  invoice('Invoice', 'Invoice number', 'INV-1042'),
  order('Order', 'Order number', 'ORD-208'),
  customer('Customer', 'Customer reference', 'Customer code'),
  table('Table', 'Table number', '5'),
  other('Other', 'Payment note', 'Service or booking reference');

  const PaymentContextKind(this.label, this.fieldLabel, this.hint);
  final String label;
  final String fieldLabel;
  final String hint;
}

abstract final class PaymentContext {
  /// Empty business references use the bank reference, never a fictitious table.
  static String encode(
    PaymentContextKind kind,
    String value,
    String transactionReference,
  ) {
    final clean = value.trim();
    return clean.isEmpty
        ? 'Payment: ${transactionReference.trim().toUpperCase()}'
        : '${kind.label}: $clean';
  }

  static String display(Object? stored) {
    final value = stored?.toString().trim() ?? '';
    if (value.isEmpty) return 'No business reference';
    if (RegExp(r'^(Invoice|Order|Customer|Table|Other|Payment): ')
        .hasMatch(value)) {
      return value;
    }
    // Unprefixed records were captured by the original table-based workflow.
    return 'Table: $value';
  }

  static String roleLabel(Object? role) => switch (role) {
    'waiter' => 'Payment staff',
    'cashier' => 'Cashier',
    'admin' => 'Administrator',
    _ => 'Staff',
  };
}
