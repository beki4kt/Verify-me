import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'offline_storage.dart'; 

class VerificationResult {
  final bool isSuccess;
  final String? errorMessage;
  final Map<String, dynamic>? data;
  VerificationResult({required this.isSuccess, this.errorMessage, this.data});
}

class ApiService {
  static const String baseUrl = "https://verifyapi.leulzenebe.pro";
  static const String apiKey = "sk_live_7ebe516799b67c8a30b6861a4131caca8d1ae6bce7f3a6b9";
  static final _supabase = Supabase.instance.client;

  static String? currentBusinessId;
  static String? currentStaffNumber;
  static String? currentUserRole;
  static int? currentBusinessMaxStaff; 
  static bool? currentBusinessHasCashier; 

  // --- 1. AUTHENTICATION ---
  static Future<String?> loginWithPhone(String phone, String password) async {
    final superAdminCheck = await _supabase.from('super_admins').select().eq('phone_number', phone).eq('password', password).maybeSingle();
    if (superAdminCheck != null) { currentUserRole = 'super_admin'; return 'super_admin'; }
    
    final staffCheck = await _supabase.from('staff').select('*, businesses(max_staff_limit, is_active, has_cashier_module)').eq('phone_number', phone).eq('password', password).maybeSingle();
    
    if (staffCheck != null && staffCheck['is_active'] == true && staffCheck['businesses']['is_active'] == true) {
      currentBusinessId = staffCheck['business_id'];
      currentStaffNumber = staffCheck['staff_number']; 
      currentUserRole = staffCheck['role'];
      currentBusinessMaxStaff = staffCheck['businesses']['max_staff_limit'];
      currentBusinessHasCashier = staffCheck['businesses']['has_cashier_module'];
      return staffCheck['role'];
    }
    return null;
  }

