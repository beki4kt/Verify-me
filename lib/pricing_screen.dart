import 'package:flutter/material.dart';
import 'package:verify_me/core/theme/app_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'api_service.dart';
import 'business_gateway_screen.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_spacing.dart';
import 'core/theme/app_typography.dart';
import 'core/widgets/app_shell.dart';
import 'plan_catalog.dart';
import 'trial_mode_screen.dart';
import 'core/config/app_variant.dart';

class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key, this.openedFromTrial = false});

  final bool openedFromTrial;

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  BillingPeriod _period = BillingPeriod.monthly;
  PlanDefinition _selectedPlan = PlanCatalog.pro;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackdrop(
        maxWidth: 1160,
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.xxxl,
                ),
                sliver: SliverList.list(
                  children: [
                    _header(),
                    const SizedBox(height: AppSpacing.lg),
                    _decisionSurface(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() => Row(
    children: [
      IconButton(
        tooltip: 'Back',
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(AppIcons.back),
      ),
      const SizedBox(width: 4),
      const BrandLockup(compact: true),
      const Spacer(),
      const GlassLanguageToggleButton(),
      const GlassThemeToggleButton(),
    ],
  );

  Widget _decisionSurface() => GlassPanel(
    accent: _selectedPlan.recommended ? AppColors.primary : AppColors.aqua,
    padding: const EdgeInsets.all(AppSpacing.xl),
    child: Column(
      children: [
        _hero(),
        const SizedBox(height: AppSpacing.xl),
        _billingPicker(),
        const SizedBox(height: AppSpacing.xl),
        LayoutBuilder(
          builder: (context, constraints) {
            final basic = _PlanChoice(
              plan: PlanCatalog.basic,
              period: _period,
              selected: _selectedPlan.id == PlanCatalog.basic.id,
              onTap: () => setState(() => _selectedPlan = PlanCatalog.basic),
            );
            final pro = _PlanChoice(
              plan: PlanCatalog.pro,
              period: _period,
              selected: _selectedPlan.id == PlanCatalog.pro.id,
              onTap: () => setState(() => _selectedPlan = PlanCatalog.pro),
            );
            if (constraints.maxWidth >= 760) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: basic),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(child: pro),
                ],
              );
            }
            return Column(
              children: [
                basic,
                const SizedBox(height: AppSpacing.lg),
                pro,
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.xl),
        _actionBar(),
      ],
    ),
  ).animate().fadeIn(duration: 420.ms).scaleXY(begin: .985, end: 1);

  Widget _hero() => Column(
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.primary.withValues(alpha: .35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              AppIcons.sparkle,
              size: 16,
              color: AppColors.primarySoft,
            ),
            const SizedBox(width: 7),
            Text(
              AppVariant.usesMinimalCopy ? 'PLANS' : 'SIMPLE, FLEXIBLE PRICING',
              style: AppTypography.microLabel(color: AppColors.primarySoft),
            ),
          ],
        ),
      ).animate().fadeIn(delay: 80.ms).slideY(begin: -.15, end: 0),
      const SizedBox(height: AppSpacing.md),
      Text(
        AppVariant.usesMinimalCopy
            ? 'Choose a plan'
            : 'Two plans. One clear choice.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.displaySmall?.copyWith(
          fontSize: MediaQuery.sizeOf(context).width < 520 ? 30 : 40,
          height: 1.08,
          letterSpacing: -1,
        ),
      ).animate().fadeIn(delay: 130.ms).slideY(begin: .12, end: 0),
      if (!AppVariant.usesMinimalCopy) ...[
        const SizedBox(height: 8),
        Text(
          'Start small with Basic, or choose Pro for the complete restaurant command center.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ).animate().fadeIn(delay: 180.ms),
      ],
    ],
  );

  Widget _billingPicker() => Center(
    child: Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: .58),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: .18),
        ),
      ),
      child: SegmentedButton<BillingPeriod>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: BillingPeriod.monthly, label: Text('Monthly')),
          ButtonSegment(
            value: BillingPeriod.quarterly,
            label: Text('3 months · SAVE'),
            icon: Icon(AppIcons.savings),
          ),
        ],
        selected: {_period},
        onSelectionChanged: (value) => setState(() => _period = value.first),
      ),
    ),
  ).animate().fadeIn(delay: 220.ms).slideY(begin: .1, end: 0);

  Widget _actionBar() {
    final signedIn =
        ApiService.currentBusinessId != null &&
        ApiService.currentUserRole != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: (_selectedPlan.recommended ? AppColors.primary : AppColors.aqua)
            .withValues(alpha: .10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color:
              (_selectedPlan.recommended ? AppColors.primary : AppColors.aqua)
                  .withValues(alpha: .28),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 680;
          final summary = AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, .12),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: Column(
              key: ValueKey('${_selectedPlan.id}-${_period.name}'),
              crossAxisAlignment: compact
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                Text(
                  AppVariant.usesMinimalCopy
                      ? _selectedPlan.name
                      : '${_selectedPlan.name} is selected',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (!AppVariant.usesMinimalCopy) ...[
                  const SizedBox(height: 3),
                  Text(
                    signedIn
                        ? 'Send the owner team a billing request. Your current service stays active during review.'
                        : 'Connect your restaurant workspace and the CHEKMI team will activate your selection.',
                    textAlign: compact ? TextAlign.center : TextAlign.start,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          );
          final actions = Wrap(
            alignment: compact ? WrapAlignment.center : WrapAlignment.end,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              TextButton.icon(
                onPressed: _openTrial,
                icon: Icon(
                  widget.openedFromTrial
                      ? AppIcons.refresh
                      : AppIcons.playCircle,
                ),
                label: Text(
                  AppVariant.usesMinimalCopy
                      ? 'DEMO'
                      : (widget.openedFromTrial
                            ? 'REPLAY TRIAL'
                            : 'TRY IT FREE'),
                ),
              ),
              FilledButton.icon(
                onPressed: _submitting ? null : _continueWithPlan,
                icon: _submitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(signedIn ? AppIcons.send : AppIcons.forward),
                label: Text(
                  AppVariant.usesMinimalCopy
                      ? (signedIn ? 'REQUEST' : 'START')
                      : (signedIn
                            ? 'REQUEST ${_selectedPlan.name.toUpperCase()}'
                            : 'GET STARTED'),
                ),
              ),
            ],
          );
          if (compact) {
            return Column(
              children: [
                summary,
                const SizedBox(height: AppSpacing.md),
                actions,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: summary),
              const SizedBox(width: AppSpacing.lg),
              actions,
            ],
          );
        },
      ),
    ).animate().fadeIn(delay: 420.ms).slideY(begin: .08, end: 0);
  }

  void _openTrial() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const TrialModeScreen()),
    );
  }

  Future<void> _continueWithPlan() async {
    final signedIn =
        ApiService.currentBusinessId != null &&
        ApiService.currentUserRole != null;
    if (!signedIn) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const BusinessGatewayScreen()),
        (_) => false,
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final billingLabel = _period == BillingPeriod.monthly
          ? 'monthly'
          : 'three-month';
      await ApiService.openSupportCase(
        category: 'billing',
        subject: '${_selectedPlan.name} plan request',
        description:
            'Please review and activate the ${_selectedPlan.name} plan on the $billingLabel billing cycle for this restaurant.',
        priority: 'normal',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_selectedPlan.name} request sent. The owner team can now review it.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _PlanChoice extends StatelessWidget {
  const _PlanChoice({
    required this.plan,
    required this.period,
    required this.selected,
    required this.onTap,
  });

  final PlanDefinition plan;
  final BillingPeriod period;
  final bool selected;
  final VoidCallback onTap;

  static const _basicFeatures = [
    '2,500 verifications each month',
    '1 staff seat and all 6 providers',
    'Receipt scanning and live tickets',
    'Recent transaction history',
  ];

  static const _proFeatures = [
    'Unlimited verifications and staff',
    'Daily revenue reports and bank analytics',
    'Cashier controls and tip payouts',
    'Evidence archive and priority support',
  ];

  static const _minimalBasicFeatures = [
    '2,500 checks / month',
    '1 staff · 6 providers',
    'Scan · tickets · history',
  ];

  static const _minimalProFeatures = [
    'Unlimited checks · staff',
    'Reports · analytics',
    'Cashier · tips · support',
  ];

  @override
  Widget build(BuildContext context) {
    final accent = plan.recommended ? AppColors.primary : AppColors.aqua;
    final price = plan.priceFor(period);
    final savings = period == BillingPeriod.quarterly
        ? plan.quarterlySavingsEtb
        : null;
    final features = AppVariant.usesMinimalCopy
        ? (plan.recommended ? _minimalProFeatures : _minimalBasicFeatures)
        : (plan.recommended ? _proFeatures : _basicFeatures);
    return Semantics(
          button: true,
          selected: selected,
          label: 'Choose ${plan.name}',
          child: AnimatedScale(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            scale: selected ? 1 : .975,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: selected
                    ? accent.withValues(alpha: .105)
                    : Theme.of(context).colorScheme.surface
                          .withValues(alpha: .38),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: selected
                      ? accent.withValues(alpha: .76)
                      : Theme.of(context).colorScheme.outline
                            .withValues(alpha: .16),
                  width: selected ? 2 : 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: .16),
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                        ),
                      ]
                    : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(26),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 280),
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: plan.recommended
                                      ? const [
                                          AppColors.primary,
                                          AppColors.pink,
                                        ]
                                      : const [
                                          AppColors.aqua,
                                          AppColors.brandBlue,
                                        ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: selected
                                    ? [
                                        BoxShadow(
                                          color: accent.withValues(alpha: .25),
                                          blurRadius: 18,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Icon(
                                plan.recommended
                                    ? AppIcons.premium
                                    : AppIcons.quickAction,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    plan.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall,
                                  ),
                                  if (!AppVariant.usesMinimalCopy)
                                    Text(
                                      plan.recommended
                                          ? 'Complete operations'
                                          : 'Verification essentials',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                ],
                              ),
                            ),
                            if (plan.recommended)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [AppColors.primary, AppColors.pink],
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  AppVariant.usesMinimalCopy
                                      ? 'PRO'
                                      : 'BEST CHOICE',
                                  style: AppTypography.microLabel(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(
                                  scale: Tween(
                                    begin: .94,
                                    end: 1.0,
                                  ).animate(animation),
                                  child: child,
                                ),
                              ),
                          child: price == null
                              ? Column(
                                  key: ValueKey('${plan.id}-${period.name}'),
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Tailored',
                                      style: AppTypography.money(
                                        size: 34,
                                        color: accent,
                                      ),
                                    ),
                                    Text(
                                      'Sized to your restaurant',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ],
                                )
                              : Column(
                                  key: ValueKey('${plan.id}-${period.name}'),
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$price ETB',
                                      style: AppTypography.money(
                                        size: 34,
                                        color: accent,
                                      ),
                                    ),
                                    Text(
                                      period == BillingPeriod.monthly
                                          ? 'per month'
                                          : 'for 3 months',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                    if (savings != null && savings > 0) ...[
                                      const SizedBox(height: 5),
                                      Text(
                                        'Save $savings ETB',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.copyWith(
                                              color: AppColors.success,
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        for (final feature in features) ...[
                          _FeatureLine(label: feature, accent: accent),
                          const SizedBox(height: 10),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: selected ? accent : Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(color: accent, width: 2),
                              ),
                              child: selected
                                  ? const Icon(
                                      AppIcons.check,
                                      color: Colors.white,
                                      size: 15,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 9),
                            Text(
                              selected
                                  ? 'SELECTED'
                                  : (AppVariant.usesMinimalCopy
                                        ? 'SELECT'
                                        : 'TAP TO SELECT'),
                              style: AppTypography.microLabel(color: accent),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(delay: (plan.recommended ? 340 : 280).ms)
        .slideX(begin: plan.recommended ? .05 : -.05, end: 0);
  }
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(AppIcons.success, size: 18, color: accent),
      const SizedBox(width: 9),
      Expanded(
        child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ),
    ],
  );
}
