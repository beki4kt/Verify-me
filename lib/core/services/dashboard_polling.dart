import 'dart:async';

/// One recoverable poll shared by dashboard listeners, with a replay for every
/// new subscriber. Session changes and removed listeners discard in-flight data.
Stream<T> dashboardPolling<T>({
  required Future<T> Function() fetch,
  required bool Function() isActive,
  required Future<void> Function() wait,
}) {
  final listeners = <MultiStreamController<T>>{};
  T? latest;
  var hasLatest = false;
  var generation = 0;

  Future<void> poll(int run) async {
    while (run == generation && listeners.isNotEmpty && isActive()) {
      try {
        final value = await fetch();
        if (run != generation || !isActive()) break;
        latest = value;
        hasLatest = true;
        // A successful unchanged response also clears a previous stream error.
        for (final listener in listeners.toList()) {
          listener.add(value);
        }
      } catch (error, stack) {
        if (run != generation || !isActive()) break;
        for (final listener in listeners.toList()) {
          listener.addError(error, stack);
        }
      }
      if (run != generation || listeners.isEmpty || !isActive()) break;
      await wait();
    }
    if (run == generation && !isActive()) {
      hasLatest = false;
      for (final listener in listeners.toList()) {
        listener.close();
      }
      listeners.clear();
    }
  }

  return Stream<T>.multi((listener) {
    if (!isActive()) {
      listener.close();
      return;
    }
    final start = listeners.isEmpty;
    listeners.add(listener);
    if (hasLatest) listener.add(latest as T);
    listener.onCancel = () {
      listeners.remove(listener);
      if (listeners.isEmpty) generation++;
    };
    if (start) unawaited(poll(++generation));
  }, isBroadcast: true);
}
