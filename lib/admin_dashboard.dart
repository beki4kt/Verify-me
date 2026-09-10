import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:verify_me/core/theme/app_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'api_service.dart';
import 'staff_login_screen.dart'; // FIXED: Swapped to the active login screen
import 'core/theme/app_colors.dart';
import 'core/theme/app_motion.dart';
import 'core/theme/app_spacing.dart';
import 'core/theme/app_typography.dart';
import 'core/widgets/app_shell.dart';
import 'core/widgets/metric_card.dart';
import 'core/widgets/payment_brand.dart';
import 'core/widgets/state_views.dart';
import 'core/widgets/transaction_filter_bar.dart';
import 'localization_service.dart';
import 'plan_catalog.dart';
import 'pricing_screen.dart';
import 'support_privacy_screen.dart';
import 'core/config/app_variant.dart';
import 'core/config/payment_context.dart';
import 'iphone/iphone_dashboard_shell.dart';

class _PaymentAccountProvider {
  const _PaymentAccountProvider({
    required this.name,
    required this.description,
    required this.numberLabel,
    required this.numberKey,
    required this.nameKey,
    required this.icon,
    required this.color,
  });

  final String name;
  final String description;
  final String numberLabel;
  final String numberKey;
  final String nameKey;
  final IconData icon;
  final Color color;
}

const _paymentAccountProviders = <_PaymentAccountProvider>[
  _PaymentAccountProvider(
    name: 'Telebirr',
    description: 'Mobile or merchant account that receives Telebirr payments.',
    numberLabel: 'Mobile / merchant number',
    numberKey: 'telebirr_number',
    nameKey: 'telebirr_name',
    icon: AppIcons.mobile,
    color: Color(0xFF0EA5E9),
  ),
  _PaymentAccountProvider(
    name: 'Commercial Bank of Ethiopia',
    description: 'Official CBE account used for business transfers.',
    numberLabel: 'CBE account number',
    numberKey: 'cbe_number',
    nameKey: 'cbe_name',
    icon: AppIcons.banking,
    color: Color(0xFFA855F7),
  ),
  _PaymentAccountProvider(
    name: 'CBE Birr',
    description: 'Wallet or phone number registered to the business.',
    numberLabel: 'CBE Birr wallet number',
    numberKey: 'cbebirr_number',
    nameKey: 'cbebirr_name',
    icon: AppIcons.wallet,
    color: Color(0xFF7C3AED),
  ),
  _PaymentAccountProvider(
    name: 'Dashen Bank',
    description: 'Official Dashen account used for incoming payments.',
    numberLabel: 'Dashen account number',
    numberKey: 'dashen_number',
    nameKey: 'dashen_name',
    icon: AppIcons.banking,
    color: Color(0xFFF59E0B),
  ),
  _PaymentAccountProvider(
    name: 'Bank of Abyssinia',
    description: 'Official Abyssinia account used for incoming payments.',
    numberLabel: 'Abyssinia account number',
    numberKey: 'abyssinia_number',
    nameKey: 'abyssinia_name',
    icon: AppIcons.banking,
    color: Color(0xFFEF4444),
  ),
  _PaymentAccountProvider(
    name: 'M-Pesa',
    description: 'Business mobile wallet, paybill, or till number.',
    numberLabel: 'M-Pesa number / till',
    numberKey: 'mpesa_number',
    nameKey: 'mpesa_name',
    icon: AppIcons.wallet,
    color: Color(0xFF22C55E),
  ),
];

