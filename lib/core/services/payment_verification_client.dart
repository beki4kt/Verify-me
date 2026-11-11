import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/verification_result.dart';

class PaymentVerificationClient {
  PaymentVerificationClient({
    required this.client,
    required this.endpoint,
    required this.supportsStatus,
    this.requestTimeout = const Duration(seconds: 60),
    this.statusTimeout = const Duration(seconds: 12),
  });

  final http.Client client;
  final Uri endpoint;
  final bool supportsStatus;
  final Duration requestTimeout;
  final Duration statusTimeout;

  Future<VerificationResult> verify({
    required String token,
    required String publicKey,
    required Map<String, dynamic> body,
  }) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      if (supportsStatus) 'apikey': publicKey,
    };
    VerificationResult result;
    try {
      final response = await client
          .post(endpoint, headers: headers, body: jsonEncode(body))
          .timeout(requestTimeout);
      result = decode(response);
    } on TimeoutException {
      result = VerificationResult(
        isSuccess: false,
        errorCode: 'TIMEOUT',
        retryable: true,
      );
    } catch (_) {
      result = VerificationResult(
        isSuccess: false,
        errorCode: 'CONNECTION_FAILED',
        retryable: true,
      );
    }
    if (!result.isSuccess &&
        supportsStatus &&
        const {
          'TIMEOUT',
          'CONNECTION_FAILED',
          'DATABASE_UNAVAILABLE',
          'COMMIT_NOT_CONFIRMED',
          'VERIFICATION_IN_PROGRESS',
          'INVALID_SERVICE_RESPONSE',
        }.contains(result.errorCode)) {
      // Recovery only reads an existing payment. It never repeats the paid
      // Veritas lookup or accepts an uncommitted provider receipt as success.
      try {
        final response = await client
            .post(
              endpoint,
              headers: headers,
              body: jsonEncode({
                'action': 'status',
                'provider': body['provider'],
                'reference': body['reference'],
              }),
            )
            .timeout(statusTimeout);
        final saved = decode(response);
        if (saved.isSuccess) return saved;
        if (saved.errorCode == 'SESSION_EXPIRED') return saved;
      } catch (_) {
        /* Retain the original uncertainty/error. */
      }
    }
    return result;
  }

  static VerificationResult decode(http.Response response) {
    Map<String, dynamic> body;
    try {
      final value = jsonDecode(response.body);
      if (value is! Map<String, dynamic>) throw const FormatException();
      body = value;
    } catch (_) {
      return VerificationResult(
        isSuccess: false,
        errorCode: 'INVALID_SERVICE_RESPONSE',
        retryable: true,
        errorMessage: 'The verification service is unavailable or not deployed. Ask the administrator to check its setup.',
      );
    }
    final data = body['data'];
    if (response.statusCode == 404 && body['code'] == 'NOT_FOUND') {
      return VerificationResult(
        isSuccess: false,
        errorCode: 'SERVICE_NOT_DEPLOYED',
        errorMessage: 'Payment verification is not deployed yet. Ask the administrator to deploy the chekmi-verify function in Supabase.',
      );
    }
    final ticketId = data is Map ? data['ticket_id'] : null;
    if ((response.statusCode == 200 || response.statusCode == 201) &&
        body['success'] == true &&
        ticketId is String &&
        ticketId.trim().isNotEmpty) {
      return VerificationResult(isSuccess: true, data: body);
    }
    final missingCommit = body['success'] == true;
    return VerificationResult(
      isSuccess: false,
      errorCode: missingCommit
          ? 'COMMIT_NOT_CONFIRMED'
          : body['code']?.toString() ?? 'NOT_VERIFIED',
      errorMessage: missingCommit
          ? 'The service did not confirm a saved payment. Check payment history before retrying.'
          : body['error']?.toString() ??
                body['message']?.toString() ??
                'The payment was not verified.',
      retryable: missingCommit || body['retryable'] == true,
      retryAfterSeconds: body['retryAfterSeconds'] is num
          ? (body['retryAfterSeconds'] as num).toInt()
          : int.tryParse(body['retryAfterSeconds']?.toString() ?? ''),
      data: body,
    );
  }
}