  // --- 2. API VERIFICATION & TICKETS ---
  static Future<VerificationResult> verifyTransaction(String transactionId, String endpoint) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {"Content-Type": "application/json", "Accept": "application/json", "x-api-key": apiKey, "User-Agent": "Mozilla/5.0"},
        body: jsonEncode({"reference": transactionId}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true || data['status'] == 'success') return VerificationResult(isSuccess: true, data: data);
        return VerificationResult(isSuccess: false, errorMessage: data['message'] ?? 'Verification failed');
      }
      final data = jsonDecode(response.body);
      return VerificationResult(isSuccess: false, errorMessage: data['error'] ?? data['message'] ?? 'Server rejected');
    } catch (e) {
      return VerificationResult(isSuccess: false, errorMessage: 'Network Error.');
    }
  }

  static Future<void> submitVerifiedTicket({required String transactionId, required String amount, required String bankName}) async {
    if (currentBusinessId == null || currentStaffNumber == null) throw Exception("Session expired.");
    final ticketData = {
      'business_id': currentBusinessId, 'waiter_id': currentStaffNumber, 'transaction_ref': transactionId,
      'bill_amount': double.tryParse(amount.replaceAll(',', '').replaceAll('ETB', '').trim()) ?? 0.0, 'bank': bankName, 'status': 'pending', 
    };
    try {
      await _supabase.from('tickets').insert(ticketData).timeout(const Duration(seconds: 5));
    } catch (e) {
      await SyncManager.instance.saveOfflineTicket(ticketData);
      throw Exception("Network unavailable. Ticket saved locally and will sync automatically.");
    }
  }

  static Future<void> updateTicketStatus(String ticketId, String status) async {
    await _supabase.from('tickets').update({'status': status}).eq('ticket_id', ticketId);
  }

  // --- 3. DATA STREAMS ---
  static Stream<Map<String, dynamic>> streamCurrentBusiness() {
    if (currentBusinessId == null) throw Exception("No session");
    return _supabase.from('businesses').stream(primaryKey: ['business_id']).eq('business_id', currentBusinessId!).map((list) => list.first);
  }

  static Stream<List<Map<String, dynamic>>> streamAllBusinesses() {
    return _supabase.from('businesses').stream(primaryKey: ['business_id']).order('created_at', ascending: false);
  }

  static Stream<List<Map<String, dynamic>>> streamTodayTickets() {
    if (currentBusinessId == null) throw Exception("No active session");
    return _supabase.from('tickets').stream(primaryKey: ['ticket_id']).eq('business_id', currentBusinessId!).order('created_at', ascending: false).limit(100); 
  }

  static Stream<List<Map<String, dynamic>>> streamWaiterTickets() {
    if (currentBusinessId == null || currentStaffNumber == null) return const Stream.empty();
    // FIXED: Use .map() for secondary client-side filtering
    return _supabase
        .from('tickets')
        .stream(primaryKey: ['ticket_id'])
        .eq('business_id', currentBusinessId!)
        .order('created_at', ascending: false)
        .map((tickets) => tickets.where((t) => t['waiter_id'] == currentStaffNumber).toList());
  }

  static Stream<List<Map<String, dynamic>>> streamPendingTickets() {
    if (currentBusinessId == null) return const Stream.empty();
    // FIXED: Use .map() for secondary client-side filtering
    return _supabase
        .from('tickets')
        .stream(primaryKey: ['ticket_id'])
        .eq('business_id', currentBusinessId!)
        .order('created_at', ascending: false)
        .map((tickets) => tickets.where((t) => t['status'] == 'pending').toList());
  }

  static Stream<List<Map<String, dynamic>>> streamSettledTickets() {
    if (currentBusinessId == null) return const Stream.empty();
    // FIXED: Use .map() for secondary client-side filtering
    return _supabase
        .from('tickets')
        .stream(primaryKey: ['ticket_id'])
        .eq('business_id', currentBusinessId!)
        .order('created_at', ascending: false)
        .map((tickets) => tickets.where((t) => t['status'] == 'settled').toList());
  }

  static Stream<List<Map<String, dynamic>>> streamStaffRoster() {
    if (currentBusinessId == null) throw Exception("No active session");
    return _supabase.from('staff').stream(primaryKey: ['staff_number']).eq('business_id', currentBusinessId!).order('created_at', ascending: false);
  }

  // --- 4. TENANT & STAFF MANAGEMENT ---
  static Future<void> updateBankAccounts(Map<String, dynamic> accounts) async {
    if (currentBusinessId == null) throw Exception("No session");
    await _supabase.from('businesses').update({'bank_accounts': accounts}).eq('business_id', currentBusinessId!);
  }

  static Future<void> provisionNewBusiness({
    required String businessName, required String packageTier, required int maxStaff, required bool hasCashier,
    required String adminName, required String adminPhone, required String adminPassword, required String adminPin,
  }) async {
    final existingCheck = await _supabase.from('staff').select('staff_number').or('staff_number.eq.$adminPin,phone_number.eq.$adminPhone').limit(1).maybeSingle();
    if (existingCheck != null) throw Exception("PIN or Phone Number is already in use.");

    final businessResponse = await _supabase.from('businesses').insert({
      'name': businessName, 'package_tier': packageTier, 'max_staff_limit': maxStaff, 'has_cashier_module': hasCashier, 'is_active': true,
    }).select().single();

    await _supabase.from('staff').insert({
      'staff_number': adminPin, 'business_id': businessResponse['business_id'], 'name': adminName, 
      'phone_number': adminPhone, 'password': adminPassword, 'role': 'admin', 'is_active': true,
    });
  }

  static Future<void> updateBusinessDetails(String businessId, String newName, String newTier, int newLimit, bool hasCashier) async {
    await _supabase.from('businesses').update({'name': newName, 'package_tier': newTier, 'max_staff_limit': newLimit, 'has_cashier_module': hasCashier}).eq('business_id', businessId);
  }

  static Future<void> toggleBusinessStatus(String businessId, bool currentStatus) async {
    await _supabase.from('businesses').update({'is_active': !currentStatus}).eq('business_id', businessId);
  }

  static Future<void> createStaffMember({required String pin, required String name, required String phone, required String password, required String role}) async {
    if (currentBusinessId == null) throw Exception("Fatal: Session disconnected.");
    
    if (role == 'cashier' && currentBusinessHasCashier != true) {
      throw Exception("Starter Plan Restriction: Cashier module is disabled.");
    }
    
    final staffCount = await _supabase.from('staff').count(CountOption.exact).eq('business_id', currentBusinessId!);
    if (staffCount >= (currentBusinessMaxStaff ?? 0)) {
      throw Exception("SaaS Limit Reached: Seat Upgrade Required.");
    }

    final duplicateCheck = await _supabase.from('staff').select('staff_number').or('staff_number.eq.$pin,phone_number.eq.$phone').limit(1).maybeSingle();
    if (duplicateCheck != null) throw Exception("Floor ID or Phone Number is already in use.");

    await _supabase.from('staff').insert({
      'staff_number': pin, 'business_id': currentBusinessId, 'name': name, 'phone_number': phone, 'password': password, 'role': role, 'is_active': true,
    });
  }

  static Future<void> updateStaffProfile(String pin, String newName, String newPhone, String newPassword, String newRole) async {
    if (currentBusinessId == null) throw Exception("Session disconnected.");
    await _supabase.from('staff').update({'name': newName, 'phone_number': newPhone, 'password': newPassword, 'role': newRole}).eq('staff_number', pin).eq('business_id', currentBusinessId!);
  }

  static Future<void> toggleStaffStatus(String pin, bool currentStatus) async {
    if (currentBusinessId == null) throw Exception("No active session");
    await _supabase.from('staff').update({'is_active': !currentStatus}).eq('staff_number', pin).eq('business_id', currentBusinessId!); 
  }
}