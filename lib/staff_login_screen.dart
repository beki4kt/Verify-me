import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'api_service.dart';
import 'core/theme/app_colors.dart';
import 'core/widgets/staff_login_experience.dart';
import 'offline_storage.dart';
import 'business_gateway_screen.dart';
import 'waiter_dashboard.dart';
import 'cashier_dashboard.dart';
import 'super_admin_login_screen.dart';
import 'admin_dashboard.dart';
import 'core/config/app_environment.dart';
import 'trial_mode_screen.dart';
import 'core/config/app_variant.dart';

class StaffLoginScreen extends StatefulWidget {
  const StaffLoginScreen({super.key});

  @override
  State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String _phonePrefix = '9';
  bool _obscurePassword = true;
  String? _errorMessage;
  late Map<String, String?> _lockedBusiness;

  bool get _isTestDemoWorkspace =>
      !AppEnvironment.isProduction && _lockedBusiness['code'] == 'MESOB-DEMO';

  @override
  void initState() {
    super.initState();
    _lockedBusiness = DeviceStorage.getLockedBusiness();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_isLoading) return;
    final rawPhone = _phoneController.text.replaceAll(RegExp(r'\s'), '');
    final password = _passwordController.text;

    if (rawPhone.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Enter your phone number and password.');
      return;
    }

    // STRICT VALIDATION
    if (!RegExp(r'^\d{8}$').hasMatch(rawPhone)) {
      setState(() => _errorMessage = "Please enter exactly 8 digits.");
      return;
    }

    final businessId = _lockedBusiness['id'];
    if (businessId == null) {
      setState(
        () => _errorMessage =
            'This workspace connection expired. Choose the workspace again.',
      );
      return;
    }

    // CONCATENATE FOR THE DATABASE
    final formattedPhone = '+251$_phonePrefix$rawPhone';

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    FocusScope.of(context).unfocus();

    try {
      final role = await ApiService.loginStaffUnderBusiness(
        businessId,
        formattedPhone,
        password,
      );

      // GUARD THE ASYNC GAP
      if (!mounted) return;

      if (role != null) {
        Widget nextScreen;

        // APPLY CURLY BRACES TO ALL FLOW CONTROL STRUCTURES
        if (role == 'super_admin' && !AppVariant.exposesOperatorConsole) {
          await ApiService.logoutStaff();
          if (!mounted) return;
          setState(() {
            _errorMessage =
                'Platform operations are not available in this app.';
          });
          return;
        }

        if (role == 'super_admin') {
          nextScreen = const SuperAdminLoginScreen();
        } else if (role == 'admin') {
          nextScreen = const AdminDashboard();
        } else if (role == 'cashier') {
          nextScreen = const CashierDashboard();
        } else {
          nextScreen = const WaiterDashboard();
        }

        // Stop mutating the outgoing login route while its replacement
        // transition is deactivating inherited dependencies on Flutter Web.
        setState(() => _isLoading = false);
        await Navigator.pushReplacement(
          context,
          CupertinoPageRoute(builder: (_) => nextScreen),
        );
        return;
      } else {
        setState(
          () => _errorMessage = "Invalid credentials or inactive account.",
        );
      }
    } catch (e) {
      if (mounted) {
        final message = e.toString().replaceFirst('Exception: ', '').trim();
        setState(
          () => _errorMessage = message.isEmpty
              ? 'Could not sign in. Check the connection and try again.'
              : message,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _useDemoAccount({required String phone, required String password}) {
    _phonePrefix = '9';
    _phoneController.text = phone;
    _passwordController.text = password;
    _handleLogin();
  }

  void _confirmUnbindDevice() {
    if (AppVariant.usesIPhoneUi) {
      showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('Change workspace?'),
          content: const Text(
            'This removes the business connection from this iPhone.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => _unbindDevice(dialogContext),
              child: const Text('Change'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          AppVariant.usesMinimalCopy ? 'Change workspace?' : 'Unbind Terminal?',
        ),
        content: Text(
          AppVariant.usesMinimalCopy ? 'Remove this workspace?' : 'This will remove the current business connection from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: AppColors.textFaint),
            ),
          ),
          TextButton(
            onPressed: () => _unbindDevice(dialogContext),
            child: const Text(
              'UNBIND',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _unbindDevice(BuildContext dialogContext) async {
    await DeviceStorage.clearDeviceLock();
    if (!mounted || !dialogContext.mounted) return;

    Navigator.pop(dialogContext);
    await Navigator.of(context).pushReplacement(
      CupertinoPageRoute<void>(builder: (_) => const BusinessGatewayScreen()),
    );
  }

  @override
  Widget build(BuildContext context) => StaffLoginExperience(
    businessName: _lockedBusiness['name'] ?? 'Business',
    businessCode: _lockedBusiness['code'] ?? '',
    phone: _phoneController,
    password: _passwordController,
    loading: _isLoading,
    obscure: _obscurePassword,
    prefix: _phonePrefix,
    onPrefix: (value) => setState(() => _phonePrefix = value),
    error: _errorMessage,
    onLogin: _handleLogin,
    onTogglePassword: () =>
        setState(() => _obscurePassword = !_obscurePassword),
    onChangeBusiness: _confirmUnbindDevice,
    onDemo: AppVariant.isPublicRelease
        ? null
        : () => Navigator.of(context).push(
            CupertinoPageRoute<void>(builder: (_) => const TrialModeScreen()),
          ),
    onOwner: AppVariant.exposesOperatorConsole
        ? () => Navigator.of(context).push(
            CupertinoPageRoute<void>(
              builder: (_) => const SuperAdminLoginScreen(),
            ),
          )
        : null,
    quickAccess: _isTestDemoWorkspace
        ? Wrap(
            spacing: 8,
            children: [
              ActionChip(
                label: const Text('Admin'),
                onPressed: _isLoading
                    ? null
                    : () => _useDemoAccount(
                        phone: '11000001',
                        password: 'AdminTest!2026',
                      ),
              ),
              ActionChip(
                label: const Text('Cashier'),
                onPressed: _isLoading
                    ? null
                    : () => _useDemoAccount(
                        phone: '11000002',
                        password: 'CashierTest!2026',
                      ),
              ),
              ActionChip(
                label: const Text('Staff'),
                onPressed: _isLoading
                    ? null
                    : () => _useDemoAccount(
                        phone: '11000003',
                        password: 'WaiterTest!2026',
                      ),
              ),
            ],
          )
        : null,
  );
}
