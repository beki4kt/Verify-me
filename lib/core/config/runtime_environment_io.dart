import 'dart:io';

/// `flutter test` sets FLUTTER_TEST in the test process. Perpetual animation
/// loops (shimmer, breathing) are disabled there so `pumpAndSettle` can settle.
bool get runningInFlutterTest => Platform.environment['FLUTTER_TEST'] == 'true';
