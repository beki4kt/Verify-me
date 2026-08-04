import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The single source of truth for the active session.
///
/// Replaces the scattered static mutable fields on `ApiService`
/// (`currentBusinessId`, `currentStaffNumber`, `currentUserRole`,
/// `currentBusinessMaxStaff`, `currentBusinessHasCashier`) which were
/// cleared inconsistently on logout (Waiter/Cashier only cleared the
/// staff number, leaking role/business state).
///
/// `ApiService` is wired to read/write through this controller during
/// `main()`, so existing `ApiService.currentBusinessId` references keep
/// working while the state is centralized and logout is consistent.
class SessionController extends ChangeNotifier {
  String? _businessId;
  String? _businessName;
  String? _staffNumber;
  String? _role;
  int? _maxStaff;
  bool? _hasCashier;

  String? get businessId => _businessId;
  String? get businessName => _businessName;
  String? get staffNumber => _staffNumber;
  String? get role => _role;
  int? get maxStaff => _maxStaff;
  bool? get hasCashier => _hasCashier;

  bool get isAuthenticated => _staffNumber != null && _role != null;
  bool get hasCashierModule => _hasCashier == true;
  bool get isSuperAdmin => _role == Role.superAdmin;
  bool get isAdmin => _role == Role.admin;

  /// Begin a staff session after a successful login.
  void startStaffSession({
    required String businessId,
    required String staffNumber,
    required String role,
    required int maxStaff,
    required bool hasCashier,
  }) {
    _businessId = businessId;
    _staffNumber = staffNumber;
    _role = role;
    _maxStaff = maxStaff;
    _hasCashier = hasCashier;
    notifyListeners();
  }

  /// Bind the locked business (after device provisioning, before staff login).
  void bindBusiness({required String businessId, required String businessName}) {
    _businessId = businessId;
    _businessName = businessName;
    notifyListeners();
  }

  /// Staff logout: clears the staff session but keeps the device locked to
  /// the business so the user returns to the staff login screen.
  void logoutStaff() {
    _staffNumber = null;
    _role = null;
    _maxStaff = null;
    _hasCashier = null;
    notifyListeners();
  }

  /// Full logout: clears business + staff (unbinds the terminal).
  void unbind() {
    _businessId = null;
    _businessName = null;
    _staffNumber = null;
    _role = null;
    _maxStaff = null;
    _hasCashier = null;
    notifyListeners();
  }
}

/// Application roles. Replaces the magic `'super_admin'` / `'admin'` /
/// `'cashier'` string literals scattered across the login + dashboards.
class Role {
  Role._();

  static const String superAdmin = 'super_admin';
  static const String admin = 'admin';
  static const String cashier = 'cashier';
  static const String waiter = 'waiter';

  static const List<String> all = [superAdmin, admin, cashier, waiter];

  /// Accent color used for role avatars / badges.
  static Color accent(String role) {
    switch (role) {
      case superAdmin:
        return AppColors.primary;
      case admin:
        return AppColors.success;
      case cashier:
        return AppColors.warning;
      default:
        return AppColors.telebirr;
    }
  }

  /// Human-readable label.
  static String label(String role) {
    switch (role) {
      case superAdmin:
        return 'Super Admin';
      case admin:
        return 'Admin';
      case cashier:
        return 'Cashier';
      default:
        return 'Waiter';
    }
  }
}
