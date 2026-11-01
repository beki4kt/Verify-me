import 'package:flutter_test/flutter_test.dart';
import 'package:verify_me/core/services/receipt_upload_response.dart';

void main() {
  test('only a confirmed stored original counts as archived', () {
    expect(
      () => requireStoredReceiptResponse(
        201,
        '{"success":true,"status":"stored","receiptId":"receipt-1"}',
      ),
      returnsNormally,
    );
    expect(
      () => requireStoredReceiptResponse(200, '{"success":true}'),
      throwsA(isA<ReceiptUploadException>()),
    );
    expect(
      () =>
          requireStoredReceiptResponse(200, '<html>temporary response</html>'),
      throwsA(isA<ReceiptUploadException>()),
    );
  });

  test('temporary storage failure keeps the original eligible for retry', () {
    expect(
      () => requireStoredReceiptResponse(
        503,
        '{"success":false,"code":"FINALIZATION_PENDING"}',
      ),
      throwsA(
        isA<ReceiptUploadException>()
            .having((e) => e.code, 'code', 'FINALIZATION_PENDING')
            .having((e) => e.retryable, 'retryable', true),
      ),
    );
  });

  test('invalid original is terminal so the user can select another image', () {
    expect(
      () => requireStoredReceiptResponse(
        415,
        '{"success":false,"code":"INVALID_IMAGE"}',
      ),
      throwsA(
        isA<ReceiptUploadException>()
            .having((e) => e.code, 'code', 'INVALID_IMAGE')
            .having((e) => e.retryable, 'retryable', false),
      ),
    );
  });
}
