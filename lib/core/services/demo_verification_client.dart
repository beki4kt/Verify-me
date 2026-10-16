import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../../offline_storage.dart';
import '../config/app_environment.dart';

class DemoServiceUnavailable implements Exception {
  const DemoServiceUnavailable();

  @override
  String toString() =>
      'Demo checks are temporarily unavailable. The demo service has not been deployed.';
}

class DemoRequestRejected implements Exception {
  const DemoRequestRejected(this.message);

  final String message;

  @override
  String toString() => message;
}

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
      throw const DemoServiceUnavailable();
    }
    final Object? data;
    try {
      data = jsonDecode(response.body);
    } on FormatException {
      throw Exception('The demo service returned an unreadable response.');
    }
    if (data is! Map<String, dynamic> || data['demo'] != true) {
      throw Exception('The demo service returned an invalid response.');
    }
    if ((response.statusCode >= 400 && response.statusCode < 500) ||
        data['code'] == 'DEMO_NOT_CONFIGURED') {
      throw DemoRequestRejected(
        data['error']?.toString() ?? 'This demo check could not be accepted.',
      );
    }
    if (response.statusCode >= 500) {
      throw Exception(
        data['error']?.toString() ?? 'The demo service is unavailable.',
      );
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
    } on DemoServiceUnavailable {
      rethrow;
    } on DemoRequestRejected {
      rethrow;
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
