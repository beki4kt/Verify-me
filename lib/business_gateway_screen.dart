import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

import 'api_service.dart';
import 'core/config/app_variant.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_icons.dart';
import 'core/theme/app_motion.dart';
import 'core/theme/app_spacing.dart';
import 'core/theme/app_typography.dart';
import 'core/widgets/app_shell.dart';
import 'core/widgets/payment_brand.dart';
import 'core/widgets/state_views.dart';
import 'localization_service.dart';
import 'iphone/iphone_business_gateway_screen.dart';
import 'offline_storage.dart';
import 'pricing_screen.dart';
import 'staff_login_screen.dart';
import 'super_admin_login_screen.dart';
import 'trial_mode_screen.dart';

class BusinessGatewayScreen extends StatefulWidget {
  const BusinessGatewayScreen({super.key});

  @override
  State<BusinessGatewayScreen> createState() => _BusinessGatewayScreenState();
}

class _BusinessGatewayScreenState extends State<BusinessGatewayScreen> {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocus = FocusNode();
  final GlobalKey _workspaceKey = GlobalKey();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  Future<void> _verifyAndLock() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      _codeFocus.requestFocus();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    FocusScope.of(context).unfocus();

    try {
      final bizData = await ApiService.verifyBusinessCode(code);
      if (bizData == null) return;

      await DeviceStorage.lockDeviceToBusiness(
        bizData['business_id'],
        bizData['name'],
        bizData['business_code'],
      );

      final hasVib = await Vibration.hasVibrator();
      if (hasVib == true) Vibration.vibrate(pattern: [0, 50, 100, 50]);

      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        CupertinoPageRoute(builder: (_) => const StaffLoginScreen()),
      );
    } catch (error) {
      final hasVib = await Vibration.hasVibrator();
      if (hasVib == true) Vibration.vibrate(duration: 200);
      if (mounted) {
        setState(
          () => _errorMessage = error.toString().replaceAll('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _focusWorkspace() async {
    final target = _workspaceKey.currentContext;
    if (target != null) {
      await Scrollable.ensureVisible(
        target,
        duration: AppMotion.slow,
        curve: AppMotion.easeOutCustom,
        alignment: .18,
      );
    }
    if (mounted) _codeFocus.requestFocus();
  }

  void _openTrial() =>
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const TrialModeScreen()));

  void _openPricing() =>
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const PricingScreen()));

  void _openOwnerAccess() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const SuperAdminLoginScreen()));

  @override
  Widget build(BuildContext context) {
    if (AppVariant.usesIPhoneUi) {
      return const IPhoneBusinessGatewayScreen();
    }
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 620;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackdrop(
        maxWidth: 1200,
        entry: true,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            compact ? AppSpacing.md : AppSpacing.xl,
            AppSpacing.md,
            compact ? AppSpacing.md : AppSpacing.xl,
            AppSpacing.xxxl,
          ),
          child: FadeSlideIn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FloatingNavIsland(
                  leading: BrandLockup(
                    compact: true,
                    onLogoTap: _openOwnerAccess,
                  ),
                  navigation: [
                    TextButton(
                      onPressed: _focusWorkspace,
                      child: const Text('WORKSPACE'),
                    ),
                    TextButton(
                      onPressed: _openTrial,
                      child: const Text('LIVE DEMO'),
                    ),
                    TextButton(
                      onPressed: _openPricing,
                      child: const Text('PRICING'),
                    ),
                  ],
                  trailing: const [
                    GlassLanguageToggleButton(),
                    SizedBox(width: 7),
                    GlassThemeToggleButton(),
                  ],
                ),
                SizedBox(height: compact ? 54 : 82),
                _hero(compact),
                SizedBox(height: compact ? 46 : 68),
                const _ProviderLogoCloud(),
                const SizedBox(height: AppSpacing.xxl),
                const _ProductBento(),
                const SizedBox(height: AppSpacing.xxl),
                _workspaceSurface(),
                const SizedBox(height: AppSpacing.xl),
                _footer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _hero(bool compact) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 940),
      child: Column(
        children: [
          HeroPillBadge(
            label: AppVariant.usesMinimalCopy
                ? 'PAYMENTS, VERIFIED'
                : 'REAL-TIME PAYMENT OPERATIONS',
            icon: AppIcons.verified,
          ),
          const SizedBox(height: AppSpacing.lg),
          GradientText(
            AppVariant.usesMinimalCopy
                ? 'Every payment.\nVerified.'
                : 'Every restaurant payment.\nVerified in real time.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              fontSize: compact ? 42 : 64,
              height: .98,
              fontWeight: FontWeight.w800,
              letterSpacing: compact ? -1.6 : -3.1,
            ),
          ),
          if (!AppVariant.usesMinimalCopy) ...[
            const SizedBox(height: AppSpacing.lg),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 690),
              child: Text(
                'Turn every transfer into a trusted, auditable signal before service slows down. CHEKMI gives your entire restaurant one calm source of truth.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.55,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              PrimaryGlow(
                child: ElevatedButton.icon(
                  onPressed: _focusWorkspace,
                  icon: const Icon(AppIcons.forward),
                  label: Text(
                    AppVariant.usesMinimalCopy
                        ? 'CONNECT'
                        : 'CONNECT YOUR WORKSPACE',
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _openTrial,
                icon: const Icon(AppIcons.playCircle),
                label: Text(
                  AppVariant.usesMinimalCopy ? 'DEMO' : 'EXPLORE LIVE DEMO',
                ),
              ),
            ],
          ),
          if (!AppVariant.usesMinimalCopy) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No setup call · No payment required · Ethiopian rails ready',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    ),
  );

  Widget _workspaceSurface() => GlassPanel(
    key: _workspaceKey,
    accent: AppColors.primary,
    borderRadius: 32,
    blur: 30,
    padding: const EdgeInsets.all(AppSpacing.xl),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 790;
        final introduction = Column(
          crossAxisAlignment: wide
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            const HeroPillBadge(label: 'ONE CODE AWAY', icon: AppIcons.key),
            const SizedBox(height: AppSpacing.lg),
            GradientText(
              context.tr('Connect this terminal'),
              textAlign: wide ? TextAlign.start : TextAlign.center,
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontSize: wide ? 38 : 32,
                height: 1.05,
                letterSpacing: -1.2,
              ),
            ),
            if (!AppVariant.usesMinimalCopy) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                context.tr(
                  'Enter your restaurant workspace code. You only need to do this once on this device.',
                ),
                textAlign: wide ? TextAlign.start : TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(height: 1.55),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              alignment: wide ? WrapAlignment.start : WrapAlignment.center,
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.sm,
              children: const [
                _TrustItem(icon: AppIcons.lock, label: 'Tenant encrypted'),
                _TrustItem(icon: AppIcons.cloudReady, label: 'Cloud synced'),
                _TrustItem(icon: AppIcons.shield, label: 'Role protected'),
              ],
            ),
          ],
        );
        final form = Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: .54),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: .09)),
          ),
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
                focusNode: _codeFocus,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                onSubmitted: (_) => _verifyAndLock(),
                style: AppTypography.money(size: 21)
                    .copyWith(letterSpacing: 3.2),
                decoration: const InputDecoration(
                  hintText: 'MESOB-DEMO',
                  prefixIcon: Icon(AppIcons.key),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: AppSpacing.md),
                ErrorBanner(message: _errorMessage!),
              ],
              const SizedBox(height: AppSpacing.lg),
              PrimaryGlow(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _verifyAndLock,
                  icon: _isLoading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(AppIcons.forward),
                  label: Text(
                    context.tr(_isLoading ? 'CONNECTING' : 'CONNECT WORKSPACE'),
                  ),
                ),
              ),
            ],
          ),
        );

        if (!wide) {
          return Column(
            children: [
              introduction,
              const SizedBox(height: AppSpacing.xl),
              form,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: introduction),
            const SizedBox(width: AppSpacing.xxl),
            Expanded(child: form),
          ],
        );
      },
    ),
  );

  Widget _footer() => Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: AppSpacing.sm,
    children: [
      const Icon(AppIcons.lock, size: 14, color: AppColors.textFaint),
      Text(
        context.tr('Encrypted tenant connection'),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const Text('·', style: TextStyle(color: AppColors.textFaint)),
      TextButton(onPressed: _openPricing, child: const Text('VIEW PRICING')),
    ],
  );
}

