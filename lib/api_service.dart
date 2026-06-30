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
  // BEREKET'S DOMAIN: EXTERNAL OCR VERIFICATION
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
      return VerificationResult(isSuccess: false, errorMessage: 'Network Error: Please check your connection.');
    }
  }

  // ==========================================
  // HENOK'S DOMAIN: INTERNAL SUPABASE SaaS CONTROLS
  // ==========================================
  static final _supabase = Supabase.instance.client;

  // Global Session State
  static String? currentBusinessId;
  static String? currentStaffNumber;
  static String? currentUserRole;
  static int? currentBusinessMaxStaff; 

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
// 1.5 Dual-Face Authentication: Phone & Password
  static Future<String?> loginWithPhone(String phone, String password) async {
    // Check 1: Is this the Developer / Super Admin?
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

    // Check 2: Is this a Restaurant Manager / Admin?
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

    return null; // Login failed
  }  

  static Stream<List<Map<String, dynamic>>> streamTodayTickets() {
    if (currentBusinessId == null) throw Exception("No active business session");
    
    return _supabase
        .from('tickets')
        .stream(primaryKey: ['ticket_id'])
        .eq('business_id', currentBusinessId!) 
        .order('created_at', ascending: false)
        .limit(100); 
  }

  static Stream<List<Map<String, dynamic>>> streamStaffRoster() {
    if (currentBusinessId == null) throw Exception("No active business session");

    return _supabase
        .from('staff')
        .stream(primaryKey: ['staff_number'])
        .eq('business_id', currentBusinessId!)
        .order('created_at', ascending: false);
  }

  static Future<void> createStaffMember({
    required String pin,
    required String name,
    required String role,
  }) async {
    if (currentBusinessId == null) throw Exception("No active business session");

    final countResponse = await _supabase.from('staff').select('staff_number').eq('business_id', currentBusinessId!).count(CountOption.exact);
    final currentStaffCount = countResponse.count ?? 0;

    if (currentStaffCount >= (currentBusinessMaxStaff ?? 0)) {
      throw Exception("Upgrade Required: Your business has reached its maximum staff limit of $currentBusinessMaxStaff.");
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
    if (currentBusinessId == null) throw Exception("No active business session");

    await _supabase
        .from('staff')
        .update({'is_active': !currentStatus})
        .eq('staff_number', pin)
        .eq('business_id', currentBusinessId!); 
  }
}