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
      errorCode: 'VERIFIER_TEMPORARILY_UNAVAILABLE',
      errorMessage: 'The provider is temporarily unavailable.',
      retryable: true,
      retryAfterSeconds: 60,
    );

    expect(result.displayErrorMessage, contains('about 60 seconds'));
  });

  test('session errors direct staff back to sign in', () {
    final result = VerificationResult(
      isSuccess: false,
      errorCode: 'SESSION_EXPIRED',
    );

    expect(result.displayErrorMessage, contains('Sign in again'));
  });
}
