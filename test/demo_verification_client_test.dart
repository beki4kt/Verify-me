import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:verify_me/core/services/demo_verification_client.dart';

void main() {
  test(
    'demo timeout recovers with status only and never sends a staff session',
    () async {
      final actions = <String>[];
      String? requestId;
      final client = DemoVerificationClient(
        token: () async => 'a' * 64,
        client: MockClient((request) async {
          expect(request.headers.containsKey('authorization'), false);
          expect(request.headers.containsKey('x-api-key'), false);
          final body = jsonDecode(request.body);
          actions.add(body['action']);
          if (body['action'] == 'verify') {
            requestId = body['lookupId'];
            throw TimeoutException('lost response');
          }
          expect(body['lookupId'], requestId);
          return http.Response(
            jsonEncode({
              'demo': true,
              'success': true,
              'remaining': 9,
              'receipt': {'amount': 100},
            }),
            200,
          );
        }),
      );
      final result = await client.verify(
        provider: 'telebirr',
        reference: 'DI82JQ406M',
      );
      expect(result['success'], true);
      expect(actions, ['verify', 'status']);
      client.close();
    },
  );

  test(
    'missing demo endpoint is reported without repeating a verification',
    () async {
      var calls = 0;
      final client = DemoVerificationClient(
        token: () async => 'a' * 64,
        endpoint: Uri.parse('https://example.test/functions/v1/chekmi-demo'),
        client: MockClient((_) async {
          calls++;
          return http.Response('{"code":"NOT_FOUND"}', 404);
        }),
      );

      await expectLater(
        client.verify(provider: 'telebirr', reference: 'DI82JQ406M'),
        throwsA(isA<DemoServiceUnavailable>()),
      );
      expect(calls, 1);
      client.close();
    },
  );

  test(
    'a rejected demo receipt keeps the server error and does not retry',
    () async {
      var calls = 0;
      final client = DemoVerificationClient(
        token: () async => 'a' * 64,
        endpoint: Uri.parse('https://example.test/functions/v1/chekmi-demo'),
        client: MockClient((_) async {
          calls++;
          return http.Response(
            '{"demo":true,"error":"Enter the receiving bank account shown on the receipt."}',
            400,
          );
        }),
      );

      await expectLater(
        client.verify(provider: 'cbe', reference: 'ABC123'),
        throwsA(
          isA<DemoRequestRejected>().having(
            (error) => error.message,
            'message',
            'Enter the receiving bank account shown on the receipt.',
          ),
        ),
      );
      expect(calls, 1);
      client.close();
    },
  );

  test(
    'demo setup failure does not become an uncertain-result error',
    () async {
      var calls = 0;
      final client = DemoVerificationClient(
        token: () async => 'a' * 64,
        client: MockClient((_) async {
          calls++;
          return http.Response(
            '{"demo":true,"code":"DEMO_NOT_CONFIGURED","error":"The demo scanner is not configured yet."}',
            503,
          );
        }),
      );
      await expectLater(
        client.verify(provider: 'telebirr', reference: 'DI82JQ406M'),
        throwsA(isA<DemoRequestRejected>()),
      );
      expect(calls, 1);
      client.close();
    },
  );
}
