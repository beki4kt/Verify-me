import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_environment.dart';
import 'core/session/session_controller.dart';

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
        '$message Ask the restaurant administrator to update this provider account.',
      'DESTINATION_MISMATCH' =>
        '$message Confirm that the customer paid the restaurant account shown at checkout.',
      'UNDERPAID' => '$message Ask the customer to pay the remaining balance.',
      'TRANSACTION_TOO_OLD' =>
        '$message Use a receipt inside the allowed verification window.',
      'DUPLICATE_PAYMENT' =>
        '$message Refresh the ticket list before attempting another verification.',
      'RATE_LIMIT' || 'VERIFIER_TEMPORARILY_UNAVAILABLE' || 'VERIFIER_ERROR' =>
        retryAfterSeconds == null
            ? '$message Try again shortly.'
            : '$message Try again in about $retryAfterSeconds seconds.',
      'CONNECTION_FAILED' =>
        '$message Check the connection, then refresh the ticket list before retrying.',
      'TIMEOUT' =>
        '$message Refresh the ticket list before retrying because the first request may have completed.',
      _ => message,
    };
  }
}

class ApiService {
  static String get baseUrl => AppEnvironment.apiBaseUrl;

  // CHEKMI uses its own short-lived backend sessions. A bare public client is
  // sufficient for the remaining tenant RPCs and avoids an unused browser auth
  // restoration step delaying app startup.
  static final _supabase = SupabaseClient(
    AppEnvironment.supabaseUrl,
    AppEnvironment.supabasePublishableKey,
  );
  static SessionController? _session;

  static void configureSession(SessionController session) {
    _session = session;
  }

  static String? currentBusinessId;
  static String? currentStaffNumber;
  static String? currentUserRole;
  static String? _staffSessionToken;
  static int? currentBusinessMaxStaff;
  static bool? currentBusinessHasCashier;
  static final Map<String, Stream<List<Map<String, dynamic>>>>
  _ticketStreamCache = {};
  static Stream<List<Map<String, dynamic>>>? _withdrawalRequestsStream;
  static Stream<List<Map<String, dynamic>>>? _staffRosterStream;
  static Stream<Map<String, dynamic>>? _businessStream;

  // --- 1. AUTHENTICATION & BUSINESS LAYER ---

  static Future<Map<String, dynamic>?> verifyBusinessCode(String code) async {
    final normalizedCode = code.trim().toUpperCase();
    dynamic response;
    try {
      response = await _supabase.rpc(
        'lookup_business',
        params: {'p_code': normalizedCode},
      );
    } on PostgrestException catch (error) {
      final lookupRpcMissing =
          error.code == 'PGRST202' && error.message.contains('lookup_business');
      if (!lookupRpcMissing) rethrow;

      // Compatibility path for installations that still use the original
      // CHEKMI schema. The restricted RPC remains the primary path; this
      // selects only the four public fields it would have returned.
      try {
        response = await _supabase
            .from('businesses')
            .select('business_id,name,business_code,is_active')
            .eq('business_code', normalizedCode)
            .maybeSingle();
      } on PostgrestException {
        throw Exception('Workspace service is unavailable.');
      }
    }

    if (response == null) throw Exception("Invalid Business Code.");
    final business = Map<String, dynamic>.from(response as Map);
    if (business['is_active'] != true) {
      throw Exception("This business account is currently suspended.");
    }

    return business;
  }

  static Future<String?> loginStaffUnderBusiness(
    String lockedBusinessId,
    String phone,
    String password,
  ) async {
    final response = await _supabase.rpc(
      'login_staff',
      params: {
        'p_business_id': lockedBusinessId,
        'p_phone': phone,
        'p_password': password,
      },
    );
    if (response == null) return null;

    final staff = Map<String, dynamic>.from(response as Map);
    currentBusinessId = staff['business_id']?.toString();
    currentStaffNumber = staff['staff_number']?.toString();
    currentUserRole = staff['role']?.toString();
    _staffSessionToken = staff['token']?.toString();
    _resetStreamCaches();
    currentBusinessMaxStaff = (staff['max_staff_limit'] as num?)?.toInt() ?? 0;
    currentBusinessHasCashier = staff['has_cashier_module'] == true;
    if (currentBusinessId == null ||
        currentStaffNumber == null ||
        currentUserRole == null ||
        _staffSessionToken == null) {
      return null;
    }
    _session?.startStaffSession(
      businessId: currentBusinessId!,
      staffNumber: currentStaffNumber!,
      role: currentUserRole!,
      maxStaff: currentBusinessMaxStaff!,
      hasCashier: currentBusinessHasCashier!,
    );
    return currentUserRole;
  }

