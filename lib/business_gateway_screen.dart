import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:vibration/vibration.dart';
import 'api_service.dart';
import 'offline_storage.dart';
import 'staff_login_screen.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_motion.dart';
import 'core/theme/app_spacing.dart';
import 'core/theme/app_typography.dart';
import 'core/widgets/app_shell.dart';
import 'core/widgets/state_views.dart';
import 'localization_service.dart';
import 'trial_mode_screen.dart';

class BusinessGatewayScreen extends StatefulWidget {
  const BusinessGatewayScreen({super.key});

  @override
  State<BusinessGatewayScreen> createState() => _BusinessGatewayScreenState();
}

class _BusinessGatewayScreenState extends State<BusinessGatewayScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyAndLock() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    FocusScope.of(context).unfocus();

    try {
      // --- GOD MODE BYPASS FOR SUPER ADMIN ---
      if (code == 'MASTER99') {
        await DeviceStorage.lockDeviceToBusiness(
          'SYSTEM_MASTER',
          'GOD MODE TERMINAL',
          'MASTER99',
        );
        final hasVib = await Vibration.hasVibrator();
        if (hasVib == true) Vibration.vibrate(pattern: [0, 50, 100, 50]);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            CupertinoPageRoute(builder: (_) => const StaffLoginScreen()),
          );
        }
        return;
      }
      // ---------------------------------------

      final bizData = await ApiService.verifyBusinessCode(code);

      if (bizData != null) {
        // Lock the device to the database response
        await DeviceStorage.lockDeviceToBusiness(
          bizData['business_id'],
          bizData['name'],
          bizData['business_code'],
        );

        final hasVib = await Vibration.hasVibrator();
        if (hasVib == true) Vibration.vibrate(pattern: [0, 50, 100, 50]);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            CupertinoPageRoute(builder: (_) => const StaffLoginScreen()),
          );
        }
      }
    } catch (e) {
      final hasVib = await Vibration.hasVibrator();
      if (hasVib == true) Vibration.vibrate(duration: 200);
      setState(
        () => _errorMessage = e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    const LanguageToggleButton(),
                    const ThemeToggleButton(),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                const BrandHero(),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  context.tr('Connect this terminal'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  context.tr(
                    'Enter your restaurant workspace code. You only need to do this once on this device.',
                  ),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xxl),
                HoverSurface(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        context.tr('WORKSPACE CODE'),
                        style: AppTypography.microLabel(),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        textAlign: TextAlign.center,
                        onSubmitted: (_) => _verifyAndLock(),
                        style: AppTypography.money(
                          size: 22,
                        ).copyWith(letterSpacing: 4),
                        decoration: const InputDecoration(
                          hintText: 'MESOB-DEMO',
                          prefixIcon: Icon(Icons.key_rounded),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (_errorMessage != null) ...[
                        ErrorBanner(message: _errorMessage!),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _verifyAndLock,
                        icon: _isLoading
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.arrow_forward_rounded),
                        label: Text(
                          context.tr(
                            _isLoading ? 'CONNECTING' : 'CONNECT WORKSPACE',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                GlassPanel(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  accent: AppColors.success,
                  child: Column(
                    children: [
                      Text(
                        context.tr('Explore before you connect'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.tr('No account, setup, or payment required'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const TrialModeScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.auto_awesome_rounded),
                        label: Text(context.tr('TRY THE LIVE DEMO')),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      size: 14,
                      color: AppColors.textFaint,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.tr('Encrypted tenant connection'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
