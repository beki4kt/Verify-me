import 'package:flutter/material.dart';
import 'package:verify_me/core/theme/app_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'api_service.dart';
import 'offline_storage.dart';
import 'business_gateway_screen.dart';
import 'waiter_dashboard.dart';
import 'cashier_dashboard.dart';
import 'super_admin_login_screen.dart';
import 'admin_dashboard.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_motion.dart';
import 'core/theme/app_spacing.dart';
import 'core/theme/app_typography.dart';
import 'core/widgets/app_shell.dart';
import 'core/widgets/state_views.dart';
import 'localization_service.dart';
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
  String? _errorMessage;
  late Map<String, String?> _lockedBusiness;

  bool get _isTestDemoWorkspace =>
      AppVariant.isTest2 && _lockedBusiness['code'] == 'MESOB-DEMO';

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
    final rawPhone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    if (rawPhone.isEmpty || password.isEmpty) return;

    // STRICT VALIDATION
    if (rawPhone.length != 8) {
      setState(() => _errorMessage = "Please enter exactly 8 digits.");
      return;
    }

    // CONCATENATE FOR THE DATABASE
    final formattedPhone = '+2519$rawPhone';

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    FocusScope.of(context).unfocus();

    try {
      final role = await ApiService.loginStaffUnderBusiness(
        _lockedBusiness['id']!,
        formattedPhone,
        password,
      );

      // GUARD THE ASYNC GAP
      if (!mounted) return;

      if (role != null) {
        Widget nextScreen;

        // APPLY CURLY BRACES TO ALL FLOW CONTROL STRUCTURES
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
        setState(() => _errorMessage = "Login Error: Check connection.");
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _useDemoAccount({required String phone, required String password}) {
    _phoneController.text = phone;
    _passwordController.text = password;
    _handleLogin();
  }

  void _confirmUnbindDevice() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          AppVariant.usesMinimalCopy ? 'Change workspace?' : 'Unbind Terminal?',
        ),
        content: Text(
          AppVariant.usesMinimalCopy ? 'Remove this workspace?' : 'This will remove the current restaurant connection from this device.',
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
            onPressed: () async {
              await DeviceStorage.clearDeviceLock();

              // GUARD THE ASYNC GAP
              if (!mounted || !dialogContext.mounted) return;

              Navigator.pop(dialogContext);
              Navigator.pushReplacement(
                context,
                CupertinoPageRoute(
                  builder: (_) => const BusinessGatewayScreen(),
                ),
              );
            },
            child: const Text(
              'UNBIND',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: AppBackdrop(
        maxWidth: 560,
        entry: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: FadeSlideIn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const GlassLanguageToggleButton(),
                    const GlassThemeToggleButton(),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                BrandHero(
                  onLogoTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SuperAdminLoginScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  context.tr('Welcome back'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                if (!AppVariant.usesMinimalCopy) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    context.tr('Sign in to continue to your shift.'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                Align(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: .2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          AppIcons.storefront,
                          color: AppColors.success,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _lockedBusiness['name'] ?? 'Restaurant',
                          style: AppTypography.microLabel(
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                HoverSurface(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_isTestDemoWorkspace) ...[
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            ActionChip(
                              avatar: const Icon(
                                AppIcons.administration,
                                size: 17,
                              ),
                              label: const Text('Admin'),
                              onPressed: _isLoading
                                  ? null
                                  : () => _useDemoAccount(
                                      phone: '11000001',
                                      password: 'AdminTest!2026',
                                    ),
                            ),
                            ActionChip(
                              avatar: const Icon(
                                AppIcons.pointOfSale,
                                size: 17,
                              ),
                              label: const Text('Cashier'),
                              onPressed: _isLoading
                                  ? null
                                  : () => _useDemoAccount(
                                      phone: '11000002',
                                      password: 'CashierTest!2026',
                                    ),
                            ),
                            ActionChip(
                              avatar: const Icon(
                                AppIcons.serviceBell,
                                size: 17,
                              ),
                              label: const Text('Waiter'),
                              onPressed: _isLoading
                                  ? null
                                  : () => _useDemoAccount(
                                      phone: '11000003',
                                      password: 'WaiterTest!2026',
                                    ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(8),
                        ],
                        style: TextStyle(
                          color: colors.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                        decoration: InputDecoration(
                          labelText: context.tr('Phone number'),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(
                              left: 16.0,
                              right: 8.0,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  AppIcons.phone,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '+2519',
                                  style: TextStyle(
                                    color: colors.onSurface,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 2,
                                  height: 24,
                                  color: colors.onSurface.withValues(alpha: .1),
                                ),
                                const SizedBox(width: 12),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        style: TextStyle(color: colors.onSurface),
                        onSubmitted: (_) => _handleLogin(),
                        decoration: InputDecoration(
                          labelText: context.tr('Password'),
                          prefixIcon: const Icon(AppIcons.lock),
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: ErrorBanner(message: _errorMessage!),
                        ),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _handleLogin,
                          icon: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(AppIcons.login),
                          label: Text(
                            context.tr(_isLoading ? 'SIGNING IN' : 'SIGN IN'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextButton(
                  onPressed: _confirmUnbindDevice,
                  child: Text(
                    context.tr('This is not your restaurant? Change workspace'),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TrialModeScreen()),
                  ),
                  icon: const Icon(AppIcons.sparkle),
                  label: Text(context.tr('TRY THE LIVE DEMO')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