  static Future<void> logoutStaff() async {
    final token = _staffSessionToken;
    if (token != null) {
      try {
        await _supabase.rpc('logout_staff', params: {'p_token': token});
      } catch (_) {
        // Local logout must still complete if the network is unavailable.
      }
    }
    _staffSessionToken = null;
    _resetStreamCaches();
    currentStaffNumber = null;
    currentUserRole = null;
    currentBusinessMaxStaff = null;
    currentBusinessHasCashier = null;
    _session?.logoutStaff();
  }

  static void unbindSession() {
    currentBusinessId = null;
    _staffSessionToken = null;
    _resetStreamCaches();
    currentStaffNumber = null;
    currentUserRole = null;
    currentBusinessMaxStaff = null;
    currentBusinessHasCashier = null;
    _session?.logoutStaff();
    _session?.unbind();
  }

  // --- 2. API VERIFICATION & TICKETS ---
  /// Verifies a transaction against the backend canonical `/verify` endpoint.
  ///
  /// [providerOrEndpoint] accepts either a raw provider name ("telebirr") or a
  /// legacy endpoint path ("/verify-telebirr", "/verify/telebirr"); it is
  /// normalized to a lowercase provider before the request is sent.
  static Future<VerificationResult> verifyTransaction(
    String transactionId,
    String providerOrEndpoint, {
    required double expectedAmount,
    String? suffix,
    String? phoneNumber,
  }) async {
    try {
      final provider = _normalizeProvider(providerOrEndpoint);
      if (provider == null) {
        return VerificationResult(
          isSuccess: false,
          errorMessage: 'Unknown provider: $providerOrEndpoint',
          errorCode: 'INVALID_PROVIDER',
        );
      }

      final String urlString = '$baseUrl/verify';

      final response = await http
          .post(
            Uri.parse(urlString),
            headers: {
              "Content-Type": "application/json",
              "Accept": "application/json",
              "User-Agent": "VerifyMe/1.0",
            },
            body: jsonEncode({
              "reference": transactionId.trim().toUpperCase(),
              "provider": provider,
              "expectedAmount": expectedAmount,
              if (suffix != null && suffix.trim().isNotEmpty)
                "suffix": suffix.trim(),
              if (phoneNumber != null && phoneNumber.trim().isNotEmpty)
                "phoneNumber": phoneNumber.trim(),
            }),
          )
          .timeout(const Duration(seconds: 20));

      // Handle Success (200 or 201) from the Express routes
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);

        if (data['success'] == true || data['status'] == 'success') {
          return VerificationResult(isSuccess: true, data: data);
        }
        return VerificationResult(
          isSuccess: false,
          errorMessage:
              (data['error'] ??
                      data['message'] ??
                      'API rejected the transaction.')
                  .toString(),
          errorCode: data['code']?.toString(),
        );
      }

