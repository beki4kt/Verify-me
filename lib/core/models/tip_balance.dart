double calculateWithdrawableTips({
  required Iterable<Map<String, dynamic>> tickets,
  required Iterable<Map<String, dynamic>> withdrawals,
}) {
  final earned = tickets
      .where((ticket) => ticket['status'] == 'settled')
      .fold<double>(
        0,
        (sum, ticket) =>
            sum + ((ticket['tip_amount'] as num?)?.toDouble() ?? 0),
      );
  final committed = withdrawals
      .where(
        (withdrawal) => const {
          'pending',
          'approved',
          'paid',
        }.contains(withdrawal['status']),
      )
      .fold<double>(
        0,
        (sum, withdrawal) =>
            sum + ((withdrawal['amount'] as num?)?.toDouble() ?? 0),
      );
  return (earned - committed).clamp(0, double.infinity).toDouble();
}
