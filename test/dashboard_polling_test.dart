import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:verify_me/core/services/dashboard_polling.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'dashboard recovers after a failed poll and replays for late listeners',
    () async {
      var calls = 0;
      var gate = Completer<void>();
      final values = <int>[];
      final errors = <Object>[];
      final stream = dashboardPolling<int>(
        fetch: () async {
          if (++calls == 1) throw StateError('offline');
          return 7;
        },
        isActive: () => true,
        wait: () => gate.future,
      );
      final first = stream.listen(values.add, onError: errors.add);
      await flush();
      expect(errors, hasLength(1));
      final old = gate;
      gate = Completer<void>();
      old.complete();
      await flush();
      expect(values, [7]);
      final secondValues = <int>[];
      final second = stream.listen(secondValues.add);
      await flush();
      expect(secondValues, [7]);
      expect(calls, 2);
      await first.cancel();
      await second.cancel();
      gate.complete();
      await flush();
      expect(calls, 2);
    },
  );

  test(
    'dashboard discards an in-flight response after a session change',
    () async {
      var active = true;
      final response = Completer<int>();
      final values = <int>[];
      final stream = dashboardPolling<int>(
        fetch: () => response.future,
        isActive: () => active,
        wait: flush,
      );
      final subscription = stream.listen(values.add);
      active = false;
      response.complete(99);
      await flush();
      expect(values, isEmpty);
      await subscription.cancel();
    },
  );

  test(
    'dashboard resumes polling after all listeners leave and return',
    () async {
      var calls = 0;
      final gate = Completer<void>();
      final stream = dashboardPolling<int>(
        fetch: () async => ++calls,
        isActive: () => true,
        wait: () => gate.future,
      );
      final first = stream.listen((_) {});
      await flush();
      await first.cancel();
      final values = <int>[];
      final second = stream.listen(values.add);
      await flush();
      expect(values, [1, 2]);
      await second.cancel();
      gate.complete();
      await flush();
      expect(calls, 2);
    },
  );
}
