import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class VerificationResult {
  final bool isSuccess;
  final String? errorMessage;
  final Map<String, dynamic>? data;

  VerificationResult({required this.isSuccess, this.errorMessage, this.data});
}

class ApiService {
  // ==========================================
  // EXTERNAL API: RECEIPT VERIFICATION
  // ==========================================
  static const String baseUrl = "https://verifyapi.leulzenebe.pro";
  static const String apiKey = "sk_live_7ebe516799b67c8a30b6861a4131caca8d1ae6bce7f3a6b9";

  static Future<VerificationResult> verifyTransaction(String transactionId, String endpoint) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "x-api-key": apiKey,
          "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        },
        body: jsonEncode({"reference": transactionId}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true || data['status'] == 'success') {
           return VerificationResult(isSuccess: true, data: data);
        } else {
           return VerificationResult(isSuccess: false, errorMessage: data['message'] ?? 'Verification failed');
        }
      } else {
        final data = jsonDecode(response.body);
        return VerificationResult(isSuccess: false, errorMessage: data['error'] ?? data['message'] ?? 'Server rejected the request');
      }
    } catch (e) {
      return VerificationResult(isSuccess: false, errorMessage: 'Network Error.');
    }
  }

  // ==========================================
  // INTERNAL API: SUPABASE SaaS CONTROLS
  // ==========================================
  static final _supabase = Supabase.instance.client;

  static String? currentBusinessId;
  static String? currentStaffNumber;
  static String? currentUserRole;
  static int? currentBusinessMaxStaff; 

  // --- PIN LOGIN (For Floor Staff) ---
  static Future<Map<String, dynamic>?> loginWithPin(String pin) async {
    final response = await _supabase
        .from('staff')
        .select('*, businesses(max_staff_limit, is_active)')
        .eq('staff_number', pin)
        .maybeSingle();

    if (response != null && response['is_active'] == true && response['businesses']['is_active'] == true) {
      currentBusinessId = response['business_id'];
      currentStaffNumber = response['staff_number'];
      currentUserRole = response['role'];
      currentBusinessMaxStaff = response['businesses']['max_staff_limit'];
      return response;
    }
    return null;
  }

  // --- PHONE LOGIN (For Super Admins & Managers) ---
  static Future<String?> loginWithPhone(String phone, String password) async {
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

    final adminCheck = await _supabase
        .from('staff')
        .select('*, businesses(max_staff_limit, is_active)')
        .eq('phone_number', phone)
        .eq('password', password)
        .eq('role', 'admin')
        .maybeSingle();

    if (adminCheck != null && adminCheck['is_active'] == true && adminCheck['businesses']['is_active'] == true) {
      currentBusinessId = adminCheck['business_id'];
      currentStaffNumber = adminCheck['staff_number'];
      currentUserRole = adminCheck['role'];
      currentBusinessMaxStaff = adminCheck['businesses']['max_staff_limit'];
      return 'admin';
    }
    return null;
  }

  // ==========================================
  // SUPER ADMIN SPECIFIC FUNCTIONS
  // ==========================================

  // Stream all restaurants in the system
  static Stream<List<Map<String, dynamic>>> streamAllBusinesses() {
    return _supabase.from('businesses').stream(primaryKey: ['business_id']).order('created_at', ascending: false);
  }

  // The Master Provisioning Logic (Dual-Insert)
  static Future<void> provisionNewBusiness({
    required String businessName,
    required String packageTier,
    required int maxStaff,
    required String adminName,
    required String adminPhone,
    required String adminPassword,
    required String adminPin,
  }) async {
    // 1. Create the Tenant
    final businessResponse = await _supabase.from('businesses').insert({
      'name': businessName,
      'package_tier': packageTier,
      'max_staff_limit': maxStaff,
      'is_active': true,
    }).select().single();

    final newBusinessId = businessResponse['business_id'];

    // 2. Create the Master Admin for this Tenant
    await _supabase.from('staff').insert({
      'staff_number': adminPin,
      'business_id': newBusinessId,
      'name': adminName,
      'phone_number': adminPhone,
      'password': adminPassword,
      'role': 'admin',
      'is_active': true,
    });
  }

  // The Global Kill Switch
  static Future<void> toggleBusinessStatus(String businessId, bool currentStatus) async {
    await _supabase.from('businesses').update({'is_active': !currentStatus}).eq('business_id', businessId);
  }

  // ==========================================
  // RESTAURANT ADMIN & STAFF FUNCTIONS
  // ==========================================
  
  static Stream<List<Map<String, dynamic>>> streamTodayTickets() {
    if (currentBusinessId == null) throw Exception("No active session");
    return _supabase.from('tickets').stream(primaryKey: ['ticket_id']).eq('business_id', currentBusinessId!).order('created_at', ascending: false).limit(100); 
  }

  static Stream<List<Map<String, dynamic>>> streamStaffRoster() {
    if (currentBusinessId == null) throw Exception("No active session");
    return _supabase.from('staff').stream(primaryKey: ['staff_number']).eq('business_id', currentBusinessId!).order('created_at', ascending: false);
  }

  static Future<void> createStaffMember({
    required String pin,
    required String name,
    required String role,
  }) async {
    if (currentBusinessId == null) throw Exception("No active session");

    final countResponse = await _supabase.from('staff').select('staff_number').eq('business_id', currentBusinessId!).count(CountOption.exact);
    if ((countResponse.count ?? 0) >= (currentBusinessMaxStaff ?? 0)) {
      throw Exception("Upgrade Required: Limit Reached.");
    }

    await _supabase.from('staff').insert({
      'staff_number': pin,
      'business_id': currentBusinessId,
      'name': name,
      'role': role,
      'is_active': true,
    });
  }

  static Future<void> toggleStaffStatus(String pin, bool currentStatus) async {
    if (currentBusinessId == null) throw Exception("No active session");
    await _supabase.from('staff').update({'is_active': !currentStatus}).eq('staff_number', pin).eq('business_id', currentBusinessId!); 
  }
}