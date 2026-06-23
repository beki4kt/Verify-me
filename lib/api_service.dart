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

  // Now requires the dynamic endpoint from the UI (e.g., '/verify-cbe' or '/verify-telebirr')
  static Future<VerificationResult> verifyTransaction(String transactionId, String endpoint) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'), 
        headers: {
          "Content-Type": "application/json",
          "x-api-key": apiKey, 
        },
        body: jsonEncode({"reference": transactionId}), 
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return VerificationResult(isSuccess: true, data: jsonDecode(response.body));
      } else {
        return VerificationResult(
          isSuccess: false, 
          errorMessage: "SERVER REJECTED:\nStatus Code: ${response.statusCode}\nBody: ${response.body}"
        );
      }
    } catch (e) {
      return VerificationResult(isSuccess: false, errorMessage: "NETWORK FAILURE:\n$e");
    }
  }
}