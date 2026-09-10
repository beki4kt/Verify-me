import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../../offline_storage.dart';
import '../config/app_environment.dart';

class DemoVerificationClient {
  DemoVerificationClient({
    http.Client? client,
    Future<String> Function()? token,
    Uri? endpoint,
  }) : _client = client ?? http.Client(),
       _token = token ?? DeviceStorage.demoInstallationToken,
       _endpoint =
           endpoint ??
           Uri.parse('${AppEnvironment.supabaseUrl}/functions/v1/chekmi-demo');
  final http.Client _client;
  final Future<String> Function() _token;
  final Uri _endpoint;
  String? _lookupId;
  bool _busy = false;
  void close() => _client.close();
  Future<Map<String, dynamic>> _send(Map<String, dynamic> body) async {
    final response = await _client
        .post(
          _endpoint,
          headers: {
            'Content-Type': 'application/json',
            'apikey': AppEnvironment.supabasePublishableKey,
          },
          body: jsonEncode({...body, 'installationToken': await _token()}),
        )
        .timeout(const Duration(seconds: 50));
    if (response.statusCode == 404) {
      throw Exception(
        'The demo scanner needs to be deployed. Please try again after setup.',
      );
    }
    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic> || data['demo'] != true) {
      throw Exception('The demo service returned an invalid response.');
    }
    return data;
  }

  Future<Map<String, dynamic>> usage() => _send({'action': 'usage'});
  Future<Map<String, dynamic>> checkResult() {
    if (_lookupId == null) return usage();
    return _send({'action': 'status', 'lookupId': _lookupId});
  }

  Future<Map<String, dynamic>> verify({
    required String provider,
    required String reference,
    String receivingAccount = '',
  }) async {
    if (_busy) throw StateError('A demo verification is already running.');
    _busy = true;
    final random = Random.secure();
    final hex = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    _lookupId =
        '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    try {
      return await _send({
        'action': 'verify',
        'lookupId': _lookupId,
        'provider': provider,
        'reference': reference.trim(),
        'receivingAccount': receivingAccount.trim(),
      });
    } catch (_) {
      // Never repeat a paid lookup after an uncertain response.
      try {
        return await checkResult();
      } catch (_) {
        throw Exception(
          'No demo result received. Use Check result before starting another check.',
        );
      }
    } finally {
      _busy = false;
    }
  }
}
