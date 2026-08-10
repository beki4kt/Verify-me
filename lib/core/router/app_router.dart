import 'package:flutter/material.dart';

import '../../business_gateway_screen.dart';
import '../../staff_login_screen.dart';
import '../../waiter_dashboard.dart';
import '../../cashier_dashboard.dart';
import '../../admin_dashboard.dart';
import '../../super_admin_dashboard.dart';
import '../session/session_controller.dart';

/// Named routes for the app.
class AppRoutes {
  AppRoutes._();

  static const provision = '/provision';
  static const login = '/login';
  static const waiter = '/waiter';
  static const cashier = '/cashier';
  static const admin = '/admin';
  static const superAdmin = '/super-admin';

  /// Map a logged-in role to its home route.
  static String forRole(String role) {
    switch (role) {
      case Role.superAdmin:
        return superAdmin;
      case Role.admin:
        return admin;
      case Role.cashier:
        return cashier;
      default:
        return waiter;
    }
  }
}

/// Resolves the role's home screen widget. Replaces the hardcoded
/// `if/else` role chain that lived inside `StaffLoginScreen`.
Widget homeScreenForRole(String role) {
  switch (role) {
    case Role.superAdmin:
      return const SuperAdminDashboard();
    case Role.admin:
      return const AdminDashboard();
    case Role.cashier:
      return const CashierDashboard();
    default:
      return const WaiterDashboard();
  }
}

/// Centralized Navigator route table for `MaterialApp.routes`.
Map<String, WidgetBuilder> appRoutes() => {
  AppRoutes.provision: (_) => const BusinessGatewayScreen(),
  AppRoutes.login: (_) => const StaffLoginScreen(),
  AppRoutes.waiter: (_) => const WaiterDashboard(),
  AppRoutes.cashier: (_) => const CashierDashboard(),
  AppRoutes.admin: (_) => const AdminDashboard(),
  AppRoutes.superAdmin: (_) => const SuperAdminDashboard(),
};

/// Pushes a screen replacing the current route (the app's standard transition).
void goReplace(BuildContext context, Widget screen) {
  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => screen));
}