class _ProviderLogoCloud extends StatelessWidget {
  const _ProviderLogoCloud();

  static const providers = [
    'Telebirr',
    'Commercial Bank of Ethiopia',
    'CBE Birr',
    'Dashen',
    'Abyssinia',
    'M-Pesa',
  ];

  static const grayscale = ColorFilter.matrix([
    .2126,
    .7152,
    .0722,
    0,
    0,
    .2126,
    .7152,
    .0722,
    0,
    0,
    .2126,
    .7152,
    .0722,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]);

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        'VERIFIES ACROSS ETHIOPIA’S PAYMENT NETWORK',
        textAlign: TextAlign.center,
        style: AppTypography.microLabel(color: AppColors.textFaint),
      ),
      const SizedBox(height: AppSpacing.lg),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final provider in providers) ...[
              _ProviderCloudLogo(provider: provider),
              if (provider != providers.last)
                Container(
                  width: 1,
                  height: 24,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  color: Colors.white.withValues(alpha: .08),
                ),
            ],
          ],
        ),
      ),
    ],
  );
}

class _ProviderCloudLogo extends StatelessWidget {
  const _ProviderCloudLogo({required this.provider});

  final String provider;

  @override
  Widget build(BuildContext context) {
    final brand = PaymentBrandData.resolve(provider);
    return Opacity(
      opacity: .58,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ColorFiltered(
            colorFilter: _ProviderLogoCloud.grayscale,
            child: Image.asset(
              brand.asset,
              width: 30,
              height: 30,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(AppIcons.wallet, size: 24),
            ),
          ),
          const SizedBox(width: 9),
          Text(
            brand.name,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ProductBento extends StatelessWidget {
  const _ProductBento();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 800) {
        return const Column(
          children: [
            SizedBox(height: 410, child: _VerificationPreview()),
            SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 210,
              child: _MetricPanel(
                icon: AppIcons.layers,
                value: '6',
                label: 'payment providers',
                copy: 'One verification workflow across the rails guests use.',
                accent: AppColors.aqua,
              ),
            ),
            SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 210,
              child: _MetricPanel(
                icon: AppIcons.team,
                value: '3',
                label: 'role-aware workspaces',
                copy: 'Waiter, cashier, and owner views stay in perfect sync.',
                accent: AppColors.primary,
              ),
            ),
          ],
        );
      }
      return const SizedBox(
        height: 440,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 7, child: _VerificationPreview()),
            SizedBox(width: AppSpacing.lg),
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  Expanded(
                    child: _MetricPanel(
                      icon: AppIcons.layers,
                      value: '6',
                      label: 'payment providers',
                      copy: 'One verification workflow across the rails guests use.',
                      accent: AppColors.aqua,
                    ),
                  ),
                  SizedBox(height: AppSpacing.lg),
                  Expanded(
                    child: _MetricPanel(
                      icon: AppIcons.team,
                      value: '3',
                      label: 'role-aware workspaces',
                      copy: 'Waiter, cashier, and owner views stay in perfect sync.',
                      accent: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _VerificationPreview extends StatelessWidget {
  const _VerificationPreview();

  @override
  Widget build(BuildContext context) => GlassPanel(
    borderRadius: 32,
    blur: 30,
    accent: AppColors.primary,
    padding: const EdgeInsets.all(AppSpacing.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _OutlineIconTile(
              icon: AppIcons.scanReceipt,
              accent: AppColors.primarySoft,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LIVE VERIFICATION',
                    style: AppTypography.microLabel(
                      color: AppColors.primarySoft,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Signal, not screenshots',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest.withValues(alpha: .86),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withValues(alpha: .09)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: .16),
                  blurRadius: 32,
                  spreadRadius: -8,
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    for (final color in const [
                      AppColors.danger,
                      AppColors.warning,
                      AppColors.success,
                    ]) ...[
                      Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withValues(alpha: .76),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      'CHEKMI / VERIFY',
                      style: AppTypography.microLabel(
                        color: AppColors.textFaint,
                      ).copyWith(fontSize: 8),
                    ),
                  ],
                ),
                const Spacer(),
                const PaymentBrand(
                  provider: 'Telebirr',
                  logoSize: 38,
                  compactName: true,
                ),
                const SizedBox(height: AppSpacing.lg),
                GradientText(
                  'ETB 1,450.00',
                  style: AppTypography.money(size: 34),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: .25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        AppIcons.verified,
                        size: 16,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'PAYMENT VERIFIED',
                        style: AppTypography.microLabel(
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Table 08',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      'Just now',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _MetricPanel extends StatelessWidget {
  const _MetricPanel({
    required this.icon,
    required this.value,
    required this.label,
    required this.copy,
    required this.accent,
  });

  final IconData icon;
  final String value;
  final String label;
  final String copy;
  final Color accent;

  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: accent == AppColors.primary ? const Offset(0, 4) : Offset.zero,
    child: GlassPanel(
      borderRadius: 30,
      accent: accent,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OutlineIconTile(icon: icon, accent: accent),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: AppTypography.money(size: 44, color: accent),
                ),
                Text(label, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  copy,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _OutlineIconTile extends StatelessWidget {
  const _OutlineIconTile({required this.icon, required this.accent});

  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      color: accent.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: accent.withValues(alpha: .18)),
    ),
    child: Icon(icon, color: accent, size: 21),
  );
}

class _TrustItem extends StatelessWidget {
  const _TrustItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: AppColors.success),
      const SizedBox(width: 7),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}
