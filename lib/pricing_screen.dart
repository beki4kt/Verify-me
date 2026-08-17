import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'business_gateway_screen.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_spacing.dart';
import 'core/theme/app_typography.dart';
import 'core/widgets/app_shell.dart';
import 'plan_catalog.dart';
import 'trial_mode_screen.dart';

class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key, this.openedFromTrial = false});

  final bool openedFromTrial;

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  BillingPeriod _period = BillingPeriod.monthly;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackdrop(
        maxWidth: 1220,
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
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xxxl,
              ),
              sliver: SliverList.list(
                children: [
                  _hero(),
                  const SizedBox(height: AppSpacing.xl),
                  _trialBanner(),
                  const SizedBox(height: AppSpacing.xl),
                  _billingPicker(),
                  const SizedBox(height: AppSpacing.xl),
                  _planCards(),
                  const SizedBox(height: AppSpacing.xxxl),
                  _comparison(),
                  const SizedBox(height: AppSpacing.xl),
                  _closingCard(),
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
      IconButton(
        tooltip: 'Back',
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      const SizedBox(width: 4),
      const BrandLockup(compact: true),
      const Spacer(),
      const GlassLanguageToggleButton(),
      const GlassThemeToggleButton(),
    ],
  );

  Widget _hero() => Semantics(
    header: true,
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.primary.withValues(alpha: .34)),
          ),
          child: Text(
            'SIMPLE, FLEXIBLE PRICING',
            style: AppTypography.microLabel(color: AppColors.primarySoft),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Choose the plan that grows\nwith your restaurant',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
            fontSize: MediaQuery.sizeOf(context).width < 520 ? 34 : 48,
            height: 1.08,
            letterSpacing: -1.3,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Text(
            'Start with reliable payment verification, then unlock the reporting, team controls, and operational tools that make CHEKMI your daily command center.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(height: 1.55),
          ),
        ),
      ],
    ),
  ).animate().fadeIn(duration: 450.ms).slideY(begin: .06, end: 0);

  Widget _trialBanner() => GlassPanel(
    accent: AppColors.aqua,
    padding: const EdgeInsets.all(AppSpacing.xl),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final copy = Column(
          crossAxisAlignment: compact
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.aqua,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'FREE INTERACTIVE TRIAL',
                  style: AppTypography.microLabel(color: AppColors.aqua),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.openedFromTrial
                  ? 'You explored CHEKMI. Now choose your next step.'
                  : 'See the Pro experience before you choose.',
              textAlign: compact ? TextAlign.center : TextAlign.start,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 5),
            Text(
              'Try waiter, cashier, and admin workflows with sample data—no account, setup, or live payment required.',
              textAlign: compact ? TextAlign.center : TextAlign.start,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        );
        final action = OutlinedButton.icon(
          onPressed: _openTrial,
          icon: Icon(
            widget.openedFromTrial
                ? Icons.replay_rounded
                : Icons.play_arrow_rounded,
          ),
          label: Text(widget.openedFromTrial ? 'REPLAY TRIAL' : 'TRY IT FREE'),
        );
        if (compact) {
          return Column(
            children: [
              copy,
              const SizedBox(height: AppSpacing.lg),
              action,
            ],
          );
        }
        return Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.aqua.withValues(alpha: .13),
                borderRadius: BorderRadius.circular(19),
              ),
              child: const Icon(
                Icons.smart_display_rounded,
                color: AppColors.aqua,
                size: 30,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(child: copy),
            const SizedBox(width: AppSpacing.lg),
            action,
          ],
        );
      },
    ),
  ).animate().fadeIn(delay: 100.ms).slideY(begin: .05, end: 0);

  Widget _billingPicker() => Center(
    child: Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: .18),
        ),
      ),
      child: SegmentedButton<BillingPeriod>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: BillingPeriod.monthly,
            label: Text('Monthly'),
            icon: Icon(Icons.calendar_view_month_rounded),
          ),
          ButtonSegment(
            value: BillingPeriod.quarterly,
            label: Text('3 months  •  SAVE'),
            icon: Icon(Icons.savings_outlined),
          ),
        ],
        selected: {_period},
        onSelectionChanged: (value) => setState(() => _period = value.first),
      ),
    ),
  );

  Widget _planCards() => LayoutBuilder(
    builder: (context, constraints) {
      final basic = _PlanCard(
        plan: PlanCatalog.basic,
        period: _period,
        onSelected: () => _selectPlan(PlanCatalog.basic),
      );
      final pro = _PlanCard(
        plan: PlanCatalog.pro,
        period: _period,
        onSelected: () => _selectPlan(PlanCatalog.pro),
      );
      if (constraints.maxWidth >= 820) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: basic),
            const SizedBox(width: AppSpacing.xl),
            Expanded(child: pro),
          ],
        );
      }
      return Column(
        children: [
          basic,
          const SizedBox(height: AppSpacing.xl),
          pro,
        ],
      );
    },
  );

  Widget _comparison() {
    const rows = [
      ('Monthly verifications', '2,500', 'Unlimited'),
      ('Staff seats', '1', 'Unlimited'),
      ('Payment providers', 'All 6', 'All 6'),
      ('Receipt scan & live ticket queue', 'Included', 'Included'),
      ('Daily revenue reports', '—', 'Included'),
      ('Staff, date & provider analytics', '—', 'Included'),
      ('Cashier and tip payout workflows', '—', 'Included'),
      ('Receipt evidence archive', '—', 'Included'),
      ('Multi-device operations', '—', 'Included'),
      ('Support', 'Standard', 'Priority'),
    ];
    return Column(
      children: [
        Text(
          'Compare every detail',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 6),
        Text(
          'Basic keeps verification simple. Pro turns payment data into operational control.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xl),
        GlassPanel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              const _ComparisonHeader(),
              for (var index = 0; index < rows.length; index++)
                _ComparisonRow(
                  label: rows[index].$1,
                  basic: rows[index].$2,
                  pro: rows[index].$3,
                  shaded: index.isEven,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _closingCard() => GlassPanel(
    accent: AppColors.primary,
    padding: const EdgeInsets.all(AppSpacing.xl),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.xl,
      runSpacing: AppSpacing.lg,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 670),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Already have a CHEKMI workspace?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 5),
              Text(
                'Connect this device with the workspace code provided during onboarding.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: _connectWorkspace,
          icon: const Icon(Icons.login_rounded),
          label: const Text('CONNECT WORKSPACE'),
        ),
      ],
    ),
  );

  void _openTrial() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const TrialModeScreen()),
    );
  }

  void _connectWorkspace() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const BusinessGatewayScreen()),
      (_) => false,
    );
  }

  Future<void> _selectPlan(PlanDefinition plan) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          MediaQuery.viewInsetsOf(sheetContext).bottom + AppSpacing.lg,
        ),
        child: GlassPanel(
          accent: plan.recommended ? AppColors.primary : AppColors.aqua,
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          (plan.recommended
                                  ? AppColors.primary
                                  : AppColors.aqua)
                              .withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      plan.recommended
                          ? Icons.workspace_premium_rounded
                          : Icons.rocket_launch_rounded,
                      color: plan.recommended
                          ? AppColors.primarySoft
                          : AppColors.aqua,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${plan.name} selected',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          plan.recommended
                              ? 'Pro pricing will be finalized with your commercial setup.'
                              : 'Your selected billing cycle is ${_period == BillingPeriod.monthly ? 'monthly' : 'every 3 months'}.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                plan.recommended
                    ? 'Choose Pro for unlimited growth, complete revenue visibility, cashier controls, and priority support.'
                    : 'Choose Basic for focused payment verification with one staff seat and predictable limits.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _connectWorkspace();
                },
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(
                  plan.recommended
                      ? 'CONTINUE WITH PRO'
                      : 'CONTINUE WITH BASIC',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.period,
    required this.onSelected,
  });

  final PlanDefinition plan;
  final BillingPeriod period;
  final VoidCallback onSelected;

  static const _basicFeatures = [
    '2,500 payment verifications every month',
    '1 staff seat',
    'All 6 supported payment providers',
    'Receipt scanning and live ticket queue',
    'Recent transaction history',
  ];

  static const _proFeatures = [
    'Unlimited payment verifications',
    'Unlimited staff seats',
    'Daily revenue reports and bank analytics',
    'Advanced date, staff, and provider filters',
    'Cashier workspace and tip payout controls',
    'Receipt evidence archive and multi-device access',
    'Priority onboarding and support',
  ];

  @override
  Widget build(BuildContext context) {
    final accent = plan.recommended ? AppColors.primary : AppColors.aqua;
    final price = plan.priceFor(period);
    final savings = period == BillingPeriod.quarterly
        ? plan.quarterlySavingsEtb
        : null;
    final features = plan.recommended ? _proFeatures : _basicFeatures;
    return Stack(
          clipBehavior: Clip.none,
          children: [
            GlassPanel(
              accent: plan.recommended ? accent : null,
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: plan.recommended
                                ? const [AppColors.primary, AppColors.violet]
                                : const [AppColors.aqua, AppColors.brandBlue],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          plan.recommended
                              ? Icons.workspace_premium_rounded
                              : Icons.bolt_rounded,
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
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              plan.recommended
                                  ? 'The complete CHEKMI experience'
                                  : 'Reliable verification essentials',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    child: price == null
                        ? Column(
                            key: ValueKey('${plan.id}-${period.name}'),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Custom',
                                style: AppTypography.money(
                                  size: 38,
                                  color: accent,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Flexible pricing for your operation',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          )
                        : Column(
                            key: ValueKey('${plan.id}-${period.name}-$price'),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.end,
                                spacing: 8,
                                children: [
                                  Text(
                                    '$price ETB',
                                    style: AppTypography.money(
                                      size: 38,
                                      color: accent,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 7),
                                    child: Text(
                                      period == BillingPeriod.monthly
                                          ? '/ month'
                                          : '/ 3 months',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                period == BillingPeriod.monthly
                                    ? 'Billed monthly'
                                    : '1,000 ETB/month effective  •  Save $savings ETB',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: savings == null
                                          ? null
                                          : AppColors.success,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    plan.tagline,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(height: 1.45),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Divider(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: .16),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    plan.recommended ? 'EVERYTHING IN BASIC, PLUS' : 'INCLUDED',
                    style: AppTypography.microLabel(color: accent),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final feature in features) ...[
                    _FeatureLine(label: feature, accent: accent),
                    const SizedBox(height: 11),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  if (plan.recommended)
                    FilledButton.icon(
                      onPressed: onSelected,
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: const Text('CHOOSE PRO'),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: onSelected,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('CHOOSE BASIC'),
                    ),
                ],
              ),
            ),
            if (plan.recommended)
              Positioned(
                top: -13,
                right: 24,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.pink],
                    ),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: .3),
                        blurRadius: 18,
                        offset: const Offset(0, 7),
                      ),
                    ],
                  ),
                  child: Text(
                    'BEST CHOICE',
                    style: AppTypography.microLabel(color: Colors.white),
                  ),
                ),
              ),
          ],
        )
        .animate()
        .fadeIn(delay: (plan.recommended ? 180 : 120).ms)
        .slideY(begin: .05, end: 0);
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
      Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: .13),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.check_rounded, size: 15, color: accent),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ),
    ],
  );
}

class _ComparisonHeader extends StatelessWidget {
  const _ComparisonHeader();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    child: const Row(
      children: [
        Expanded(flex: 5, child: Text('FEATURE')),
        Expanded(flex: 2, child: Center(child: Text('BASIC'))),
        Expanded(flex: 2, child: Center(child: Text('PRO'))),
      ],
    ),
  );
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({
    required this.label,
    required this.basic,
    required this.pro,
    required this.shaded,
  });

  final String label;
  final String basic;
  final String pro;
  final bool shaded;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      color: shaded
          ? Theme.of(context).colorScheme.onSurface.withValues(alpha: .035)
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                basic,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: basic == '—' ? muted.withValues(alpha: .45) : null,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: pro == 'Included'
                  ? const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                      size: 20,
                    )
                  : Text(
                      pro,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.primarySoft,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
