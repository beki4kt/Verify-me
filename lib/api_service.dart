import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'offline_storage.dart';
import 'core/session/session_controller.dart';

class VerificationResult {
  final bool isSuccess;
  final String? errorMessage;
  final Map<String, dynamic>? data;
  VerificationResult({required this.isSuccess, this.errorMessage, this.data});
}

class ApiService {
  // --- LOCAL MACHINE TESTING CONFIGURATION ---
  // Replace "192.168.1.X" with your actual computer's local IP address so your physical phone can connect!
  static const String _configuredBaseUrl = String.fromEnvironment(
    'VERIFY_ME_API_URL',
    defaultValue: 'http://172.20.10.4:3000/api',
  );

  // 0.0.0.0 is a server bind address, never a destination a phone can call.
  // Fall back to the current development machine if an old launch profile
  // accidentally injects it at build time.
  static const String baseUrl = _configuredBaseUrl == 'http://0.0.0.0:3000/api'
      ? 'http://172.20.10.4:3000/api'
      : _configuredBaseUrl;

  // Keep your live domain here as a comment for when you switch to production:
  // static const String baseUrl = "https://verifyapi.leulzenebe.pro/api";

  static final _supabase = Supabase.instance.client;
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

  // --- 1. AUTHENTICATION & BUSINESS LAYER ---

  static Future<Map<String, dynamic>?> verifyBusinessCode(String code) async {
    final response = await _supabase
        .from('businesses')
        .select('business_id, name, business_code, is_active')
        .eq('business_code', code.toUpperCase())
        .maybeSingle();

    if (response == null) throw Exception("Invalid Business Code.");
    if (response['is_active'] != true) {
      throw Exception("This business account is currently suspended.");
    }

    return response;
  }

  static Future<String?> loginStaffUnderBusiness(
    String lockedBusinessId,
    String phone,
    String password,
  ) async {
    final superAdminCheck = await _supabase
        .from('super_admins')
        .select()
        .eq('phone_number', phone)
        .eq('password', password)
        .maybeSingle();
    if (superAdminCheck != null) {
      currentUserRole = 'super_admin';
      return 'super_admin';
    }

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
    currentStaffNumber = null;
    currentUserRole = null;
    currentBusinessMaxStaff = null;
    currentBusinessHasCashier = null;
    _session?.logoutStaff();
  }

  static void unbindSession() {
    currentBusinessId = null;
    _staffSessionToken = null;
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
          errorMessage: response.statusCode == 503 ? serverError : serverError,
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

  static Future<void> submitVerifiedTicket({
    required String transactionId,
    required String amount,
    required String bankName,
    required String tableNumber,
    double tipAmount = 0.0,
  }) async {
    if (currentBusinessId == null || currentStaffNumber == null) {
      throw Exception("Session expired.");
    }

    final ticketData = {
      'business_id': currentBusinessId,
      'waiter_id': currentStaffNumber,
      'table_number': tableNumber.trim(),
      'transaction_ref': transactionId,
      'bill_amount':
          double.tryParse(
            amount.replaceAll(',', '').replaceAll('ETB', '').trim(),
          ) ??
          0.0,
      'tip_amount': tipAmount,
      'bank': bankName,
      'status': 'pending',
    };

    try {
      await _supabase
          .rpc(
            'create_ticket',
            params: {
              'p_token': _requireSessionToken(),
              'p_transaction_ref': ticketData['transaction_ref'],
              'p_bill_amount': ticketData['bill_amount'],
              'p_bank': ticketData['bank'],
              'p_table_number': ticketData['table_number'],
              'p_tip_amount': ticketData['tip_amount'],
            },
          )
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      final text = e.toString();
      final networkFailure =
          e is TimeoutException ||
          e is SocketException ||
          text.contains('SocketException') ||
          text.contains('timed out') ||
          text.contains('Failed host lookup');
      if (!networkFailure) {
        throw Exception('Ticket database error: $text');
      }
      await SyncManager.instance.saveOfflineTicket(ticketData);
      throw Exception(
        "Network unavailable. Ticket saved locally and will sync automatically.",
      );
    }
  }

  static Future<void> updateTicketStatus(String ticketId, String status) async {
    await _transitionTicket(ticketId: ticketId, status: status);
  }

  /// Settle a ticket: marks it `settled` with the actual paid amount + tip.
  /// Fixes the prior bug where the cashier updated on `id` instead of `ticket_id`.
  // TODO(schema): once the `settled_by`/`settled_at` migration is applied to
  // the live Supabase project, add those fields here for an audit trail.
  static Future<void> settleTicket({
    required String ticketId,
    required double actualAmount,
    required double tipAmount,
  }) async {
    await _transitionTicket(
      ticketId: ticketId,
      status: 'settled',
      actualAmount: actualAmount,
      tipAmount: tipAmount,
    );
  }

  /// Reject a ticket (shortfall / fraud).
  static Future<void> rejectTicket(String ticketId) async {
    await _transitionTicket(ticketId: ticketId, status: 'rejected');
  }

  // --- 3. BACKEND-FILTERED DATA STREAMS ---
  static Stream<Map<String, dynamic>> streamCurrentBusiness() {
    if (currentBusinessId == null) throw Exception("No session");
    return _supabase
        .from('businesses')
        .stream(primaryKey: ['business_id'])
        .eq('business_id', currentBusinessId!)
        .map((list) => list.first);
  }

  /// One-shot business lookup for critical workflows. Verification must not
  /// depend on Supabase Realtime being enabled for the businesses table.
  static Future<Map<String, dynamic>> fetchCurrentBusiness() async {
    if (currentBusinessId == null) {
      throw Exception('No active business session');
    }
    return await _supabase
        .from('businesses')
        .select()
        .eq('business_id', currentBusinessId!)
        .single();
  }

  static Stream<List<Map<String, dynamic>>> streamAllBusinesses() {
    return _supabase
        .from('businesses')
        .stream(primaryKey: ['business_id'])
        .order('created_at', ascending: false);
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
    double? actualAmount,
    double? tipAmount,
  }) async {
    await _supabase.rpc(
      'transition_ticket',
      params: {
        'p_token': _requireSessionToken(),
        'p_ticket_id': ticketId,
        'p_status': status,
        'p_actual_amount': actualAmount,
        'p_tip_amount': tipAmount,
      },
    );
  }