      // Handle Route and Validation Errors (400, 404, 500)
      try {
        final data = jsonDecode(response.body);
        final serverError =
            (data['error'] ??
                    data['message'] ??
                    'Server error: ${response.statusCode}')
                .toString();
        return VerificationResult(
          isSuccess: false,
          errorMessage: serverError,
          errorCode: data['code']?.toString(),
          retryable: data['retryable'] == true,
          retryAfterSeconds: (data['retryAfterSeconds'] as num?)?.toInt(),
        );
      } catch (_) {
        return VerificationResult(
          isSuccess: false,
          errorMessage:
              'HTTP Error: ${response.statusCode}. Check route paths.',
        );
      }
    } catch (e) {
      return VerificationResult(
        isSuccess: false,
        errorMessage: 'Connection Failed: $e',
        errorCode: 'CONNECTION_FAILED',
        retryable: true,
      );
    }
  }

  /// Server-authoritative production workflow. The backend validates this
  /// staff session, calls the provider, checks the tenant's receiving account,
  /// and atomically commits immutable evidence plus the pending ticket.
  static Future<VerificationResult> verifyAndCreateTicket({
    required String transactionId,
    required String provider,
    required double expectedAmount,
    required String tableNumber,
    Uint8List? receiptImageBytes,
  }) async {
    final normalizedProvider = _normalizeProvider(provider);
    if (normalizedProvider == null) {
      return VerificationResult(
        isSuccess: false,
        errorMessage: 'Unknown provider: $provider',
        errorCode: 'INVALID_PROVIDER',
      );
    }
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/verify-and-create'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer ${_requireSessionToken()}',
              'User-Agent': 'CHEKMI/1.0',
            },
            body: jsonEncode({
              'reference': transactionId.trim().toUpperCase(),
              'provider': normalizedProvider,
              'expectedAmount': expectedAmount,
              'tableNumber': tableNumber.trim(),
              if (receiptImageBytes != null)
                'receiptImageBase64': base64Encode(receiptImageBytes),
            }),
          )
          .timeout(const Duration(seconds: 35));
      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return VerificationResult(isSuccess: true, data: decoded);
      }
      return VerificationResult(
        isSuccess: false,
        errorMessage:
            decoded['error']?.toString() ??
            'Verification failed (${response.statusCode}).',
        errorCode: decoded['code']?.toString(),
        retryable: decoded['retryable'] == true,
        retryAfterSeconds: (decoded['retryAfterSeconds'] as num?)?.toInt(),
        data: decoded,
      );
    } on TimeoutException {
      return VerificationResult(
        isSuccess: false,
        errorMessage: 'Verification timed out. Check before retrying.',
        errorCode: 'TIMEOUT',
        retryable: true,
      );
    } catch (error) {
      return VerificationResult(
        isSuccess: false,
        errorMessage: 'Connection failed: $error',
        errorCode: 'CONNECTION_FAILED',
        retryable: true,
      );
    }
  }

  /// Normalizes a provider name or legacy endpoint path to a known provider.
  /// Accepts "telebirr", "Telebirr", "/verify-telebirr", "/verify/telebirr".
  static String? _normalizeProvider(String input) {
    final s = input.trim().toLowerCase().replaceAll('-', '/');
    final segments = s
        .split('/')
        .where((p) => p.isNotEmpty && p != 'verify')
        .toList();
    final candidate = segments.isNotEmpty ? segments.last : s;
    switch (candidate) {
      case 'telebirr':
      case 'cbe':
      case 'cbebirr':
      case 'dashen':
      case 'abyssinia':
      case 'mpesa':
        return candidate;
      default:
        return null;
    }
  }

  static Future<Map<String, dynamic>?> fetchReceiptImage(
    String ticketId,
  ) async {
    final response = await _supabase.rpc(
      'get_receipt_image',
      params: {'p_token': _requireSessionToken(), 'p_ticket_id': ticketId},
    );
    return response is Map ? Map<String, dynamic>.from(response) : null;
  }

  /// Settlement uses the provider-confirmed amount already stored with the
  /// immutable evidence. The cashier supplies only an auditable reason.
  static Future<void> settleTicket({
    required String ticketId,
    required String reason,
  }) async {
    await _transitionTicket(
      ticketId: ticketId,
      status: 'settled',
      reason: reason,
    );
  }

  static Future<void> rejectTicket({
    required String ticketId,
    required String reason,
  }) async {
    await _transitionTicket(
      ticketId: ticketId,
      status: 'rejected',
      reason: reason,
    );
  }

  // --- 3. BACKEND-FILTERED DATA STREAMS ---
  static Stream<Map<String, dynamic>> streamCurrentBusiness() {
    return _businessStream ??= _replayLatest(_pollCurrentBusiness());
  }

  /// One-shot business lookup for critical workflows. Verification must not
  /// depend on Supabase Realtime being enabled for the businesses table.
  static Future<Map<String, dynamic>> fetchCurrentBusiness() async {
    final response = await _supabase.rpc(
      'get_current_business',
      params: {'p_token': _requireSessionToken()},
    );
    return Map<String, dynamic>.from(response as Map);
  }

  static Stream<List<Map<String, dynamic>>> streamAllBusinesses() {
    throw UnsupportedError(
      'Platform administration requires the protected operator console.',
    );
  }

  static Stream<Map<String, dynamic>> _pollCurrentBusiness() async* {
    String? previousPayload;
    while (_staffSessionToken != null) {
      final business = await fetchCurrentBusiness();
      final payload = jsonEncode(business);
      if (payload != previousPayload) {
        previousPayload = payload;
        yield business;
      }
      await Future<void>.delayed(const Duration(seconds: 5));
    }
  }

  static Stream<List<Map<String, dynamic>>> streamTodayTickets() {
    return _ticketPollingStream('business');
  }

  static Stream<List<Map<String, dynamic>>> streamWaiterTickets() {
    if (currentBusinessId == null || currentStaffNumber == null) {
      return const Stream.empty();
    }
    return _ticketPollingStream('waiter');
  }

  static Stream<List<Map<String, dynamic>>> streamPendingTickets() {
    if (currentBusinessId == null) return const Stream.empty();
    return _ticketPollingStream(
      'business',
    ).map((tickets) => tickets.where((t) => t['status'] == 'pending').toList());
  }

  static Stream<List<Map<String, dynamic>>> streamSettledTickets() {
    if (currentBusinessId == null) return const Stream.empty();
    return _ticketPollingStream(
      'business',
    ).map((tickets) => tickets.where((t) => t['status'] == 'settled').toList());
  }

  static Stream<List<Map<String, dynamic>>> streamTicketReport({
    DateTime? from,
    DateTime? to,
    String? staffNumber,
    String? provider,
  }) {
    return _replayLatest(
      _pollTicketReport(
        from: from,
        to: to,
        staffNumber: staffNumber,
        provider: provider,
      ),
    );
  }

  static Stream<List<Map<String, dynamic>>> _pollTicketReport({
    DateTime? from,
    DateTime? to,
    String? staffNumber,
    String? provider,
  }) async* {
    String? previousPayload;
    while (_staffSessionToken != null) {
      final response = await _supabase.rpc(
        'list_ticket_report',
        params: {
          'p_token': _requireSessionToken(),
          'p_from': from?.toUtc().toIso8601String(),
          'p_to': to?.toUtc().toIso8601String(),
          'p_staff_number': staffNumber,
          'p_provider': provider,
        },
      );
      final rows = (response as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      final payload = jsonEncode(rows);
      if (payload != previousPayload) {
        previousPayload = payload;
        yield rows;
      }
      await Future<void>.delayed(const Duration(seconds: 5));
    }
  }

  static Future<void> recordVerificationAttempt({
    required String provider,
    required String transactionRef,
    required double expectedAmount,
    double? verifiedAmount,
    double tipAmount = 0,
    required bool verified,
    String? errorMessage,
  }) async {
    await _supabase.rpc(
      'record_verification_attempt',
      params: {
        'p_token': _requireSessionToken(),
        'p_provider': _normalizeProvider(provider) ?? provider.toLowerCase(),
        'p_transaction_ref': transactionRef.trim().toUpperCase(),
        'p_expected_amount': expectedAmount,
        'p_verified_amount': verifiedAmount,
        'p_tip_amount': tipAmount,
        'p_outcome': verified ? 'verified' : 'failed',
        'p_error_message': errorMessage,
      },
    );
  }

  static Stream<List<Map<String, dynamic>>> streamMyVerificationAttempts() {
    return _shareWhileListening(_pollVerificationAttempts());
  }

  static Stream<List<Map<String, dynamic>>> _pollVerificationAttempts() async* {
    String? previousPayload;
    while (_staffSessionToken != null) {
      final response = await _supabase.rpc(
        'list_my_verification_attempts',
        params: {'p_token': _requireSessionToken()},
      );
      final rows = (response as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      final payload = jsonEncode(rows);
      if (payload != previousPayload) {
        previousPayload = payload;
        yield rows;
      }
      await Future<void>.delayed(const Duration(seconds: 5));
    }
  }

  static String _requireSessionToken() {
    final token = _staffSessionToken;
    if (token == null) {
      throw Exception('Session expired. Please sign in again.');
    }
    return token;
  }

  static Future<void> _transitionTicket({
    required String ticketId,
    required String status,
    required String reason,
  }) async {
    await _supabase.rpc(
      'transition_verified_ticket',
      params: {
        'p_token': _requireSessionToken(),
        'p_ticket_id': ticketId,
        'p_status': status,
        'p_reason': reason.trim(),
      },
    );
  }

  // Dashboard screens intentionally consume the same polling stream in more
  // than one StreamBuilder (for example, summary metrics and the ledger).
  // An async* stream is single-subscription by default, so expose it as a
  // broadcast stream to prevent "Stream has already been listened to" from
  // cascading into Flutter framework lifecycle assertions.
  static Stream<List<Map<String, dynamic>>> _ticketPollingStream(String scope) {
    return _ticketStreamCache.putIfAbsent(
      scope,
      () => _replayLatest(_pollTickets(scope)),
    );
  }

  static Stream<List<Map<String, dynamic>>> _pollTickets(String scope) async* {
    String? previousPayload;
    while (_staffSessionToken != null) {
      final response = await _supabase.rpc(
        'list_tickets',
        params: {'p_token': _requireSessionToken(), 'p_scope': scope},
      );
      final rows = (response as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      final payload = jsonEncode(rows);
      if (payload != previousPayload) {
        previousPayload = payload;
        yield rows;
      }
      await Future<void>.delayed(const Duration(seconds: 5));
    }
  }

  /// Shares one RPC poll between dashboard sections and tears it down as soon
  /// as the route's final listener is disposed. This prevents invisible
  /// dashboards from continuing to make requests after navigation.
  static Stream<T> _shareWhileListening<T>(Stream<T> source) {
    return source.asBroadcastStream(
      onCancel: (subscription) => unawaited(subscription.cancel()),
    );
  }

  /// Keeps a polling stream alive for the dashboard route and immediately
  /// replays its latest value when a tab is rebuilt.
  static Stream<T> _replayLatest<T>(Stream<T> source) {
    late StreamController<T> controller;
    StreamSubscription<T>? subscription;
    T? latest;
    var hasLatest = false;
    controller = StreamController<T>.broadcast(
      onListen: () {
        if (hasLatest) {
          scheduleMicrotask(() {
            if (!controller.isClosed) controller.add(latest as T);
          });
        }
        subscription ??= source.listen(
          (value) {
            latest = value;
            hasLatest = true;
            controller.add(value);
          },
          onError: controller.addError,
          onDone: controller.close,
        );
      },
    );
    return controller.stream;
  }

  static void _resetStreamCaches() {
    _ticketStreamCache.clear();
    _withdrawalRequestsStream = null;
    _staffRosterStream = null;
    _businessStream = null;
  }

  static Future<void> requestTipWithdrawal(double amount) async {
    await _supabase.rpc(
      'request_tip_withdrawal',
      params: {'p_token': _requireSessionToken(), 'p_amount': amount},
    );
  }

  static Future<void> resolveTipWithdrawal(
    String requestId,
    String status,
  ) async {
    await _supabase.rpc(
      'resolve_tip_withdrawal_request',
      params: {
        'p_token': _requireSessionToken(),
        'p_request_id': requestId,
        'p_status': status,
      },
    );
  }

  static Stream<List<Map<String, dynamic>>> streamTipWithdrawalRequests() {
    return _withdrawalRequestsStream ??= _replayLatest(
      _pollTipWithdrawalRequests(),
    );
  }

  static Stream<List<Map<String, dynamic>>>
  _pollTipWithdrawalRequests() async* {
    String? previousPayload;
    while (_staffSessionToken != null) {
      final response = await _supabase.rpc(
        'list_tip_withdrawal_requests',
        params: {'p_token': _requireSessionToken()},
      );
      final rows = (response as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      final payload = jsonEncode(rows);
      if (payload != previousPayload) {
        previousPayload = payload;
        yield rows;
      }
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  }

  static Stream<List<Map<String, dynamic>>> streamStaffRoster() {
    return _staffRosterStream ??= _replayLatest(_pollStaffRoster());
  }

  static Stream<List<Map<String, dynamic>>> _pollStaffRoster() async* {
    String? previousPayload;
    while (_staffSessionToken != null) {
      final response = await _supabase.rpc(
        'list_staff_roster',
        params: {'p_token': _requireSessionToken()},
      );
      final rows = (response as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      final payload = jsonEncode(rows);
      if (payload != previousPayload) {
        previousPayload = payload;
        yield rows;
      }
      await Future<void>.delayed(const Duration(seconds: 5));
    }
  }

  // --- 4. TENANT & STAFF MANAGEMENT ---
  static Future<void> changeCurrentAdminPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (currentUserRole != 'admin') {
      throw Exception('Only an administrator can change this password.');
    }

    await _supabase.rpc(
      'change_current_admin_password',
      params: {
        'p_token': _requireSessionToken(),
        'p_current_password': currentPassword,
        'p_new_password': newPassword,
      },
    );
  }

  static Future<void> openSupportCase({
    required String category,
    required String subject,
    required String description,
    String priority = 'normal',
  }) async {
    await _supabase.rpc(
      'open_support_case',
      params: {
        'p_token': _requireSessionToken(),
        'p_category': category,
        'p_subject': subject.trim(),
        'p_description': description.trim(),
        'p_priority': priority,
      },
    );
  }

  static Future<List<Map<String, dynamic>>> listMySupportCases() async {
    final response = await _supabase.rpc(
      'list_my_support_cases',
      params: {'p_token': _requireSessionToken()},
    );
    return (response as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  static Future<void> requestBusinessDeletion(String reason) async {
    await _supabase.rpc(
      'request_business_deletion',
      params: {'p_token': _requireSessionToken(), 'p_reason': reason.trim()},
    );
  }

  static Future<void> acceptLegalDocument({
    required String type,
    required String version,
  }) async {
    await _supabase.rpc(
      'accept_legal_document',
      params: {
        'p_token': _requireSessionToken(),
        'p_document_type': type,
        'p_version': version,
      },
    );
  }

  static Future<void> updateBankAccounts(Map<String, dynamic> accounts) async {
    await _supabase.rpc(
      'update_bank_accounts',
      params: {'p_token': _requireSessionToken(), 'p_accounts': accounts},
    );
  }

  static Future<void> provisionNewBusiness({
    required String businessName,
    required String businessCode,
    required String packageTier,
    required int maxStaff,
    required bool hasCashier,
    required String adminName,
    required String adminPhone,
    required String adminPassword,
    required String adminPin,
  }) async {
    throw UnsupportedError(
      'Tenant provisioning is available only in the protected operator console.',
    );
  }

  static Future<void> updateBusinessDetails(
    String businessId,
    String newName,
    String newTier,
    int newLimit,
    bool hasCashier,
  ) async {
    throw UnsupportedError(
      'Tenant changes require the protected operator console.',
    );
  }

  static Future<void> toggleBusinessStatus(
    String businessId,
    bool targetStatus,
  ) async {
    throw UnsupportedError(
      'Tenant status changes require the protected operator console.',
    );
  }

  static Future<void> createStaffMember({
    required String pin,
    required String name,
    required String phone,
    required String password,
    required String role,
  }) async {
    await _supabase.rpc(
      'create_staff_member',
      params: {
        'p_token': _requireSessionToken(),
        'p_staff_number': pin,
        'p_name': name,
        'p_phone': phone,
        'p_password': password,
        'p_role': role,
      },
    );
  }

  static Future<void> updateStaffProfile(
    String pin,
    String newName,
    String newPhone,
    String newPassword,
    String newRole,
  ) async {
    await _supabase.rpc(
      'update_staff_member',
      params: {
        'p_token': _requireSessionToken(),
        'p_staff_number': pin,
        'p_name': newName,
        'p_phone': newPhone,
        'p_new_password': newPassword,
        'p_role': newRole,
      },
    );
  }

  static Future<void> toggleStaffStatus(String pin, bool targetStatus) async {
    await _supabase.rpc(
      'set_staff_active',
      params: {
        'p_token': _requireSessionToken(),
        'p_staff_number': pin,
        'p_active': targetStatus,
      },
    );
  }
}
