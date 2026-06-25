import 'dart:convert';
import 'package:http/http.dart' as http;

class VerificationResult {
  final bool isSuccess;
  final String? errorMessage;
  final Map<String, dynamic>? data;

  VerificationResult({required this.isSuccess, this.errorMessage, this.data});
}

class ApiService {
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
}