import 'package:flutter_test/flutter_test.dart';
import 'package:verify_me/core/widgets/dashboard_refresh_status.dart';

void main() {
  test('formats dashboard freshness without hiding an active refresh', () {
    final now = DateTime.utc(2026, 9, 18, 12);

    expect(
      dashboardRefreshLabel(
        DashboardRefreshState(
          lastUpdated: now.subtract(const Duration(seconds: 8)),
        ),
        now: now,
      ),
      'Updated 8s ago',
    );
    expect(
      dashboardRefreshLabel(
        DashboardRefreshState(
          lastUpdated: now.subtract(const Duration(minutes: 3)),
        ),
        now: now,
      ),
      'Updated 3m ago',
    );
    expect(
      dashboardRefreshLabel(
        DashboardRefreshState(lastUpdated: now, isRefreshing: true),
        now: now,
      ),
      'Refreshing payments…',
    );
  });
}
