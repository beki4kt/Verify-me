import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';

class OperatorApiException implements Exception {
  const OperatorApiException(this.message, {this.code, this.status});

  final String message;
  final String? code;
  final int? status;

  @override
  String toString() => message;
}

class OperatorService {
  OperatorService._();

  static String? _token;
  static String? _email;
  static DateTime? _expiresAt;

  static bool get isAuthenticated =>
      _token != null &&
      _expiresAt != null &&
      _expiresAt!.isAfter(DateTime.now().toUtc());
  static String get operatorEmail => _email ?? 'Platform owner';

  static Future<void> login({
    required String email,
    required String password,
    required String code,
  }) async {
    final payload = await _request(
      'POST',
      '/operator/login',
      authenticated: false,
      body: {'email': email.trim(), 'password': password, 'code': code.trim()},
    );
    final token = payload['token']?.toString();
    final operator = payload['operator'] is Map
        ? Map<String, dynamic>.from(payload['operator'] as Map)
        : <String, dynamic>{};
    if (token == null || token.isEmpty) {
      throw const OperatorApiException(
        'The server did not create an owner session.',
      );
    }
    _token = token;
    _email = operator['email']?.toString() ?? email.trim().toLowerCase();
    _expiresAt = DateTime.tryParse(operator['expiresAt']?.toString() ?? '')
        ?.toUtc();
  }

  static void logout() {
    _token = null;
    _email = null;
    _expiresAt = null;
  }

  static Future<Map<String, dynamic>> fetchOverview() =>
      _request('GET', '/operator/overview');

  static Future<void> createBusiness(Map<String, dynamic> values) async {
    await _request('POST', '/operator/businesses', body: values);
  }

  static Future<void> setBusinessStatus({
    required String businessId,
    required bool active,
    String reason = '',
  }) async {
    await _request(
      'PATCH',
      '/operator/businesses/$businessId/status',
      body: {'active': active, 'reason': reason},
    );
  }

  static Future<void> updateSubscription({
    required String businessId,
    required String tier,
    required String status,
    required int maxStaff,
    required bool hasCashier,
    String? endsAt,
    String? graceEndsAt,
  }) async {
    await _request(
      'PATCH',
      '/operator/businesses/$businessId/subscription',
      body: {
        'tier': tier,
        'status': status,
        'maxStaff': maxStaff,
        'hasCashier': hasCashier,
        'endsAt': endsAt,
        'graceEndsAt': graceEndsAt,
      },
    );
  }

  static Future<int> revokeBusinessSessions({
    required String businessId,
    String reason = '',
  }) async {
    final payload = await _request(
      'POST',
      '/operator/businesses/$businessId/revoke-sessions',
      body: {'reason': reason},
    );
    return (payload['revoked'] as num?)?.toInt() ?? 0;
  }

  static Future<void> updateSupportCase({
    required String caseId,
    required String status,
  }) async {
    await _request(
      'PATCH',
      '/operator/support/$caseId',
      body: {'status': status},
    );
  }

  static Future<void> reviewDeletionRequest({
    required String requestId,
    required String status,
    String notes = '',
  }) async {
    await _request(
      'PATCH',
      '/operator/deletions/$requestId',
      body: {'status': status, 'notes': notes},
    );
  }

  static Future<int> refreshSubscriptionStatuses() async {
    final payload = await _request(
      'POST',
      '/operator/system/refresh-subscriptions',
      body: const {},
    );
    return (payload['changed'] as num?)?.toInt() ?? 0;
  }

  static Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    if (authenticated && !isAuthenticated) {
      logout();
      throw const OperatorApiException(
        'Your owner session has expired. Sign in again.',
        code: 'OPERATOR_SESSION_EXPIRED',
        status: 401,
      );
    }
    final request = http.Request(
      method,
      Uri.parse('${ApiService.baseUrl}$path'),
    );
    request.headers['Accept'] = 'application/json';
    request.headers['Content-Type'] = 'application/json';
    if (authenticated) request.headers['Authorization'] = 'Bearer $_token';
    if (body != null) request.body = jsonEncode(body);

    http.StreamedResponse response;
    try {
      response = await request.send().timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const OperatorApiException(
        'The protected operator API is unreachable. Start or deploy the CHEKMI backend and try again.',
        code: 'OPERATOR_API_UNREACHABLE',
      );
    }
    final raw = await response.stream.bytesToString();
    Map<String, dynamic> payload = <String, dynamic>{};
    if (raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) payload = Map<String, dynamic>.from(decoded);
      } catch (_) {
        payload = {'error': raw};
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401 && authenticated) logout();
      throw OperatorApiException(
        payload['error']?.toString() ??
            'Operator request failed (${response.statusCode}).',
        code: payload['code']?.toString(),
        status: response.statusCode,
      );
    }
    return payload;
  }
}
