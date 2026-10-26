import 'package:flutter/material.dart';
import 'package:verify_me/core/theme/app_icons.dart';
import 'package:flutter/services.dart';

import 'api_service.dart';
import 'staff_login_screen.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_motion.dart';
import 'core/theme/app_shapes.dart';
import 'core/theme/app_spacing.dart';
import 'core/theme/app_typography.dart';
import 'core/widgets/app_bottom_sheet.dart';
import 'core/widgets/skeleton.dart';
import 'core/widgets/status_dot.dart';
import 'core/widgets/state_views.dart';
import 'core/widgets/success_overlay.dart';
import 'core/widgets/segmented_tabs.dart';
import 'core/widgets/app_shell.dart';
import 'core/widgets/dashboard_refresh_status.dart';
import 'localization_service.dart';
import 'support_privacy_screen.dart';
import 'core/config/app_variant.dart';
import 'core/config/payment_context.dart';
import 'core/models/workspace_profile.dart';
import 'iphone/iphone_dashboard_shell.dart';

class CashierDashboard extends StatefulWidget {
  const CashierDashboard({
    super.key,
    this.workspaceProfile,
    this.readOnly = false,
  });
  final WorkspaceProfile? workspaceProfile;
  final bool readOnly;

  @override
  State<CashierDashboard> createState() => _CashierDashboardState();
}

