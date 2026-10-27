import 'package:flutter_test/flutter_test.dart';
import 'package:verify_me/core/session/session_controller.dart';

void main() {
  test('a cached role cannot keep an expired staff session authenticated', () {
    final session = SessionController();
    session.startStaffSession(
      businessId: 'workspace-a',
      staffNumber: 'staff-a',
      role: 'admin',
      maxStaff: 4,
      hasCashier: true,
      expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
    );
    expect(session.isAuthenticated, false);
  });

  test('logout clears role and expiry while preserving device connection', () {
    final session = SessionController();
    session.bindBusiness(businessId: 'workspace-a', businessName: 'Test');
    session.startStaffSession(
      businessId: 'workspace-a',
      staffNumber: 'staff-a',
      role: 'cashier',
      maxStaff: 4,
      hasCashier: true,
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );
    expect(session.isAuthenticated, true);
    session.logoutStaff();
    expect(session.isAuthenticated, false);
    expect(session.expiresAt, isNull);
    expect(session.businessId, 'workspace-a');
  });
}
