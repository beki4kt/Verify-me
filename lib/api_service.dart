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
          // CRITICAL: This bypasses the OS Error 104 Connection Reset
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
  // INTERNAL API: SUPABASE ADMIN CONTROLS
  // ==========================================
  static final _supabase = Supabase.instance.client;

  // 1. Stream the real-time revenue stats for today
  static Stream<List<Map<String, dynamic>>> streamTodayTickets() {
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    return _supabase
        .from('tickets')
        .stream(primaryKey: ['ticket_id'])
        .gte('created_at', '${todayStr}T00:00:00Z');
  }

  // 2. Stream the complete staff roster
  static Stream<List<Map<String, dynamic>>> streamStaffRoster() {
    return _supabase
        .from('staff')
        .stream(primaryKey: ['staff_number'])
        .order('created_at', ascending: false);
  }

  // 3. Action: Provision a new team member
  static Future<void> createStaffMember({
    required String pin,
    required String name,
    required String role,
  }) async {
    await _supabase.from('staff').insert({
      'staff_number': pin,
      'name': name,
      'role': role,
      'is_active': true,
    });
  }

  // 4. Action: Toggle staff activation status
  static Future<void> toggleStaffStatus(String pin, bool currentStatus) async {
    await _supabase
        .from('staff')
        .update({'is_active': !currentStatus})
        .eq('staff_number', pin);
  }
}