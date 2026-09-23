import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:verify_me/core/services/payment_verification_client.dart';

void main() {
  test('missing Supabase deployment has an actionable setup error', () {
    final result = PaymentVerificationClient.decode(
      http.Response(
        '{"code":"NOT_FOUND","message":"Requested function was not found"}',
        404,
      ),
    );
    expect(result.isSuccess, false);
    expect(result.errorCode, 'SERVICE_NOT_DEPLOYED');
    expect(
      result.displayErrorMessage,
      contains('deploy the chekmi-verify function'),
    );
  });
  test(
    'only a successful saved-payment response can show verification success',
    () {
      for (final body in [
        {'success': false, 'error': 'Not verified'},
        {
          'success': true,
          'data': {'amount': 600},
        },
        {
          'success': true,
          'data': {'ticket_id': ''},
        },
        {
          'data': {'ticket_id': 'saved'},
        },
      ]) {
        expect(
          PaymentVerificationClient.decode(http.Response(jsonEncode(body), 200))
              .isSuccess,
          false,
        );
      }
      expect(
        PaymentVerificationClient.decode(
          http.Response('{"success":true,"data":{"ticket_id":"saved"}}', 201),
        ).isSuccess,
        true,
      );
    },
  );

  test(
    'HTML hosting errors produce a deployment error rather than Still checking',
    () {
      final result = PaymentVerificationClient.decode(
        http.Response('<!doctype html><title>App unavailable</title>', 503),
      );
      expect(result.isSuccess, false);
      expect(result.errorCode, 'INVALID_SERVICE_RESPONSE');
      expect(result.displayErrorMessage, contains('not deployed'));
      expect(result.displayErrorMessage, isNot(contains('Still checking')));
    },
  );

  test(
    'timeout reads saved status without repeating the paid verification',
    () async {
      final sent = <Map<String, dynamic>>[];
      final transport = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        sent.add(body);
        expect(request.url.host, 'project.supabase.co');
        expect(request.headers['x-api-key'], isNull);
        if (body['action'] != 'status') {
          throw TimeoutException('simulated lost response');
        }
        return http.Response(
          '{"success":true,"data":{"ticket_id":"saved","recovered":true}}',
          200,
        );
      });
      final verifier = PaymentVerificationClient(
        client: transport,
        endpoint: Uri.parse(
          'https://project.supabase.co/functions/v1/chekmi-verify',
        ),
        supportsStatus: true,
      );
      final result = await verifier.verify(
        token: 'staff-session',
        publicKey: 'public-project-key',
        body: {
          'provider': 'telebirr',
          'reference': 'DHU5AM9UB3',
          'expectedAmount': 550,
        },
      );
      expect(result.isSuccess, true);
      expect(sent, hasLength(2));
      expect(sent.last, {
        'action': 'status',
        'provider': 'telebirr',
        'reference': 'DHU5AM9UB3',
      });
    },
  );

  test('a timeout without a saved payment never becomes success', () async {
    final transport = MockClient((request) async {
      if (!request.body.contains('status')) {
        throw TimeoutException('lost response');
      }
      return http.Response('{"success":false,"code":"NOT_COMMITTED"}', 200);
    });
    final result =
        await PaymentVerificationClient(
          client: transport,
          endpoint: Uri.parse(
            'https://project.supabase.co/functions/v1/chekmi-verify',
          ),
          supportsStatus: true,
        ).verify(
          token: 'staff-session',
          publicKey: 'public',
          body: {'reference': 'DHU5AM9UB3', 'provider': 'telebirr'},
        );
    expect(result.isSuccess, false);
    expect(result.errorCode, 'TIMEOUT');
    expect(result.displayErrorMessage, contains('No payment confirmation'));
  });
}