class _CashierDashboardState extends State<CashierDashboard> {
  late Stream<List<Map<String, dynamic>>> _ticketsStream;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _ticketsStream = ApiService.streamTodayTickets();
    if (widget.readOnly) _tabIndex = 1;
  }

  void _refreshData() {
    ApiService.refreshDashboardData();
  }

  Future<void> _handleLogout() async {
    await ApiService.logoutStaff();
    if (!mounted) return;
    goReplace(context, const StaffLoginScreen());
  }

  void _openHelpAndPrivacy() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SupportPrivacyScreen()),
    );
  }

  Future<void> _showTipAllocation(Map<String, dynamic> payment) async {
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    final available =
        ((payment['unresolved_excess'] as num?)?.toDouble() ?? 0) -
        ((payment['allocated_tip_amount'] as num?)?.toDouble() ?? 0);
    var saving = false;
    String? errorText;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Allocate a tip'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Available excess: ${available.toStringAsFixed(2)} ETB'),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Tip amount (ETB)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: reasonController,
                maxLength: 500,
                decoration: const InputDecoration(labelText: 'Reason'),
              ),
              if (errorText != null)
                Text(
                  errorText!,
                  style: TextStyle(
                    color: Theme.of(dialogContext).colorScheme.error,
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final amount = double.tryParse(
                        amountController.text.trim(),
                      );
                      if (amount == null ||
                          !amount.isFinite ||
                          amount <= 0 ||
                          amount > available ||
                          reasonController.text.trim().length < 3) {
                        setDialogState(
                          () => errorText =
                              'Enter a valid amount and a short reason.',
                        );
                        return;
                      }
                      setDialogState(() {
                        saving = true;
                        errorText = null;
                      });
                      try {
                        await ApiService.allocatePaymentTip(
                          ticketId: payment['ticket_id'].toString(),
                          recipientStaffNumber: payment['waiter_id'].toString(),
                          amount: amount,
                          reason: reasonController.text.trim(),
                        );
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                      } catch (error) {
                        if (dialogContext.mounted) {
                          setDialogState(() {
                            saving = false;
                            errorText = error.toString().replaceFirst(
                              'Exception: ',
                              '',
                            );
                          });
                        }
                      }
                    },
              child: saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Allocate tip'),
            ),
          ],
        ),
      ),
    );
    amountController.dispose();
    reasonController.dispose();
  }

  // ── Settlement sheet ─────────────────────────────────────────────────────
  void _showSettlementSheet(Map<String, dynamic> ticket) {
    late final TextEditingController actualController;
    final ticketId = (ticket['ticket_id'] ?? '').toString();
    final ref = (ticket['transaction_ref'] ?? '—').toString();
    final waiterId = (ticket['waiter_id'] ?? '—').toString();
    final expectedAmount =
        (ticket['expected_amount'] as num?)?.toDouble() ??
        (ticket['bill_amount'] as num?)?.toDouble() ??
        0.0;
    final verifiedAmount =
        (ticket['verified_amount'] as num?)?.toDouble() ?? expectedAmount;
    actualController = TextEditingController(
      text: verifiedAmount.toStringAsFixed(2),
    );
    bool isSubmitting = false;
    String? errorText;

    showAppSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final input = actualController.text.trim();
            final actual = double.tryParse(input);
            final hasInput = input.isNotEmpty && actual != null;
            final isShortfall = hasInput && actual < expectedAmount;
            final tip =
                ((ticket['tip_amount'] as num?)?.toDouble() ?? 0) +
                ((ticket['allocated_tip_amount'] as num?)?.toDouble() ?? 0);
            final unresolved =
                ((ticket['unresolved_excess'] as num?)?.toDouble() ?? 0) -
                ((ticket['allocated_tip_amount'] as num?)?.toDouble() ?? 0);

            return AppSheetBody(
              children: [
                AppSheetHeader(
                  title: 'COMPLETE PAYMENT',
                  color: AppColors.primary,
                ),
                const SizedBox(height: 24),
                // Ticket summary card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: ShapeDecoration(
                    color: Theme.of(context).colorScheme.surface
                        .withValues(alpha: .62),
                    shape: AppShapes.cardSm,
                  ),
                  child: Column(
                    children: [
                      _summaryRow('REF', ref),
                      const Divider(color: AppColors.hairline, height: 24),
                      _summaryRow(
                        'FOR',
                        PaymentContext.display(ticket['table_number']),
                      ),
                      const Divider(color: AppColors.hairline, height: 24),
                      _summaryRow('STAFF', 'ID: $waiterId'),
                      const Divider(color: AppColors.hairline, height: 24),
                      _summaryRow(
                        AppVariant.usesMinimalCopy ? 'DUE' : 'AMOUNT DUE',
                        '${expectedAmount.toStringAsFixed(2)} ETB',
                        valueColor: AppColors.success,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Actual amount entry
                TextField(
                  controller: actualController,
                  readOnly: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+\.?\d{0,2}'),
                    ),
                  ],
                  textAlign: TextAlign.center,
                  style: AppTypography.money(
                    size: 28,
                    color: isShortfall
                        ? AppColors.danger
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                  onChanged: (_) => setSheetState(() {}),
                  decoration: InputDecoration(
                    labelText: AppVariant.usesMinimalCopy
                        ? 'AMOUNT (ETB)'
                        : 'PROVIDER VERIFIED AMOUNT (ETB)',
                    prefixIcon: Icon(
                      AppIcons.wallet,
                      color: isShortfall ? AppColors.danger : AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (tip > 0)
                  // The tip reveal grows in place, so the number reads as the
                  // result of the amount above it.
                  AnimatedSize(
                    duration: AppMotion.slow,
                    curve: AppMotion.easeOutCustom,
                    alignment: Alignment.topCenter,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: ShapeDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        shape: AppShapes.cardSm,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppVariant.usesMinimalCopy
                                ? 'TIP ALLOCATED'
                                : 'ALLOCATED TIP',
                            style: AppTypography.microLabel(
                              color: AppColors.success,
                            ),
                          ),
                          Text(
                            '${tip.toStringAsFixed(2)} ETB',
                            style: AppTypography.money(
                              size: 16,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (unresolved > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      '${unresolved.toStringAsFixed(2)} ETB excess remains unresolved.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                if (isShortfall)
                  AnimatedSize(
                    duration: AppMotion.slow,
                    curve: AppMotion.easeOutCustom,
                    alignment: Alignment.topCenter,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: ShapeDecoration(
                        color: AppColors.danger.withValues(alpha: 0.1),
                        shape: AppShapes.cardSm,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            AppIcons.warning,
                            color: AppColors.danger,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              AppVariant.usesMinimalCopy ? 'AMOUNT BELOW DUE' : 'SHORTFALL. Amount is less than the amount due. Settlement blocked.',
                              style: AppTypography.microLabel(
                                color: AppColors.danger,
                              ).copyWith(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                if (errorText != null) ...[ErrorBanner(message: errorText!)],
                if (isShortfall)
                  ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            setSheetState(() {
                              isSubmitting = true;
                              errorText = null;
                            });
                            try {
                              await ApiService.rejectTicket(
                                ticketId: ticketId,
                                reason: 'Reviewer did not complete payment',
                              );
                              if (!context.mounted || !mounted) return;
                              final messenger = ScaffoldMessenger.of(
                                this.context,
                              );
                              Navigator.pop(context);
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Payment rejected.'),
                                  backgroundColor: AppColors.danger,
                                ),
                              );
                            } catch (e) {
                              if (context.mounted) {
                                setSheetState(
                                  () => errorText = 'Network Error: $e',
                                );
                              }
                            } finally {
                              if (context.mounted) {
                                setSheetState(() => isSubmitting = false);
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                    ),
                    child: isSubmitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            AppVariant.usesMinimalCopy
                                ? 'REJECT'
                                : 'REJECT PAYMENT',
                          ),
                  )
                else
                  ElevatedButton(
                    onPressed: (!hasInput || isSubmitting)
                        ? null
                        : () async {
                            setSheetState(() {
                              isSubmitting = true;
                              errorText = null;
                            });
                            try {
                              await ApiService.settleTicket(
                                ticketId: ticketId,
                                reason: 'Payment marked complete by reviewer',
                              );
                              if (!context.mounted || !mounted) return;
                              final dashboardContext = this.context;
                              Navigator.pop(context);
                              await SuccessOverlay.show(
                                dashboardContext,
                                message: 'PAYMENT MARKED COMPLETE',
                              );
                            } catch (e) {
                              if (context.mounted) {
                                setSheetState(
                                  () => errorText = 'Network Error: $e',
                                );
                              }
                            } finally {
                              if (context.mounted) {
                                setSheetState(() => isSubmitting = false);
                              }
                            }
                          },
                    child: isSubmitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text('MARK COMPLETE'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _summaryRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.microLabel()),
        Text(
          value,
          style: AppTypography.money(
            size: 14,
            weight: FontWeight.w700,
            color: valueColor ?? Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  // ── Pending queue ────────────────────────────────────────────────────────
  Widget _buildPendingQueue() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _ticketsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _skeletonList();
        }
        if (snapshot.hasError) {
          return ErrorBanner(message: context.tr('Connection error.'));
        }
        final pending = (snapshot.data ?? [])
            .where((t) => t['status'] == 'pending')
            .toList();
        if (pending.isEmpty) {
          return EmptyView(
            message: context.tr('Queue is clear.'),
            icon: AppIcons.success,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.page),
          itemCount: pending.length,
          itemBuilder: (context, index) {
            final t = pending[index];
            final bank = (t['bank'] ?? '').toString();
            final amount = (t['bill_amount'] as num?)?.toDouble() ?? 0.0;
            return FadeSlideIn(
              index: index.clamp(0, 6),
              child: Pressable(
                onTap: () => _showSettlementSheet(t),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: ShapeDecoration(
                    color: Theme.of(context).colorScheme.surface
                        .withValues(alpha: .64),
                    shape: AppShapes.cardSm,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          AppIcons.alertNotification,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${amount.toStringAsFixed(2)} ETB',
                              style: AppTypography.money(size: 18),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              PaymentContext.display(t['table_number']),
                              style: Theme.of(context).textTheme.bodySmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                BankChip(
                                  bank: bank,
                                  color: AppColors.bank(bank),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'REF: ${t['transaction_ref']}',
                                    style: AppTypography.microLabel(),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        AppIcons.chevronRight,
                        color: AppColors.textFaint,
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
  }

  // ── Settled ledger ────────────────────────────────────────────────────────
  Widget _buildSettledLedger() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _ticketsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _skeletonList();
        }
        if (snapshot.hasError) {
          return ErrorBanner(message: context.tr('Connection error.'));
        }
        final past = (snapshot.data ?? [])
            .where((t) => t['status'] != 'pending')
            .toList();
        if (past.isEmpty) {
          return EmptyView(
            message: context.tr('No settled payments yet.'),
            icon: AppIcons.receipt,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.page),
          itemCount: past.length,
          itemBuilder: (context, index) {
            final t = past[index];
            final isSettled = t['status'] == 'settled';
            final bank = (t['bank'] ?? '').toString();
            final billAmount = (t['bill_amount'] as num?)?.toDouble() ?? 0.0;
            final actual = (t['actual_amount'] as num?)?.toDouble() ?? 0.0;
            final tip =
                ((t['tip_amount'] as num?)?.toDouble() ?? 0) +
                ((t['allocated_tip_amount'] as num?)?.toDouble() ?? 0);
            final remainingExcess =
                ((t['unresolved_excess'] as num?)?.toDouble() ?? 0) -
                ((t['allocated_tip_amount'] as num?)?.toDouble() ?? 0);
            final status = isSettled ? 'settled' : 'rejected';
            final statusColor = isSettled
                ? AppColors.success
                : AppColors.danger;
            return FadeSlideIn(
              index: index.clamp(0, 6),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: ShapeDecoration(
                  color: Theme.of(context).colorScheme.surface
                      .withValues(alpha: .64),
                  shape: AppShapes.cardSm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        StatusDot(
                          label: status,
                          color: statusColor,
                          icon: isSettled ? AppIcons.success : AppIcons.cancel,
                        ),
                        const Spacer(),
                        BankChip(bank: bank, color: AppColors.bank(bank)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isSettled ? '${billAmount.toStringAsFixed(2)} ETB' : '—',
                      style: AppTypography.money(size: 20),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'REF: ${t['transaction_ref']}  •  Staff: ${t['waiter_id']}',
                      style: AppTypography.microLabel(),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      PaymentContext.display(t['table_number']),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (isSettled && tip > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: AnimatedSize(
                          duration: AppMotion.slow,
                          curve: AppMotion.easeOutCustom,
                          alignment: Alignment.topCenter,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: ShapeDecoration(
                              color: AppColors.success.withValues(alpha: 0.1),
                              shape: const ContinuousRectangleBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(8),
                                ),
                              ),
                            ),
                            child: Text(
                              'Includes ${tip.toStringAsFixed(2)} ETB tip (total ${actual.toStringAsFixed(2)})',
                              style: AppTypography.microLabel(
                                color: AppColors.success,
                              ).copyWith(fontSize: 10),
                            ),
                          ),
                        ),
                      ),
                    if (isSettled && remainingExcess > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${remainingExcess.toStringAsFixed(2)} ETB excess unresolved',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (t['financial_state'] == 'normal' &&
                          widget.workspaceProfile?.tipsEnabled == true &&
                          widget.workspaceProfile?.can('manage_tips') == true &&
                          (t['allocated_tip_amount'] as num? ?? 0) == 0)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () => _showTipAllocation(t),
                            child: const Text('Allocate a tip'),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _skeletonList() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: List.generate(5, (_) => const TicketSkeletonRow()),
    );
  }

  // ── Scaffold ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppVariant.usesIPhoneUi
          ? IPhoneDashboardNavigationBar(
              title: Text(
                widget.workspaceProfile == null
                    ? context.tr('Cashier')
                    : widget.readOnly
                    ? 'Activity'
                    : 'Payments',
              ),
              onSignOut: _handleLogout,
              onHelp: _openHelpAndPrivacy,
              onRefresh: _refreshData,
            )
          : AppBar(
              elevation: 0,
              leading: IconButton(
                tooltip: 'Sign out',
                icon: const Icon(AppIcons.logout, color: AppColors.danger),
                onPressed: _handleLogout,
              ),
              actions: [
                const GlassLanguageToggleButton(),
                const GlassThemeToggleButton(),
                IconButton(
                  tooltip: 'Help and privacy',
                  icon: const Icon(AppIcons.support),
                  onPressed: _openHelpAndPrivacy,
                ),
                IconButton(
                  tooltip: 'Refresh payments',
                  icon: const Icon(AppIcons.refresh),
                  onPressed: _refreshData,
                ),
              ],
              title: Text(
                widget.workspaceProfile == null
                    ? context.tr('Cashier terminal')
                    : widget.readOnly
                    ? 'Activity'
                    : 'Payments',
              ),
              titleTextStyle: AppTypography.appBarTitle(),
            ),
      body: AppBackdrop(
        child: Column(
          children: [
            DashboardRefreshStatus(
              listenable: ApiService.dashboardRefreshState,
              onRefresh: _refreshData,
            ),
            if (!widget.readOnly)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.sm,
                  AppSpacing.xl,
                  AppSpacing.md,
                ),
                child: SegmentedTabs(
                  tabs: widget.workspaceProfile == null
                      ? [context.tr('PENDING'), context.tr('SETTLED')]
                      : const ['REVIEW', 'COMPLETE'],
                  index: _tabIndex,
                  onChanged: (i) => setState(() => _tabIndex = i),
                ),
              ),
            Expanded(
              // Fade-through keeps the segmented control and its pill feeling
              // connected to the body: the outgoing list leaves before the
              // next arrives.
              child: FadeThroughSwitcher(
                child: KeyedSubtree(
                  key: ValueKey(_tabIndex),
                  child: _tabIndex == 0 && !widget.readOnly
                      ? _buildPendingQueue()
                      : _buildSettledLedger(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