List<_PaymentAccountProvider> get _enabledPaymentAccountProviders =>
    _paymentAccountProviders
        .where((provider) => AppVariant.isPaymentProviderEnabled(provider.name))
        .toList(growable: false);

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  late Stream<List<Map<String, dynamic>>> _ticketsStream;
  late Stream<List<Map<String, dynamic>>> _staffStream;
  late Stream<Map<String, dynamic>> _businessStream;
  late Stream<List<Map<String, dynamic>>> _withdrawalRequestsStream;
  StreamSubscription<List<Map<String, dynamic>>>? _staffCacheSubscription;
  StreamSubscription<Map<String, dynamic>>? _businessPlanSubscription;
  final Map<String, String> _staffLabels = {};
  final Set<String> _staffStatusUpdates = <String>{};
  final Set<String> _withdrawalUpdates = <String>{};
  List<Map<String, dynamic>> _staffRoster = const [];
  Object? _staffRosterError;
  bool _staffRosterLoaded = false;
  PlanDefinition _activePlan = PlanCatalog.basic;
  TransactionPeriod _ledgerPeriod = TransactionPeriod.daily;
  DateTimeRange? _ledgerCustomRange;
  String? _ledgerStaff;
  String? _ledgerPaymentMethod;

  @override
  void initState() {
    super.initState();
    _setDataStreams();
    _staffCacheSubscription = _staffStream.listen(
      (staff) {
        if (!mounted) return;
        setState(() {
          _staffRoster = List<Map<String, dynamic>>.unmodifiable(
            staff.map((member) => Map<String, dynamic>.from(member)),
          );
          _staffRosterLoaded = true;
          _staffRosterError = null;
          _staffLabels
            ..clear()
            ..addEntries(
              staff.map(
                (member) => MapEntry(
                  member['staff_number'].toString(),
                  member['name']?.toString() ??
                      'Staff ${member['staff_number']}',
                ),
              ),
            );
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _staffRosterLoaded = true;
          _staffRosterError = error;
        });
      },
      onDone: () {
        if (!mounted || _staffRosterLoaded) return;
        setState(() => _staffRosterLoaded = true);
      },
    );
    _businessPlanSubscription = _businessStream.listen((business) {
      if (!mounted) return;
      final plan = PlanCatalog.fromTier(
        business['subscription_tier']?.toString(),
      );
      if (plan.id == _activePlan.id) return;
      setState(() => _activePlan = plan);
    });
  }

  @override
  void dispose() {
    _staffCacheSubscription?.cancel();
    _businessPlanSubscription?.cancel();
    super.dispose();
  }

  Widget _buildProInsightsLock() {
    if (!AppVariant.showsPlanMarketing) {
      return const GlassPanel(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Row(
          children: [
            Icon(AppIcons.lock, color: AppColors.textMuted),
            SizedBox(width: AppSpacing.md),
            Expanded(child: Text('Not included for this workspace.')),
          ],
        ),
      );
    }
    return GlassPanel(
      accent: AppColors.primary,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final copy = Column(
            crossAxisAlignment: compact
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    AppIcons.premium,
                    color: AppColors.primarySoft,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'PRO INSIGHTS',
                    style: AppTypography.microLabel(
                      color: AppColors.primarySoft,
                    ),
                  ),
                ],
              ),
              if (!AppVariant.usesMinimalCopy) ...[
                const SizedBox(height: 8),
                Text(
                  'Turn every verification into a clearer business decision.',
                  textAlign: compact ? TextAlign.center : TextAlign.start,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Upgrade to Pro for daily revenue reports, bank deposit analytics, and staff, date, and provider filters.',
                  textAlign: compact ? TextAlign.center : TextAlign.start,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          );
          final action = FilledButton.icon(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const PricingScreen())),
            icon: const Icon(AppIcons.sparkle),
            label: Text(AppVariant.usesMinimalCopy ? 'PLANS' : 'EXPLORE PRO'),
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
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.violet],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(AppIcons.analytics, color: Colors.white),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(child: copy),
              const SizedBox(width: AppSpacing.lg),
              action,
            ],
          );
        },
      ),
    );
  }

  void _setDataStreams() {
    _ticketsStream = _serverTicketReport();
    _staffStream = ApiService.streamStaffRoster().asBroadcastStream();
    _businessStream = ApiService.streamCurrentBusiness().asBroadcastStream();
    _withdrawalRequestsStream = ApiService.streamTipWithdrawalRequests();
  }

  void _refreshData() {
    ApiService.refreshDashboardData();
    setState(() => _ticketsStream = _serverTicketReport());
  }

  Stream<List<Map<String, dynamic>>> _serverTicketReport() {
    final now = DateTime.now();
    DateTime? from;
    DateTime? to;
    switch (_ledgerPeriod) {
      case TransactionPeriod.daily:
        from = DateTime(now.year, now.month, now.day);
      case TransactionPeriod.weekly:
        final today = DateTime(now.year, now.month, now.day);
        from = today.subtract(const Duration(days: 6));
      case TransactionPeriod.custom:
        final range = _ledgerCustomRange;
        if (range != null) {
          from = DateTime(range.start.year, range.start.month, range.start.day);
          to = DateTime(range.end.year, range.end.month, range.end.day + 1);
        }
      case TransactionPeriod.all:
        break;
    }
    return ApiService.streamTicketReport(
      from: from,
      to: to,
      staffNumber: _ledgerStaff,
      provider: _ledgerPaymentMethod,
    );
  }

  List<Map<String, dynamic>> _filteredTickets(
    List<Map<String, dynamic>> tickets,
  ) => filterTransactions(
    tickets,
    period: _ledgerPeriod,
    customRange: _ledgerCustomRange,
    staffNumber: _ledgerStaff,
    paymentMethod: _ledgerPaymentMethod,
  );

  Future<void> _changeLedgerPeriod(TransactionPeriod period) async {
    if (period == TransactionPeriod.custom) {
      final now = DateTime.now();
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 2),
        lastDate: now,
        initialDateRange: _ledgerCustomRange,
      );
      if (picked == null || !mounted) return;
      setState(() {
        _ledgerPeriod = period;
        _ledgerCustomRange = picked;
        _ticketsStream = _serverTicketReport();
      });
      return;
    }
    setState(() {
      _ledgerPeriod = period;
      _ticketsStream = _serverTicketReport();
    });
  }

  Widget _buildLedgerFilters(List<Map<String, dynamic>> tickets) {
    final staff = <String, String>{};
    final methods = <String>{};
    for (final ticket in tickets) {
      final staffNumber = ticket['waiter_id']?.toString();
      final method = ticket['bank']?.toString();
      if (staffNumber != null && staffNumber.isNotEmpty) {
        staff[staffNumber] = _staffLabels[staffNumber] ?? 'Staff $staffNumber';
      }
      if (method != null && method.isNotEmpty) methods.add(method);
    }
    return TransactionFilterBar(
      period: _ledgerPeriod,
      customRange: _ledgerCustomRange,
      onPeriodChanged: _changeLedgerPeriod,
      staffMembers: staff,
      staffNumber: _ledgerStaff,
      onStaffChanged: (value) => setState(() {
        _ledgerStaff = value;
        _ticketsStream = _serverTicketReport();
      }),
      paymentMethods: {
        ...methods,
        'telebirr',
        'cbe',
        'cbebirr',
        'dashen',
        'abyssinia',
        'mpesa',
      }.toList()..sort(),
      paymentMethod: _ledgerPaymentMethod,
      onPaymentMethodChanged: (value) => setState(() {
        _ledgerPaymentMethod = value;
        _ticketsStream = _serverTicketReport();
      }),
    );
  }

  String _formatLedgerDate(dynamic raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (date == null) return 'Unknown time';
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)} ${two(date.hour)}:${two(date.minute)}';
  }

  List<DropdownMenuItem<String>> _getAvailableRoles() {
    List<DropdownMenuItem<String>> roles = [
      const DropdownMenuItem(value: 'waiter', child: Text('Staff')),
    ];
    if (ApiService.currentBusinessHasCashier == true) {
      roles.insert(
        0,
        const DropdownMenuItem(value: 'cashier', child: Text('Cashier')),
      );
    }
    return roles;
  }

  Color _getBankColor(String bank) {
    if (bank.toLowerCase().contains('telebirr')) return const Color(0xFF0EA5E9);
    if (bank.toLowerCase().contains('cbe')) return const Color(0xFFA855F7);
    if (bank.toLowerCase().contains('dashen')) return const Color(0xFFF59E0B);
    return AppColors.textFaint;
  }

  Future<void> _showBankConfigSheet(
    Map<String, dynamic> currentAccounts,
  ) async {
    final numberControllers = {
      for (final provider in _enabledPaymentAccountProviders)
        provider.numberKey: TextEditingController(
          text: currentAccounts[provider.numberKey]?.toString() ?? '',
        ),
    };
    final nameControllers = {
      for (final provider in _enabledPaymentAccountProviders)
        provider.nameKey: TextEditingController(
          text: currentAccounts[provider.nameKey]?.toString() ?? '',
        ),
    };
    var selectedProvider = _enabledPaymentAccountProviders.first;
    bool isSubmitting = false;
    String? errorText;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final theme = Theme.of(sheetContext);
            final configuredCount = _enabledPaymentAccountProviders.where((
              provider,
            ) {
              return numberControllers[provider.numberKey]!.text
                  .trim()
                  .isNotEmpty;
            }).length;

            return FractionallySizedBox(
              heightFactor: .94,
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: .2),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        24,
                        20,
                        24,
                        MediaQuery.of(sheetContext).viewInsets.bottom + 24,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
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
                                      color: AppColors.success.withValues(
                                        alpha: .12,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(
                                      AppIcons.banking,
                                      color: AppColors.success,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Payment accounts',
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w900,
                                              ),
                                        ),
                                        if (!AppVariant.usesMinimalCopy) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'Add the official receiving account for every provider your business accepts.',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                  height: 1.4,
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withValues(
                                        alpha: .1,
                                      ),
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                    child: Text(
                                      '$configuredCount / ${_enabledPaymentAccountProviders.length}',
                                      style: const TextStyle(
                                        color: AppColors.success,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (!AppVariant.usesMinimalCopy) ...[
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: .08,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: AppColors.primary.withValues(
                                        alpha: .18,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        AppIcons.secureUser,
                                        color: AppColors.primary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Receipt destinations are checked against these values. Leave a provider blank only when the business does not accept it.',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(height: 1.45),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 18),
                              DropdownButtonFormField<String>(
                                initialValue: selectedProvider.numberKey,
                                decoration: const InputDecoration(
                                  labelText: 'Payment method',
                                  prefixIcon: Icon(AppIcons.money),
                                ),
                                items: _enabledPaymentAccountProviders
                                    .map(
                                      (provider) => DropdownMenuItem(
                                        value: provider.numberKey,
                                        child: PaymentBrand(
                                          provider: provider.name,
                                          logoSize: 26,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setSheetState(() {
                                    selectedProvider =
                                        _enabledPaymentAccountProviders
                                            .firstWhere(
                                              (provider) =>
                                                  provider.numberKey == value,
                                            );
                                  });
                                },
                              ),
                              const SizedBox(height: 14),
                              ..._enabledPaymentAccountProviders
                                  .where(
                                    (provider) =>
                                        provider.numberKey ==
                                        selectedProvider.numberKey,
                                  )
                                  .map((provider) {
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 14,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: provider.color.withValues(
                                            alpha: .045,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: provider.color.withValues(
                                              alpha: .2,
                                            ),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                PaymentLogo(
                                                  provider: provider.name,
                                                  size: 40,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        provider.name,
                                                        style: theme
                                                            .textTheme
                                                            .titleSmall
                                                            ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w900,
                                                            ),
                                                      ),
                                                      if (!AppVariant
                                                          .usesMinimalCopy) ...[
                                                        const SizedBox(
                                                          height: 2,
                                                        ),
                                                        Text(
                                                          provider.description,
                                                          style: theme
                                                              .textTheme
                                                              .bodySmall
                                                              ?.copyWith(
                                                                color: theme
                                                                    .colorScheme
                                                                    .onSurfaceVariant,
                                                              ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 14),
                                            LayoutBuilder(
                                              builder: (context, constraints) {
                                                final numberField = TextField(
                                                  controller:
                                                      numberControllers[provider
                                                          .numberKey],
                                                  keyboardType:
                                                      TextInputType.text,
                                                  textInputAction:
                                                      TextInputAction.next,
                                                  inputFormatters: [
                                                    FilteringTextInputFormatter.allow(
                                                      RegExp(
                                                        r'[0-9A-Za-z+\- ]',
                                                      ),
                                                    ),
                                                    LengthLimitingTextInputFormatter(
                                                      32,
                                                    ),
                                                  ],
                                                  onChanged: (_) =>
                                                      setSheetState(() {}),
                                                  decoration:
                                                      _buildInputDecoration(
                                                        provider.numberLabel,
                                                        AppIcons.number,
                                                      ),
                                                );
                                                final nameField = TextField(
                                                  controller:
                                                      nameControllers[provider
                                                          .nameKey],
                                                  textCapitalization:
                                                      TextCapitalization.words,
                                                  textInputAction:
                                                      TextInputAction.next,
                                                  maxLength: 80,
                                                  decoration:
                                                      _buildInputDecoration(
                                                        'Account holder / merchant name',
                                                        AppIcons.storefront,
                                                      ).copyWith(
                                                        counterText: '',
                                                      ),
                                                );
                                                if (constraints.maxWidth <
                                                    560) {
                                                  return Column(
                                                    children: [
                                                      numberField,
                                                      const SizedBox(
                                                        height: 12,
                                                      ),
                                                      nameField,
                                                    ],
                                                  );
                                                }
                                                return Row(
                                                  children: [
                                                    Expanded(
                                                      child: numberField,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(child: nameField),
                                                  ],
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                              if (errorText != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: AppColors.danger.withValues(
                                      alpha: .1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.danger),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        AppIcons.error,
                                        color: AppColors.danger,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          errorText!,
                                          style: const TextStyle(
                                            color: AppColors.danger,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              FilledButton.icon(
                                onPressed: isSubmitting
                                    ? null
                                    : () async {
                                        for (final provider
                                            in _enabledPaymentAccountProviders) {
                                          final number =
                                              numberControllers[provider
                                                      .numberKey]!
                                                  .text
                                                  .trim();
                                          final holder =
                                              nameControllers[provider.nameKey]!
                                                  .text
                                                  .trim();
                                          if (number.isEmpty &&
                                              holder.isNotEmpty) {
                                            setSheetState(() {
                                              errorText =
                                                  'Enter the ${provider.name} account number or clear its account-holder name.';
                                            });
                                            return;
                                          }
                                          if (number.isNotEmpty &&
                                              number.length < 5) {
                                            setSheetState(() {
                                              errorText =
                                                  '${provider.name} account number looks too short.';
                                            });
                                            return;
                                          }
                                        }

                                        setSheetState(() {
                                          isSubmitting = true;
                                          errorText = null;
                                        });
                                        try {
                                          final updatedAccounts =
                                              Map<String, dynamic>.from(
                                                currentAccounts,
                                              );
                                          for (final provider
                                              in _enabledPaymentAccountProviders) {
                                            final number =
                                                numberControllers[provider
                                                        .numberKey]!
                                                    .text
                                                    .trim();
                                            final holder =
                                                nameControllers[provider
                                                        .nameKey]!
                                                    .text
                                                    .trim();
                                            if (number.isEmpty) {
                                              updatedAccounts.remove(
                                                provider.numberKey,
                                              );
                                              updatedAccounts.remove(
                                                provider.nameKey,
                                              );
                                            } else {
                                              updatedAccounts[provider
                                                      .numberKey] =
                                                  number;
                                              if (holder.isEmpty) {
                                                updatedAccounts.remove(
                                                  provider.nameKey,
                                                );
                                              } else {
                                                updatedAccounts[provider
                                                        .nameKey] =
                                                    holder;
                                              }
                                            }
                                          }
                                          await ApiService.updateBankAccounts(
                                            updatedAccounts,
                                          );
                                          if (!sheetContext.mounted) return;
                                          Navigator.of(sheetContext).pop();
                                          if (mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Accounts updated.',
                                                    ),
                                                  ),
                                                );
                                          }
                                        } catch (error) {
                                          if (!sheetContext.mounted) return;
                                          setSheetState(() {
                                            isSubmitting = false;
                                            errorText = error
                                                .toString()
                                                .replaceFirst(
                                                  'Exception: ',
                                                  '',
                                                );
                                          });
                                        }
                                      },
                                icon: isSubmitting
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(AppIcons.save),
                                label: Text(
                                  isSubmitting
                                      ? 'Saving accounts…'
                                      : 'Save payment accounts',
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 18,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    for (final controller in numberControllers.values) {
      controller.dispose();
    }
    for (final controller in nameControllers.values) {
      controller.dispose();
    }
  }

  Future<void> _showChangePasswordSheet() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isSubmitting = false;
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirmation = true;
    String? errorText;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final theme = Theme.of(sheetContext);

            Widget passwordField({
              required TextEditingController controller,
              required String label,
              required String hint,
              required bool obscure,
              required VoidCallback toggleVisibility,
              TextInputAction textInputAction = TextInputAction.next,
            }) {
              return TextField(
                controller: controller,
                obscureText: obscure,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: textInputAction,
                decoration: _buildInputDecoration(label, AppIcons.lock)
                    .copyWith(
                      hintText: hint,
                      suffixIcon: IconButton(
                        tooltip: obscure ? 'Show password' : 'Hide password',
                        onPressed: toggleVisibility,
                        icon: Icon(
                          obscure ? AppIcons.visible : AppIcons.hidden,
                        ),
                      ),
                    ),
              );
            }

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                24,
                16,
                24,
                MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: .2,
                            ),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      Container(
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          AppIcons.password,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Change admin password',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Confirm your identity with the current admin password, then choose a new password for this account.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 24),
                      passwordField(
                        controller: currentPasswordController,
                        label: 'Current admin password',
                        hint: 'Required to confirm this change',
                        obscure: obscureCurrent,
                        toggleVisibility: () => setSheetState(
                          () => obscureCurrent = !obscureCurrent,
                        ),
                      ),
                      const SizedBox(height: 14),
                      passwordField(
                        controller: newPasswordController,
                        label: 'New password',
                        hint: 'At least 8 characters',
                        obscure: obscureNew,
                        toggleVisibility: () =>
                            setSheetState(() => obscureNew = !obscureNew),
                      ),
                      const SizedBox(height: 14),
                      passwordField(
                        controller: confirmPasswordController,
                        label: 'Confirm new password',
                        hint: 'Enter the new password again',
                        obscure: obscureConfirmation,
                        textInputAction: TextInputAction.done,
                        toggleVisibility: () => setSheetState(
                          () => obscureConfirmation = !obscureConfirmation,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: .45),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(AppIcons.shield, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Use 8 or more characters. Other signed-in devices will be logged out after the change.',
                                style: TextStyle(fontSize: 12, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (errorText != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.danger),
                          ),
                          child: Text(
                            errorText!,
                            style: const TextStyle(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final currentPassword =
                                    currentPasswordController.text;
                                final newPassword = newPasswordController.text;
                                final confirmation =
                                    confirmPasswordController.text;
                                if (currentPassword.isEmpty) {
                                  setSheetState(() {
                                    errorText =
                                        'Enter your current admin password.';
                                  });
                                  return;
                                }
                                if (newPassword.length < 8) {
                                  setSheetState(() {
                                    errorText = 'The new password must be at least 8 characters.';
                                  });
                                  return;
                                }
                                if (newPassword != confirmation) {
                                  setSheetState(() {
                                    errorText =
                                        'The new passwords do not match.';
                                  });
                                  return;
                                }
                                if (newPassword == currentPassword) {
                                  setSheetState(() {
                                    errorText = 'Choose a new password different from the current password.';
                                  });
                                  return;
                                }

                                setSheetState(() {
                                  isSubmitting = true;
                                  errorText = null;
                                });
                                try {
                                  await ApiService.changeCurrentAdminPassword(
                                    currentPassword: currentPassword,
                                    newPassword: newPassword,
                                  );
                                  if (!sheetContext.mounted) return;
                                  Navigator.of(sheetContext).pop();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Password updated.'),
                                      ),
                                    );
                                  }
                                } catch (error) {
                                  if (!sheetContext.mounted) return;
                                  setSheetState(() {
                                    isSubmitting = false;
                                    final message = error
                                        .toString()
                                        .replaceFirst('Exception: ', '');
                                    errorText = message.contains('P0001')
                                        ? 'The current admin password is incorrect.'
                                        : message;
                                  });
                                }
                              },
                        icon: isSubmitting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(AppIcons.resetPassword),
                        label: Text(
                          isSubmitting
                              ? 'Updating password…'
                              : 'Update password',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
  }

  void _showAddStaffSheet() {
    final pinController = TextEditingController();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedRole = 'waiter';
    bool isSubmitting = false;
    bool submissionSucceeded = false;
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface
          .withValues(alpha: .94),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 24,
                right: 24,
                top: 32,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'PROVISION NEW STAFF',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: nameController,
                      style: Theme.of(context).textTheme.bodyLarge,
                      decoration: _buildInputDecoration(
                        'FULL NAME',
                        AppIcons.user,
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(8),
                      ],
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                      decoration: _buildInputDecoration(
                        'PHONE NUMBER',
                        AppIcons.phone,
                        isPhone: true,
                      ),
                    ),

                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: passwordController,
                            style: Theme.of(context).textTheme.bodyLarge,
                            decoration: _buildInputDecoration(
                              'PASSWORD',
                              AppIcons.lock,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: pinController,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                            decoration: _buildInputDecoration(
                              'ID',
                              AppIcons.staffBadge,
                            ).copyWith(counterText: ""),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      dropdownColor: Theme.of(context).colorScheme.surface,
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                      decoration: _buildInputDecoration(
                        'SYSTEM ROLE',
                        AppIcons.work,
                      ),
                      items: _getAvailableRoles(),
                      onChanged: (val) =>
                          setSheetState(() => selectedRole = val!),
                    ),
                    const SizedBox(height: 24),

                    if (errorText != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.redAccent),
                        ),
                        child: Text(
                          errorText!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                    ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              if (nameController.text.isEmpty ||
                                  phoneController.text.length != 8 ||
                                  passwordController.text.isEmpty) {
                                setSheetState(
                                  () => errorText = 'Please fill out all fields and ensure phone is 8 digits.',
                                );
                                return;
                              }
                              if (pinController.text.length < 4) {
                                setSheetState(
                                  () => errorText =
                                      'Staff ID must be exactly 4 digits.',
                                );
                                return;
                              }

                              setSheetState(() {
                                isSubmitting = true;
                                errorText = null;
                              });
                              try {
                                await ApiService.createStaffMember(
                                  pin: pinController.text.trim(),
                                  name: nameController.text.trim(),
                                  phone: '+2519${phoneController.text.trim()}',
                                  password: passwordController.text.trim(),
                                  role: selectedRole,
                                );
                                submissionSucceeded = true;
                                if (context.mounted) Navigator.pop(context);
                              } catch (e) {
                                if (context.mounted) {
                                  setSheetState(
                                    () => errorText = e.toString().replaceAll(
                                      'Exception: ',
                                      '',
                                    ),
                                  );
                                }
                              } finally {
                                if (!submissionSucceeded && context.mounted) {
                                  setSheetState(() => isSubmitting = false);
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'SAVE USER',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditStaffSheet(Map<String, dynamic> staffMember) {
    final dbPhone = staffMember['phone_number']?.toString() ?? '';
    final displayPhone = dbPhone.startsWith('+2519')
        ? dbPhone.replaceFirst('+2519', '')
        : dbPhone;

    final nameController = TextEditingController(
      text: staffMember['name']?.toString() ?? '',
    );
    final phoneController = TextEditingController(text: displayPhone);
    final passwordController = TextEditingController();

    String selectedRole = staffMember['role'];
    if (selectedRole == 'cashier' &&
        ApiService.currentBusinessHasCashier != true) {
      selectedRole = 'waiter';
    }
    bool isSubmitting = false;
    bool submissionSucceeded = false;
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface
          .withValues(alpha: .94),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 24,
                right: 24,
                top: 32,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'MANAGE STAFF: ${staffMember['staff_number']}',
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: nameController,
                      style: Theme.of(context).textTheme.bodyLarge,
                      decoration: _buildInputDecoration(
                        'FULL NAME',
                        AppIcons.user,
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(8),
                      ],
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                      decoration: _buildInputDecoration(
                        'PHONE NUMBER',
                        AppIcons.phone,
                        isPhone: true,
                      ),
                    ),

                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      style: Theme.of(context).textTheme.bodyLarge,
                      obscureText: true,
                      decoration: _buildInputDecoration(
                        'NEW PASSWORD (OPTIONAL)',
                        AppIcons.lock,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      dropdownColor: Theme.of(context).colorScheme.surface,
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                      decoration: _buildInputDecoration(
                        'SYSTEM ROLE',
                        AppIcons.work,
                      ),
                      items: _getAvailableRoles(),
                      onChanged: (val) =>
                          setSheetState(() => selectedRole = val!),
                    ),
                    const SizedBox(height: 24),

                    if (errorText != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.redAccent),
                        ),
                        child: Text(
                          errorText!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                    ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              if (nameController.text.isEmpty ||
                                  phoneController.text.length != 8) {
                                setSheetState(
                                  () => errorText = 'Name is required and phone must be 8 digits.',
                                );
                                return;
                              }
                              if (passwordController.text.isNotEmpty &&
                                  passwordController.text.length < 8) {
                                setSheetState(
                                  () => errorText = 'A new password must be at least 8 characters.',
                                );
                                return;
                              }
                              setSheetState(() {
                                isSubmitting = true;
                                errorText = null;
                              });
                              try {
                                await ApiService.updateStaffProfile(
                                  staffMember['staff_number'].toString(),
                                  nameController.text.trim(),
                                  '+2519${phoneController.text.trim()}',
                                  passwordController.text.trim(),
                                  selectedRole,
                                );
                                submissionSucceeded = true;
                                if (context.mounted) Navigator.pop(context);
                              } catch (e) {
                                if (context.mounted) {
                                  setSheetState(
                                    () => errorText = e.toString().replaceAll(
                                      'Exception: ',
                                      '',
                                    ),
                                  );
                                }
                              } finally {
                                if (!submissionSucceeded && context.mounted) {
                                  setSheetState(() => isSubmitting = false);
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'UPDATE STAFF',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _buildInputDecoration(
    String label,
    IconData icon, {
    bool isPhone = false,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: isPhone
          ? Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Text(
                    '+2519',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 2,
                    height: 24,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            )
          : Icon(icon),
    );
  }

  Future<void> _updateStaffStatus(
    Map<String, dynamic> staff,
    bool isActive,
  ) async {
    final staffNumber = staff['staff_number']?.toString() ?? '';
    if (staffNumber.isEmpty || _staffStatusUpdates.contains(staffNumber)) {
      return;
    }

    setState(() => _staffStatusUpdates.add(staffNumber));
    try {
      await ApiService.toggleStaffStatus(staffNumber, isActive);
      if (!mounted) return;
      setState(() {
        _staffRoster = _staffRoster
            .map(
              (member) => member['staff_number']?.toString() == staffNumber
                  ? <String, dynamic>{...member, 'is_active': isActive}
                  : member,
            )
            .toList(growable: false);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isActive
                ? '${staff['name']} can sign in again.'
                : '${staff['name']} has been paused.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not update ${staff['name']}: ${error.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _staffStatusUpdates.remove(staffNumber));
      }
    }
  }

  // Uses the route's single roster subscription so returning to this tab never
  // replaces useful content with a new full-screen loading state.
  Widget _buildStaffRosterTab() {
    if (!_staffRosterLoaded) {
      return const LoadingView(message: 'Loading team');
    }

    final staffList = _staffRoster
        .where((staff) => staff['role'] != 'admin')
        .toList(growable: false);

    return ListView(
      key: const PageStorageKey<String>('admin-team-list'),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Team',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${staffList.length} floor ${staffList.length == 1 ? 'member' : 'members'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: _showAddStaffSheet,
              icon: const Icon(AppIcons.addUser, size: 18),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (_staffRosterError != null)
          ErrorBanner(message: _friendlyStreamError(_staffRosterError)),
        if (staffList.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 72),
            child: EmptyView(
              message: 'No payment staff yet. Add the first team member.',
              icon: AppIcons.team,
            ),
          )
        else
          for (final staff in staffList) _buildStaffMemberCard(staff),
      ],
    );
  }

  Widget _buildStaffMemberCard(Map<String, dynamic> staff) {
    final staffNumber = staff['staff_number']?.toString() ?? '';
    final isActive = staff['is_active'] as bool? ?? true;
    final isUpdating = _staffStatusUpdates.contains(staffNumber);
    final roleName = PaymentContext.roleLabel(staff['role']).toUpperCase();
    final roleDisplay = roleName.isEmpty
        ? roleName
        : '${roleName[0]}${roleName.substring(1).toLowerCase()}';
    final roleColor = roleName == 'CASHIER'
        ? const Color(0xFFF59E0B)
        : const Color(0xFF10B981);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppVariant.usesIPhoneUi
            ? Theme.of(context).colorScheme.surfaceContainerHigh
            : Theme.of(context).colorScheme.surface.withValues(alpha: .82),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            AppVariant.usesIPhoneUi ? 20 : 16,
          ),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant
                .withValues(alpha: AppVariant.usesIPhoneUi ? .42 : 1),
            width: AppVariant.usesIPhoneUi ? .6 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isUpdating ? null : () => _showEditStaffSheet(staff),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: roleColor.withValues(alpha: .12),
                  child: Icon(
                    roleName == 'CASHIER'
                        ? AppIcons.pointOfSale
                        : AppIcons.staffBadge,
                    color: roleColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        staff['name']?.toString() ?? 'Unknown',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$staffNumber  •  $roleDisplay  •  ${isActive ? 'Active' : 'Paused'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isActive
                              ? roleColor
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isUpdating)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 15),
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  Switch.adaptive(
                    value: isActive,
                    activeTrackColor: AppColors.success,
                    onChanged: (value) => _updateStaffStatus(staff, value),
                  ),
                const Icon(AppIcons.chevronRight, size: 17),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showReceiptEvidence(String ticketId) async {
    try {
      final data = await ApiService.fetchReceiptImage(ticketId);
      if (!mounted) return;
      final encoded = data?['image_base64']?.toString();
      if (encoded == null || encoded.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No receipt image is attached.')),
        );
        return;
      }
      final bytes = base64Decode(encoded);
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 820),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(AppIcons.secureUser),
                  title: const Text('Receipt evidence'),
                  subtitle: Text(
                    '${data?['byte_size'] ?? bytes.length} bytes • SHA-256 protected',
                  ),
                  trailing: IconButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(AppIcons.close),
                  ),
                ),
                Flexible(
                  child: InteractiveViewer(
                    minScale: .7,
                    maxScale: 4,
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not load receipt: $error')));
    }
  }

  Future<void> _resolveWithdrawal(
    Map<String, dynamic> request,
    String status,
  ) async {
    final requestId = request['request_id']?.toString() ?? '';
    if (requestId.isEmpty || _withdrawalUpdates.contains(requestId)) return;

    setState(() => _withdrawalUpdates.add(requestId));
    try {
      await ApiService.resolveTipWithdrawal(requestId, status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Withdrawal marked ${status.toLowerCase()}.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not update withdrawal: ${error.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _withdrawalUpdates.remove(requestId));
      }
    }
  }

  void _showWithdrawalRequests() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: .86,
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _withdrawalRequestsStream,
          builder: (context, snapshot) {
            final requests = snapshot.data ?? const <Map<String, dynamic>>[];
            return Column(
              children: [
                ListTile(
                  leading: const Icon(AppIcons.money),
                  title: const Text('Tip withdrawal requests'),
                  subtitle: Text('${requests.length} recent requests'),
                  trailing: IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(AppIcons.close),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: requests.isEmpty
                      ? const EmptyView(
                          message: 'No withdrawal requests.',
                          icon: AppIcons.inbox,
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: requests.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final request = requests[index];
                            final pending = request['status'] == 'pending';
                            final approved = request['status'] == 'approved';
                            final requestId = request['request_id']?.toString();
                            final isUpdating =
                                requestId != null &&
                                _withdrawalUpdates.contains(requestId);
                            final amount =
                                (request['amount'] as num?)?.toDouble() ?? 0;
                            return GlassPanel(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  const CircleAvatar(
                                    child: Icon(AppIcons.user),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Staff ${request['staff_number']}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${amount.toStringAsFixed(2)} ETB • ${request['status'].toString().toUpperCase()}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isUpdating)
                                    const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox.square(
                                        dimension: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  else if (pending) ...[
                                    IconButton.filledTonal(
                                      tooltip: 'Reject',
                                      onPressed: () => _resolveWithdrawal(
                                        request,
                                        'rejected',
                                      ),
                                      icon: const Icon(AppIcons.close),
                                    ),
                                    const SizedBox(width: 6),
                                    IconButton.filled(
                                      tooltip: 'Approve',
                                      onPressed: () => _resolveWithdrawal(
                                        request,
                                        'approved',
                                      ),
                                      icon: const Icon(AppIcons.check),
                                    ),
                                  ] else if (approved) ...[
                                    FilledButton.icon(
                                      onPressed: () =>
                                          _resolveWithdrawal(request, 'paid'),
                                      icon: const Icon(AppIcons.money),
                                      label: const Text('Mark paid'),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAdminToolsTab() {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _businessStream,
      builder: (context, businessSnapshot) {
        final rawAccounts = businessSnapshot.data?['bank_accounts'];
        final accounts = rawAccounts is Map
            ? Map<String, dynamic>.from(rawAccounts)
            : <String, dynamic>{};
        final configuredAccounts = _enabledPaymentAccountProviders.where((
          provider,
        ) {
          return accounts[provider.numberKey]?.toString().trim().isNotEmpty ==
              true;
        }).length;

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _withdrawalRequestsStream,
          builder: (context, withdrawalSnapshot) {
            final pendingWithdrawals =
                (withdrawalSnapshot.data ?? const <Map<String, dynamic>>[])
                    .where((request) => request['status'] == 'pending')
                    .length;
            return ListView(
              padding: EdgeInsets.all(
                AppVariant.usesIPhoneUi ? 16 : AppSpacing.xl,
              ),
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        AppIcons.settings,
                        color: AppColors.primary,
                        size: 27,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        AppVariant.usesIPhoneUi
                            ? context.tr('Manage')
                            : 'Admin tools',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 720 ? 2 : 1;
                    final width = columns == 1
                        ? constraints.maxWidth
                        : (constraints.maxWidth - AppSpacing.md) / 2;
                    return Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      children: [
                        _adminToolCard(
                          width: width,
                          icon: AppIcons.addUser,
                          color: AppColors.primary,
                          title: 'Add staff',
                          detail: 'Create account',
                          onTap: _showAddStaffSheet,
                          index: 0,
                        ),
                        _adminToolCard(
                          width: width,
                          icon: AppIcons.banking,
                          color: configuredAccounts == 0
                              ? AppColors.danger
                              : AppColors.success,
                          title: 'Payment accounts',
                          detail:
                              '$configuredAccounts / ${_enabledPaymentAccountProviders.length} set',
                          onTap: () => _showBankConfigSheet(accounts),
                          index: 1,
                        ),
                        _adminToolCard(
                          width: width,
                          icon: AppIcons.notifications,
                          color: pendingWithdrawals > 0
                              ? AppColors.warning
                              : AppColors.success,
                          title: 'Tip requests',
                          detail: pendingWithdrawals > 0
                              ? '$pendingWithdrawals pending'
                              : 'All clear',
                          onTap: _showWithdrawalRequests,
                          index: 2,
                        ),
                        _adminToolCard(
                          width: width,
                          icon: AppIcons.password,
                          color: AppColors.violet,
                          title: 'Password',
                          detail: 'Change password',
                          onTap: _showChangePasswordSheet,
                          index: 3,
                        ),
                        _adminToolCard(
                          width: width,
                          icon: AppIcons.support,
                          color: AppColors.aqua,
                          title: 'Support & privacy',
                          detail: 'Help and account',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SupportPrivacyScreen(
                                allowAccountDeletion: true,
                              ),
                            ),
                          ),
                          index: 4,
                        ),
                        _adminToolCard(
                          width: width,
                          icon: AppIcons.refresh,
                          color: AppColors.success,
                          title: 'Refresh',
                          detail: 'Reload transactions',
                          onTap: _refreshData,
                          index: 5,
                        ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _adminToolCard({
    required double width,
    required IconData icon,
    required Color color,
    required String title,
    required String detail,
    required VoidCallback onTap,
    int index = 0,
  }) {
    return FadeSlideIn(
      index: index.clamp(0, 5),
      child: SizedBox(
        width: width,
        child: Semantics(
          button: true,
          label: title,
          child: HoverSurface(
            onTap: onTap,
            accent: color,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .13),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, color: color, size: 27),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        detail,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(AppIcons.chevronRight, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    await ApiService.logoutStaff();
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      CupertinoPageRoute<void>(builder: (_) => const StaffLoginScreen()),
    );
  }

  void _openHelpAndPrivacy() {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(builder: (_) => const SupportPrivacyScreen()),
    );
  }

  Widget _buildIPhoneBusinessTitle() {
    return Text(context.tr('Admin'));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppVariant.usesIPhoneUi
            ? IPhoneDashboardNavigationBar(
                title: _buildIPhoneBusinessTitle(),
                onSignOut: _signOut,
                onHelp: _openHelpAndPrivacy,
                onRefresh: _refreshData,
              )
            : AppBar(
                title: StreamBuilder<Map<String, dynamic>>(
                  stream: _businessStream,
                  builder: (context, snapshot) {
                    final business = snapshot.data;
                    final name = business?['name']?.toString() ?? 'Business';
                    final type =
                        business?['business_type']?.toString() ??
                        business?['subscription_tier']?.toString() ??
                        'Business';
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!AppVariant.usesMinimalCopy)
                          Text(
                            type,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                      ],
                    );
                  },
                ),
                titleTextStyle: AppTypography.appBarTitle(),
                leading: IconButton(
                  tooltip: 'Sign out',
                  icon: const Icon(AppIcons.logout, color: AppColors.danger),
                  onPressed: _signOut,
                ),
                actions: [
                  const GlassLanguageToggleButton(),
                  const GlassThemeToggleButton(),
                ],
                bottom: TabBar(
                  dividerHeight: 0,
                  tabs: [
                    Tab(
                      icon: const Icon(AppIcons.analytics, size: 18),
                      text: context.tr('Overview'),
                    ),
                    Tab(
                      icon: const Icon(AppIcons.team, size: 18),
                      text: context.tr('Team'),
                    ),
                    const Tab(
                      icon: Icon(AppIcons.settings, size: 18),
                      text: 'Manage',
                    ),
                  ],
                ),
              ),
        body: AppBackdrop(
          child: DashboardTabView(
            preserveState: AppVariant.usesIPhoneUi,
            physics: AppVariant.usesIPhoneUi
                ? const NeverScrollableScrollPhysics()
                : null,
            children: [
              // TAB 1: FINANCIALS AND LEDGER
              CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _ticketsStream,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: ErrorBanner(
                              message: _friendlyStreamError(snapshot.error),
                            ),
                          );
                        }
                        if (!_activePlan.includes(
                          PlanFeature.dailyRevenueReport,
                        )) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: _buildProInsightsLock(),
                          );
                        }
                        final allTickets =
                            snapshot.data ?? const <Map<String, dynamic>>[];
                        final visibleTickets = _filteredTickets(allTickets);
                        double totalRevenue = 0;
                        int pendingCount = 0;
                        Map<String, double> bankTotals = {};
                        Map<String, int> bankCounts = {};

                        if (snapshot.hasData) {
                          for (var ticket in visibleTickets) {
                            if (ticket['status'] == 'settled') {
                              double amount = (ticket['bill_amount'] ?? 0)
                                  .toDouble();
                              totalRevenue += amount;
                              String bankName = ticket['bank'] ?? 'Unknown';
                              bankTotals[bankName] =
                                  (bankTotals[bankName] ?? 0) + amount;
                              bankCounts[bankName] =
                                  (bankCounts[bankName] ?? 0) + 1;
                            } else if (ticket['status'] == 'pending') {
                              pendingCount++;
                            }
                          }
                        }

                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLedgerFilters(allTickets),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildMetricCard(
                                      context.tr('TOTAL REVENUE'),
                                      '${totalRevenue.toStringAsFixed(0)} ETB',
                                      const Color(0xFF10B981),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildMetricCard(
                                      context.tr('OPEN PAYMENTS'),
                                      '$pendingCount',
                                      const Color(0xFFF59E0B),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Text(
                                AppVariant.usesIPhoneUi
                                    ? _modernSectionLabel('PAYMENT METHODS')
                                    : context.tr('BANK DEPOSIT BREAKDOWN'),
                                style: AppVariant.usesIPhoneUi
                                    ? Theme.of(context).textTheme.titleMedium
                                          ?.copyWith(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: -.25,
                                          )
                                    : const TextStyle(
                                        color: AppColors.textFaint,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                        letterSpacing: 1.5,
                                      ),
                              ),
                              const SizedBox(height: 16),
                              if (bankTotals.isEmpty)
                                GlassPanel(
                                  padding: const EdgeInsets.all(24),
                                  child: Center(
                                    child: Text(
                                      context.tr(
                                        'No verified transactions yet.',
                                      ),
                                      style: const TextStyle(
                                        color: AppColors.textFaint,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                GlassPanel(
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        children: bankTotals.entries.map((
                                          entry,
                                        ) {
                                          Color bColor = _getBankColor(
                                            entry.key,
                                          );
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 16.0,
                                            ),
                                            child: Row(
                                              children: [
                                                PaymentLogo(
                                                  provider: entry.key,
                                                  size: 34,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        entry.key,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodyMedium
                                                            ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 14,
                                                            ),
                                                      ),
                                                      Text(
                                                        '${bankCounts[entry.key] ?? 0} payments • ${totalRevenue == 0 ? '0' : (entry.value / totalRevenue * 100).toStringAsFixed(1)}%',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodySmall,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Text(
                                                  '${entry.value.toStringAsFixed(0)} ETB',
                                                  style: TextStyle(
                                                    color: bColor,
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    )
                                    .animate()
                                    .fadeIn(delay: 300.ms)
                                    .slideY(begin: 0.1, end: 0),
                            ],
                          ),
                        ).animate().fadeIn(duration: 400.ms);
                      },
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Text(
                        AppVariant.usesIPhoneUi
                            ? _modernSectionLabel('TRANSACTIONS')
                            : context.tr('MASTER TRANSACTION LEDGER'),
                        style: AppVariant.usesIPhoneUi
                            ? Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -.25,
                              )
                            : const TextStyle(
                                color: AppColors.textFaint,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                                letterSpacing: 1.5,
                              ),
                      ),
                    ),
                  ),

                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _ticketsStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: ErrorBanner(
                              message: _friendlyStreamError(snapshot.error),
                            ),
                          ),
                        );
                      }
                      final visibleTickets = _filteredTickets(
                        snapshot.data ?? const <Map<String, dynamic>>[],
                      );
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        );
                      }
                      if (visibleTickets.isEmpty) {
                        return SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Text(
                                context.tr('Ledger is clear.'),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ),
                        );
                      }

                      return SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final ticket = visibleTickets[index];
                          final isSettled = ticket['status'] == 'settled';
                          final isRejected = ticket['status'] == 'rejected';
                          final bankColor = _getBankColor(ticket['bank'] ?? '');
                          final statusColor = isSettled
                              ? const Color(0xFF10B981)
                              : (isRejected
                                    ? Colors.redAccent
                                    : const Color(0xFFF59E0B));

                          return GlassPanel(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            padding: const EdgeInsets.all(16),
                            borderRadius: AppVariant.usesIPhoneUi ? 20 : 16,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            AppIcons.receipt,
                                            color: statusColor,
                                            size: AppVariant.usesIPhoneUi
                                                ? 18
                                                : 16,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${ticket['bill_amount']} ETB',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize:
                                                      AppVariant.usesIPhoneUi
                                                      ? 18
                                                      : 16,
                                                ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          PaymentBrand(
                                            provider:
                                                ticket['bank']?.toString() ??
                                                'N/A',
                                            logoSize: 22,
                                            style: TextStyle(
                                              color: bankColor,
                                              fontSize: AppVariant.usesIPhoneUi
                                                  ? 12
                                                  : 10,
                                              fontWeight:
                                                  AppVariant.usesIPhoneUi
                                                  ? FontWeight.w700
                                                  : FontWeight.w900,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'REF: ${ticket['transaction_ref'] ?? ticket['ticket_id'].toString().substring(0, 8)}',
                                            style: TextStyle(
                                              color: AppVariant.usesIPhoneUi
                                                  ? Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant
                                                  : AppColors.textFaint,
                                              fontSize: AppVariant.usesIPhoneUi
                                                  ? 12
                                                  : 10,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Staff ${ticket['waiter_id']} • ${PaymentContext.display(ticket['table_number'])} • ${_formatLedgerDate(ticket['created_at'])}',
                                        style: TextStyle(
                                          color: AppVariant.usesIPhoneUi
                                              ? Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant
                                                    .withValues(alpha: .72)
                                              : AppColors.textDisabled,
                                          fontSize: AppVariant.usesIPhoneUi
                                              ? 11
                                              : 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (ticket['receipt_image_saved'] == true)
                                  IconButton(
                                    tooltip: 'View receipt evidence',
                                    onPressed: () => _showReceiptEvidence(
                                      ticket['ticket_id'].toString(),
                                    ),
                                    icon: const Icon(
                                      AppIcons.scanImage,
                                      color: AppColors.primary,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }, childCount: visibleTickets.length),
                      );
                    },
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),

              // TAB 2: STAFF ROSTER
              _buildStaffRosterTab(),
              // TAB 3: LARGE ADMIN ACTIONS
              _buildAdminToolsTab(),
            ],
          ),
        ),
        bottomNavigationBar: AppVariant.usesIPhoneUi
            ? IPhoneBottomTabBar(
                items: [
                  IPhoneTabItem(
                    label: context.tr('Overview'),
                    icon: AppIcons.analytics,
                  ),
                  IPhoneTabItem(label: context.tr('Team'), icon: AppIcons.team),
                  IPhoneTabItem(
                    label: context.tr('Manage'),
                    icon: AppIcons.settings,
                  ),
                ],
              )
            : null,
      ),
    );
  }

  Widget _buildMetricCard(String title, String val, Color accents) {
    return MetricCard(title: title, value: val, accent: accents);
  }

  String _friendlyStreamError(Object? error) {
    final message =
        error?.toString().replaceFirst('Exception: ', '') ??
        'Unable to load dashboard data.';
    return 'Dashboard data could not be loaded. $message';
  }

  String _modernSectionLabel(String value) {
    final translated = context.tr(value);
    if (translated.isEmpty || translated != translated.toUpperCase()) {
      return translated;
    }
    final lower = translated.toLowerCase();
    return '${lower[0].toUpperCase()}${lower.substring(1)}';
  }
}
