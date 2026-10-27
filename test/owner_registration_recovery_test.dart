import 'package:flutter_test/flutter_test.dart';
import 'package:verify_me/core/services/owner_registration_recovery.dart';

void main() {
  test(
    'already committed owner request is returned without another create',
    () async {
      var creates = 0;
      final result = await requestOwnerWorkspaceIdempotently(
        lookup: () async => {
          'business_id': 'existing',
          'subscription_status': 'pending_activation',
        },
        create: () async {
          creates++;
          return {'business_id': 'duplicate'};
        },
      );
      expect(result['business_id'], 'existing');
      expect(creates, 0);
    },
  );

  test(
    'lost response recovers the committed request without a second create',
    () async {
      var reads = 0;
      var creates = 0;
      final result = await requestOwnerWorkspaceIdempotently(
        lookup: () async {
          reads++;
          return reads == 1 ? null : {'business_id': 'committed'};
        },
        create: () async {
          creates++;
          throw StateError('response lost');
        },
      );
      expect(result['business_id'], 'committed');
      expect(creates, 1);
    },
  );

  test(
    'a failed create with no committed workspace preserves its error',
    () async {
      await expectLater(
        requestOwnerWorkspaceIdempotently(
          lookup: () async => null,
          create: () async => throw StateError('registration rejected'),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'registration rejected',
          ),
        ),
      );
    },
  );
}