  // Dashboard screens intentionally consume the same polling stream in more
  // than one StreamBuilder (for example, summary metrics and the ledger).
  // An async* stream is single-subscription by default, so expose it as a
  // broadcast stream to prevent "Stream has already been listened to" from
  // cascading into Flutter framework lifecycle assertions.
  static Stream<List<Map<String, dynamic>>> _ticketPollingStream(String scope) {
    return _shareWhileListening(_pollTickets(scope));
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

  static Stream<List<Map<String, dynamic>>> streamStaffRoster() {
    if (currentBusinessId == null) throw Exception("No active session");
    return _supabase
        .from('staff')
        .stream(primaryKey: ['staff_number'])
        .eq('business_id', currentBusinessId!)
        .order('created_at', ascending: false);
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

  static Future<void> updateBankAccounts(Map<String, dynamic> accounts) async {
    if (currentBusinessId == null) throw Exception("No session");
    await _supabase
        .from('businesses')
        .update({'bank_accounts': accounts})
        .eq('business_id', currentBusinessId!);
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
    final codeCheck = await _supabase
        .from('businesses')
        .select('business_code')
        .eq('business_code', businessCode)
        .maybeSingle();
    if (codeCheck != null) {
      throw Exception(
        "This Tenant Code is already in use by another restaurant.",
      );
    }

    final existingCheck = await _supabase
        .from('staff')
        .select('staff_number')
        .or('staff_number.eq.$adminPin,phone_number.eq.$adminPhone')
        .limit(1)
        .maybeSingle();
    if (existingCheck != null) {
      throw Exception("PIN or Phone Number is already in use.");
    }

    final businessResponse = await _supabase
        .from('businesses')
        .insert({
          'name': businessName,
          'business_code': businessCode,
          'subscription_tier': packageTier,
          'max_staff_limit': maxStaff,
          'has_cashier_module': hasCashier,
          'is_active': true,
        })
        .select()
        .single();

    await _supabase.from('staff').insert({
      'staff_number': adminPin,
      'business_id': businessResponse['business_id'],
      'name': adminName,
      'phone_number': adminPhone,
      'password': adminPassword,
      'role': 'admin',
      'is_active': true,
    });
  }

  static Future<void> updateBusinessDetails(
    String businessId,
    String newName,
    String newTier,
    int newLimit,
    bool hasCashier,
  ) async {
    await _supabase
        .from('businesses')
        .update({
          'name': newName,
          'subscription_tier': newTier,
          'max_staff_limit': newLimit,
          'has_cashier_module': hasCashier,
        })
        .eq('business_id', businessId);
  }

  static Future<void> toggleBusinessStatus(
    String businessId,
    bool targetStatus,
  ) async {
    await _supabase
        .from('businesses')
        .update({'is_active': targetStatus})
        .eq('business_id', businessId);
  }

  static Future<void> createStaffMember({
    required String pin,
    required String name,
    required String phone,
    required String password,
    required String role,
  }) async {
    if (currentBusinessId == null) {
      throw Exception("Fatal: Session disconnected.");
    }

    if (role == 'cashier' && currentBusinessHasCashier != true) {
      throw Exception("Starter Plan Restriction: Cashier module is disabled.");
    }

    final staffCount = await _supabase
        .from('staff')
        .count(CountOption.exact)
        .eq('business_id', currentBusinessId!);
    if (staffCount >= (currentBusinessMaxStaff ?? 0)) {
      throw Exception("SaaS Limit Reached: Seat Upgrade Required.");
    }

    final duplicateCheck = await _supabase
        .from('staff')
        .select('staff_number')
        .or('staff_number.eq.$pin,phone_number.eq.$phone')
        .limit(1)
        .maybeSingle();
    if (duplicateCheck != null) {
      throw Exception("Floor ID or Phone Number is already in use.");
    }

    await _supabase.from('staff').insert({
      'staff_number': pin,
      'business_id': currentBusinessId,
      'name': name,
      'phone_number': phone,
      'password': password,
      'role': role,
      'is_active': true,
    });
  }

  static Future<void> updateStaffProfile(
    String pin,
    String newName,
    String newPhone,
    String newPassword,
    String newRole,
  ) async {
    if (currentBusinessId == null) throw Exception("Session disconnected.");
    await _supabase
        .from('staff')
        .update({
          'name': newName,
          'phone_number': newPhone,
          'password': newPassword,
          'role': newRole,
        })
        .eq('staff_number', pin)
        .eq('business_id', currentBusinessId!);
  }

  static Future<void> toggleStaffStatus(String pin, bool targetStatus) async {
    if (currentBusinessId == null) throw Exception("No active session");
    await _supabase
        .from('staff')
        .update({'is_active': targetStatus})
        .eq('staff_number', pin)
        .eq('business_id', currentBusinessId!);
  }
}
