class VerificationResult {
  final bool isSuccess;
  final String? errorMessage;
  final String? errorCode;
  final bool retryable;
  final int? retryAfterSeconds;
  final Map<String, dynamic>? data;

  VerificationResult({
    required this.isSuccess,
    this.errorMessage,
    this.errorCode,
    this.retryable = false,
    this.retryAfterSeconds,
    this.data,
  });

  String get displayErrorMessage {
    final message = errorMessage ?? 'Payment verification failed.';
    return switch (errorCode) {
      'SESSION_REQUIRED' || 'SESSION_EXPIRED' => 'Your staff session expired. Sign in again before verifying this payment.',
      'RECEIVING_ACCOUNT_INVALID' =>
        '$message Ask the business administrator to update this provider account.',
      'DESTINATION_MISMATCH' =>
        '$message Confirm that the customer paid the business account shown at checkout.',
      'UNDERPAID' =>
        '$message This version requires one receipt covering the full amount due; separate receipts cannot be combined.',
      'TRANSACTION_TOO_OLD' =>
        '$message Use a receipt inside the allowed verification window.',
      'DUPLICATE_PAYMENT' =>
        '$message Refresh the payment list before attempting another verification.',
      'RATE_LIMIT' || 'PROVIDER_RATE_LIMIT' || 'VERITAS_RATE_LIMIT' =>
        retryAfterSeconds == null
            ? 'Too many attempts. Try again shortly.'
            : 'Too many attempts. Retry in about $retryAfterSeconds seconds.',
      'PROVIDER_UNAVAILABLE' ||
      'VERIFIER_TEMPORARILY_UNAVAILABLE' ||
      'VERIFIER_ERROR' =>
        retryAfterSeconds == null
            ? 'Payment service unavailable. Try again shortly.'
            : 'Payment service unavailable. Retry in about $retryAfterSeconds seconds.',
      'CONNECTION_FAILED' =>
        'Cannot reach CHEKMI. Check your connection and try again.',
      'TIMEOUT' => 'No payment confirmation was received. Check payment history before retrying.',
      _ => message,
    };
  }
}
