import 'dart:convert';

class ReceiptUploadException implements Exception {
  const ReceiptUploadException(
    this.code,
    this.message, {
    this.retryable = false,
  });

  final String code;
  final String message;
  final bool retryable;

  @override
  String toString() => message;
}

/// A transport response counts as archived only when the evidence service
/// explicitly confirms that the original is stored and linked to a receipt.
void requireStoredReceiptResponse(int statusCode, String body) {
  Map<String, dynamic>? data;
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) data = decoded;
  } catch (_) {
    // A malformed response cannot establish that an image was archived.
  }

  if (statusCode >= 200 &&
      statusCode < 300 &&
      data?['success'] == true &&
      data?['status'] == 'stored' &&
      data?['receiptId'] is String &&
      (data!['receiptId'] as String).isNotEmpty) {
    return;
  }

  final code = data?['code']?.toString() ?? 'EVIDENCE_NOT_CONFIRMED';
  final retryable =
      statusCode >= 500 ||
      statusCode == 429 ||
      (statusCode >= 200 && statusCode < 300);
  throw ReceiptUploadException(
    code,
    data?['error']?.toString() ?? 'Original image was not confirmed as saved. Retry from receipt details.',
    retryable: retryable,
  );
}
