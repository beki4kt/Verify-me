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
}
