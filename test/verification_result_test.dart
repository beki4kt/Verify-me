import 'package:flutter_test/flutter_test.dart';
import 'package:verify_me/api_service.dart';

void main() {
  test('destination mismatch explains the next action', () {
    final result = VerificationResult(
      isSuccess: false,
      errorCode: 'DESTINATION_MISMATCH',
      errorMessage: 'Payment was not sent to this business account.',
    );

    expect(result.displayErrorMessage, contains('Confirm that the customer'));
  });

  test('retryable provider errors include the retry window', () {
    final result = VerificationResult(
      isSuccess: false,
      errorCode: 'PROVIDER_UNAVAILABLE',
      errorMessage: 'Telebirr receipt service is unavailable.',
      retryable: true,
      retryAfterSeconds: 60,
    );

    expect(result.displayErrorMessage, isNot(contains('Telebirr receipt')));
    expect(result.displayErrorMessage, contains('about 60 seconds'));
  });

  test('connection errors never expose technical exception details', () {
    final result = VerificationResult(
      isSuccess: false,
      errorCode: 'CONNECTION_FAILED',
      errorMessage: 'SocketException: errno = 110',
      retryable: true,
    );

    expect(
      result.displayErrorMessage,
      'Cannot reach CHEKMI. Check your connection and try again.',
    );
  });

  test('session errors direct staff back to sign in', () {
    final result = VerificationResult(
      isSuccess: false,
      errorCode: 'SESSION_EXPIRED',
    );

    expect(result.displayErrorMessage, contains('Sign in again'));
  });
}
