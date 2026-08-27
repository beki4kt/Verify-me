import 'package:flutter/material.dart';
import 'package:verify_me/core/theme/app_icons.dart';
import 'package:verify_me/core/config/app_variant.dart';
import 'package:flutter/services.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_spacing.dart';
import 'core/theme/app_typography.dart';
import 'core/widgets/app_shell.dart';
import 'core/theme/app_motion.dart';
import 'core/widgets/state_views.dart';
import 'operator_service.dart';
import 'super_admin_dashboard.dart';

class SuperAdminLoginScreen extends StatefulWidget {
  const SuperAdminLoginScreen({super.key});

  @override
  State<SuperAdminLoginScreen> createState() => _SuperAdminLoginScreenState();
}

class _SuperAdminLoginScreenState extends State<SuperAdminLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty ||
        _codeController.text.length != 6) {
      setState(
        () => _error = 'Enter your owner email, password, and six-digit authenticator code.',
      );
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    FocusScope.of(context).unfocus();
    try {
      await OperatorService.login(
        email: _emailController.text,
        password: _passwordController.text,
        code: _codeController.text,
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SuperAdminDashboard()),
      );
    } on OperatorApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Owner authentication failed.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AppBackdrop(
      maxWidth: 600,
      entry: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: FadeSlideIn(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Return to CHEKMI',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(AppIcons.back),
                  ),
                  const Spacer(),
                  const GlassThemeToggleButton(),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              BrandHero(
                subtitle: AppVariant.usesMinimalCopy
                    ? null
                    : 'Protected platform operations',
              ),
              const SizedBox(height: AppSpacing.xl),
              GlassPanel(
                padding: const EdgeInsets.all(AppSpacing.xl),
                accent: AppColors.primary,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: .14),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              AppIcons.administration,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Owner access',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                if (!AppVariant.usesMinimalCopy) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    'Credentials are verified by the protected CHEKMI API.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      TextField(
                        key: const Key('operatorEmailField'),
                        controller: _emailController,
                        autofillHints: const [
                          AutofillHints.username,
                          AutofillHints.email,
                        ],
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'OWNER EMAIL',
                          prefixIcon: Icon(AppIcons.emailHandle),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextField(
                        key: const Key('operatorPasswordField'),
                        controller: _passwordController,
                        autofillHints: const [AutofillHints.password],
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'PASSWORD',
                          prefixIcon: const Icon(AppIcons.password),
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? AppIcons.visible
                                  : AppIcons.hidden,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextField(
                        key: const Key('operatorCodeField'),
                        controller: _codeController,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        onSubmitted: (_) {
                          if (!_loading) _signIn();
                        },
                        style: AppTypography.money(size: 20)
                            .copyWith(letterSpacing: 7),
                        decoration: const InputDecoration(
                          labelText: AppVariant.usesMinimalCopy
                              ? 'MFA CODE'
                              : 'AUTHENTICATOR CODE',
                          hintText: '000000',
                          prefixIcon: Icon(AppIcons.phoneLock),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.lg),
                        ErrorBanner(message: _error!),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      ElevatedButton.icon(
                        key: const Key('operatorSignInButton'),
                        onPressed: _loading ? null : _signIn,
                        icon: _loading
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(AppIcons.security),
                        label: Text(
                          AppVariant.usesMinimalCopy
                              ? (_loading ? 'VERIFYING' : 'OPEN')
                              : (_loading
                                    ? 'VERIFYING OWNER'
                                    : 'OPEN CONTROL CENTER'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!AppVariant.usesMinimalCopy) ...[
                const SizedBox(height: AppSpacing.lg),
                const Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppSpacing.lg,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _SecurityFact(
                      icon: AppIcons.timer,
                      label: '2-hour session',
                    ),
                    _SecurityFact(icon: AppIcons.key, label: 'MFA required'),
                    _SecurityFact(
                      icon: AppIcons.verifiedList,
                      label: 'Actions audited',
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _SecurityFact extends StatelessWidget {
  const _SecurityFact({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: AppColors.success),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}
