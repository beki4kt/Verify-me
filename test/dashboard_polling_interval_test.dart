import 'package:flutter_test/flutter_test.dart';
import 'package:verify_me/core/services/dashboard_polling.dart';

void main() {
  test('uses fast polling only while a queue needs attention', () {
    final idle = adaptivePollingInterval<Map<String, String>>(const [
      {'status': 'settled'},
      {'status': 'rejected'},
    ], needsFastRefresh: (row) => row['status'] == 'pending');
    final active = adaptivePollingInterval<Map<String, String>>(const [
      {'status': 'settled'},
      {'status': 'pending'},
    ], needsFastRefresh: (row) => row['status'] == 'pending');

    expect(idle, const Duration(seconds: 15));
    expect(active, const Duration(seconds: 5));
  });
}
