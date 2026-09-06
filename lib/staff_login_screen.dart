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
import 'core/config/app_environment.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_motion.dart';
import 'core/theme/app_spacing.dart';
import 'core/theme/app_typography.dart';
import 'core/widgets/app_shell.dart';
import 'core/widgets/state_views.dart';
import 'localization_service.dart';
import 'trial_mode_screen.dart';
import 'core/config/app_variant.dart';
import 'iphone/iphone_dashboard_shell.dart';

class StaffLoginScreen extends StatefulWidget {
  const StaffLoginScreen({super.key});

  @override
  State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
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
    final rawPhone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    if (rawPhone.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Enter your phone number and password.');
      return;
    }

    // STRICT VALIDATION
    if (rawPhone.length != 8) {
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
    final formattedPhone = '+2519$rawPhone';

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

  Widget _buildIPhoneLogin(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final separator = CupertinoColors.separator.resolveFrom(context);
    final fieldFill = CupertinoColors.tertiarySystemFill.resolveFrom(context);
    final businessName = _lockedBusiness['name'] ?? 'Restaurant';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 64,
        centerTitle: false,
        titleSpacing: 2,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: colors.surface.withValues(alpha: .97),
        leading: CupertinoButton(
          key: const Key('iphone-change-workspace'),
          padding: EdgeInsets.zero,
          minimumSize: const Size.square(44),
          onPressed: _confirmUnbindDevice,
          child: const Icon(AppIcons.back, size: 22),
        ),
        title: Text(
          context.tr('Sign in'),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20),
        ),
        actions: const [IPhoneHeaderControls(), SizedBox(width: 6)],
      ),
      body: AppBackdrop(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 30, 20, 44),
          children: [
            Center(
              child: FadeSlideIn(
                child: BrandMark(
                  size: 64,
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (_) => const SuperAdminLoginScreen(),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            FadeSlideIn(
              index: 1,
              child: Text(
                businessName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.85,
                ),
              ),
            ),
            if (_isTestDemoWorkspace) ...[
              const SizedBox(height: 20),
              Text(
                context.tr('Quick access'),
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: secondary, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: separator.withValues(alpha: .42),
                    width: .5,
                  ),
                ),
                child: Row(
                  children: [
                    _iphoneDemoButton(
                      label: context.tr('Admin'),
                      phone: '11000001',
                      password: 'AdminTest!2026',
                    ),
                    SizedBox(
                      height: 34,
                      child: VerticalDivider(color: separator),
                    ),
                    _iphoneDemoButton(
                      label: context.tr('Cashier'),
                      phone: '11000002',
                      password: 'CashierTest!2026',
                    ),
                    SizedBox(
                      height: 34,
                      child: VerticalDivider(color: separator),
                    ),
                    _iphoneDemoButton(
                      label: context.tr('Waiter'),
                      phone: '11000003',
                      password: 'WaiterTest!2026',
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 26),
            FadeSlideIn(
              index: 2,
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: separator.withValues(alpha: .34),
                    width: .5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .10),
                      blurRadius: 24,
                      spreadRadius: -9,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CupertinoTextField(
                      key: const Key('iphone-staff-phone'),
                      controller: _phoneController,
                      enabled: !_isLoading,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(8),
                      ],
                      placeholder: context.tr('Phone number'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 17,
                      ),
                      decoration: BoxDecoration(
                        color: fieldFill,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      prefix: const Padding(
                        padding: EdgeInsets.only(left: 12),
                        child: Text(
                          '+2519',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    CupertinoTextField(
                      key: const Key('iphone-staff-password'),
                      controller: _passwordController,
                      enabled: !_isLoading,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => _handleLogin(),
                      placeholder: context.tr('Password'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 17,
                      ),
                      decoration: BoxDecoration(
                        color: fieldFill,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      prefix: const Padding(
                        padding: EdgeInsets.only(left: 12),
                        child: Icon(AppIcons.lock, size: 19),
                      ),
                      suffix: CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size.square(44),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        child: Icon(
                          _obscurePassword ? AppIcons.visible : AppIcons.hidden,
                          size: 19,
                        ),
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 14),
                      ErrorBanner(message: _errorMessage!),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 54,
                      child: CupertinoButton.filled(
                        key: const Key('iphone-staff-sign-in'),
                        borderRadius: BorderRadius.circular(16),
                        onPressed: _isLoading ? null : _handleLogin,
                        child: _isLoading
                            ? const CupertinoActivityIndicator(
                                color: CupertinoColors.white,
                              )
                            : Text(
                                context.tr('Sign in'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            CupertinoButton(
              onPressed: _confirmUnbindDevice,
              child: Text(context.tr('Change workspace')),
            ),
            CupertinoButton(
              onPressed: () => Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => const TrialModeScreen(),
                ),
              ),
              child: Text(context.tr('Open demo')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iphoneDemoButton({
    required String label,
    required String phone,
    required String password,
  }) {
    return Expanded(
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(vertical: 13),
        onPressed: _isLoading
            ? null
            : () => _useDemoAccount(phone: phone, password: password),
        child: Text(label, style: const TextStyle(fontSize: 14)),
      ),
    );
  }

  void _useDemoAccount({required String phone, required String password}) {
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
            'This removes the restaurant connection from this iPhone.',
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
  Widget build(BuildContext context) {
    if (AppVariant.usesIPhoneUi) return _buildIPhoneLogin(context);

    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: AppBackdrop(
        maxWidth: 640,
        entry: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: FadeSlideIn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FloatingNavIsland(
                  leading: BrandLockup(
                    compact: true,
                    onLogoTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SuperAdminLoginScreen(),
                      ),
                    ),
                  ),
                  trailing: const [
                    GlassLanguageToggleButton(),
                    SizedBox(width: 7),
                    GlassThemeToggleButton(),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxxl),
                const Align(
                  child: HeroPillBadge(
                    label: 'SECURE STAFF TERMINAL',
                    icon: AppIcons.shield,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                GradientText(
                  context.tr('Welcome back'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.5,
                  ),
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
                        child: PrimaryGlow(
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
