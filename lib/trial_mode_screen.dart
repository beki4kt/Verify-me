import 'package:flutter/material.dart';
import 'package:verify_me/core/theme/app_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'business_gateway_screen.dart';
import 'api_service.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_spacing.dart';
import 'core/widgets/app_shell.dart';
import 'core/widgets/payment_brand.dart';
import 'core/widgets/state_views.dart';
import 'localization_service.dart';
import 'pricing_screen.dart';
import 'core/config/app_variant.dart';
import 'waiter_dashboard.dart';

enum TrialRole { waiter, cashier, admin }

class TrialModeScreen extends StatefulWidget {
  const TrialModeScreen({super.key});

  @override
  State<TrialModeScreen> createState() => _TrialModeScreenState();
}

class _TrialModeScreenState extends State<TrialModeScreen> {
  static const _providers = [
    'Telebirr',
    'CBE',
    'CBE Birr',
    'Dashen',
    'Abyssinia',
    'M-Pesa',
  ];

  TrialRole _role = TrialRole.waiter;
  String _selectedProvider = 'Telebirr';
  bool _verified = false;
  bool _openingWaiter = false;
  String? _waiterError;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 760;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackdrop(
        maxWidth: 1180,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                0,
              ),
              sliver: SliverToBoxAdapter(child: _header()),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              sliver: SliverList.list(
                children: [
                  _hero(),
                  const SizedBox(height: AppSpacing.lg),
                  _rolePicker(),
                  const SizedBox(height: AppSpacing.lg),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: KeyedSubtree(
                      key: ValueKey(_role),
                      child: wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 3, child: _rolePreview()),
                                const SizedBox(width: AppSpacing.lg),
                                Expanded(flex: 2, child: _guidedAction()),
                              ],
                            )
                          : Column(
                              children: [
                                _rolePreview(),
                                const SizedBox(height: AppSpacing.lg),
                                _guidedAction(),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _conversionCard(),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() => Row(
    children: [
      const BrandLockup(compact: true),
      const Spacer(),
      const GlassLanguageToggleButton(),
      const GlassThemeToggleButton(),
      IconButton(
        tooltip: context.tr('EXIT TRIAL'),
        onPressed: _exit,
        icon: const Icon(AppIcons.close),
      ),
    ],
  );

  Widget _hero() => GlassPanel(
    accent: AppColors.primary,
    padding: const EdgeInsets.all(AppSpacing.xl),
    child: Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            AppIcons.sparkle,
            color: AppColors.primarySoft,
            size: 30,
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('Trial mode'),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if (!AppVariant.usesMinimalCopy) ...[
                const SizedBox(height: 5),
                Text(
                  context.tr('A guided, risk-free tour of CHEKMI'),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ],
          ),
        ),
        Chip(
          avatar: const Icon(AppIcons.shield, size: 16),
          label: Text(
            _role == TrialRole.waiter
                ? (AppVariant.usesMinimalCopy ? 'LIVE' : 'LIVE WAITER FLOW')
                : (AppVariant.usesMinimalCopy ? 'DEMO' : 'GUIDED DEMO'),
          ),
        ),
      ],
    ),
  ).animate().fadeIn().slideY(begin: .08, end: 0);

  Widget _rolePicker() => GlassPanel(
    padding: const EdgeInsets.all(AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!AppVariant.usesMinimalCopy)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
            child: Text(
              context.tr('Choose a role'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        SegmentedButton<TrialRole>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: TrialRole.waiter,
              icon: const Icon(AppIcons.serviceBell),
              label: Text(context.tr('Waiter')),
            ),
            ButtonSegment(
              value: TrialRole.cashier,
              icon: const Icon(AppIcons.pointOfSale),
              label: Text(context.tr('Cashier')),
            ),
            ButtonSegment(
              value: TrialRole.admin,
              icon: const Icon(AppIcons.analytics),
              label: Text(context.tr('Admin')),
            ),
          ],
          selected: {_role},
          onSelectionChanged: (value) => setState(() {
            _role = value.first;
            _verified = false;
            _waiterError = null;
          }),
        ),
      ],
    ),
  );

  Widget _rolePreview() {
    final data = switch (_role) {
      TrialRole.waiter => (
        title: context.tr('Waiter workspace'),
        icon: AppIcons.serviceBell,
        color: AppColors.telebirr,
        metrics: [
          (context.tr('Available tips'), '420 ETB'),
          (context.tr('Open tickets'), '3'),
          (context.tr('Today'), '12 served'),
        ],
      ),
      TrialRole.cashier => (
        title: context.tr('Cashier terminal'),
        icon: AppIcons.pointOfSale,
        color: AppColors.warning,
        metrics: [
          (context.tr('Pending'), '5'),
          (context.tr('Settled'), '18'),
          (context.tr('Today'), '24,850 ETB'),
        ],
      ),
      TrialRole.admin => (
        title: context.tr('Restaurant overview'),
        icon: AppIcons.analytics,
        color: AppColors.success,
        metrics: [
          (context.tr('TOTAL REVENUE'), '24,850 ETB'),
          (context.tr('Open tickets'), '5'),
          (context.tr('Staff online'), '7'),
        ],
      ),
    };
    return GlassPanel(
      accent: data.color,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(data.icon, color: data.color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  data.title,
                  style: Theme.of(context).textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'DEMO',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: data.color),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth < 520
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 24) / 3;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: data.metrics
                    .map(
                      (metric) => SizedBox(
                        width: cardWidth,
                        child: GlassPanel(
                          padding: const EdgeInsets.all(16),
                          borderRadius: 18,
                          blur: 12,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                metric.$1,
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                metric.$2,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(color: data.color),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          _sampleTicket(data.color),
        ],
      ),
    );
  }

  Widget _sampleTicket(Color color) {
    final brand = PaymentBrandData.resolve(_selectedProvider);
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      borderRadius: 18,
      child: Row(
        children: [
          PaymentLogo(provider: _selectedProvider, size: 42),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  brand.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text('TXN8K2M4  •  Table 08'),
              ],
            ),
          ),
          Text(
            '1,250 ETB',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  Widget _guidedAction() => _role == TrialRole.waiter
      ? _liveWaiterAction()
      : _previewVerificationAction();

  Widget _liveWaiterAction() => GlassPanel(
    accent: AppColors.telebirr,
    padding: const EdgeInsets.all(AppSpacing.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(AppIcons.scanReceipt, color: AppColors.telebirr, size: 52),
        const SizedBox(height: AppSpacing.lg),
        Text(
          context.tr('Waiter workspace'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (!AppVariant.usesMinimalCopy) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Open the real waiter scanner, ticket, and wallet workflow.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
        if (_waiterError != null) ...[
          const SizedBox(height: AppSpacing.lg),
          ErrorBanner(message: _waiterError!),
        ],
        const SizedBox(height: AppSpacing.xl),
        ElevatedButton.icon(
          onPressed: _openingWaiter ? null : _openWaiterTrial,
          icon: _openingWaiter
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(AppIcons.forward),
          label: Text(_openingWaiter ? 'OPENING' : 'OPEN WAITER'),
        ),
      ],
    ),
  );

  Widget _previewVerificationAction() => GlassPanel(
    padding: const EdgeInsets.all(AppSpacing.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          _verified ? AppIcons.verified : AppIcons.scanReceipt,
          color: _verified ? AppColors.success : AppColors.primary,
          size: 52,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          context.tr(_verified ? 'Receipt verified' : 'Verify receipt'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (!AppVariant.usesMinimalCopy) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.tr(
              _verified
                  ? 'Verified with ${PaymentBrandData.resolve(_selectedProvider).name}.'
                  : 'Select a provider, then verify the sample receipt.',
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: _providers.map(_providerChoice).toList(),
        ),
        const SizedBox(height: AppSpacing.xl),
        ElevatedButton.icon(
          onPressed: () => setState(() => _verified = true),
          icon: Icon(_verified ? AppIcons.check : AppIcons.scanReceipt),
          label: Text(context.tr(_verified ? 'VERIFIED' : 'VERIFY RECEIPT')),
        ),
      ],
    ),
  );

  Future<void> _openWaiterTrial() async {
    setState(() {
      _openingWaiter = true;
      _waiterError = null;
    });
    try {
      final business = await ApiService.verifyBusinessCode('MESOB-DEMO');
      if (business == null) throw Exception('Demo workspace unavailable.');
      final role = await ApiService.loginStaffUnderBusiness(
        business['business_id'].toString(),
        '+251911000003',
        'WaiterTest!2026',
      );
      if (role != 'waiter') throw Exception('Demo waiter unavailable.');
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const WaiterDashboard(trialMode: true),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => _waiterError = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      await ApiService.logoutStaff();
      if (mounted) setState(() => _openingWaiter = false);
    }
  }

  Widget _providerChoice(String provider) {
    final selected = provider == _selectedProvider;
    final brand = PaymentBrandData.resolve(provider);
    return Semantics(
      button: true,
      selected: selected,
      label: brand.name,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() {
          _selectedProvider = provider;
          _verified = false;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: 88,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: brand.color.withValues(alpha: selected ? .16 : .045),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: brand.color.withValues(alpha: selected ? .72 : .18),
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: brand.color.withValues(alpha: .18),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PaymentLogo(provider: provider, size: 36),
              const SizedBox(height: 7),
              Text(
                brand.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected
                      ? brand.color
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _conversionCard() => GlassPanel(
    accent: AppColors.success,
    padding: const EdgeInsets.all(AppSpacing.xl),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.lg,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('Ready to use CHEKMI?'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (!AppVariant.usesMinimalCopy) ...[
                const SizedBox(height: 6),
                Text(
                  context.tr(
                    'Compare Basic and Pro, then choose the right next step for your restaurant.',
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: _showPricing,
          icon: const Icon(AppIcons.tag),
          label: Text(AppVariant.usesMinimalCopy ? 'PLANS' : 'SEE PRICING'),
        ),
      ],
    ),
  );

  void _exit() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const BusinessGatewayScreen()),
      (_) => false,
    );
  }

  void _showPricing() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const PricingScreen(openedFromTrial: true),
      ),
    );
  }
}
