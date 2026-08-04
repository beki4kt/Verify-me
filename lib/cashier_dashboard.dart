import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

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

class CashierDashboard extends StatefulWidget {
  const CashierDashboard({super.key});

  @override
  State<CashierDashboard> createState() => _CashierDashboardState();
}

class _CashierDashboardState extends State<CashierDashboard> {
  late Stream<List<Map<String, dynamic>>> _ticketsStream;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _ticketsStream = ApiService.streamTodayTickets();
    });
  }

  void _handleLogout() {
    ApiService.currentStaffNumber = null;
    goReplace(context, const StaffLoginScreen());
  }

  // ── Settlement sheet ─────────────────────────────────────────────────────
  void _showSettlementSheet(Map<String, dynamic> ticket) {
    final actualController = TextEditingController();
    final ticketId = (ticket['ticket_id'] ?? '').toString();
    final bank = (ticket['bank'] ?? 'Unknown').toString();
    final ref = (ticket['transaction_ref'] ?? '—').toString();
    final waiterId = (ticket['waiter_id'] ?? '—').toString();
    final expectedAmount = (ticket['bill_amount'] as num?)?.toDouble() ?? 0.0;
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
            final tip = (hasInput && actual > expectedAmount)
                ? actual - expectedAmount
                : 0.0;

            return AppSheetBody(
              children: [
                AppSheetHeader(
                  title: 'VERIFY PAYMENT',
                  color: AppColors.primary,
                ),
                const SizedBox(height: 24),
                // Ticket summary card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: ShapeDecoration(
                    color: AppColors.surfaceLow,
                    shape: AppShapes.cardSm,
                  ),
                  child: Column(
                    children: [
                      _summaryRow('REF', ref),
                      const Divider(color: AppColors.hairline, height: 24),
                      _summaryRow('WAITER', 'ID: $waiterId'),
                      const Divider(color: AppColors.hairline, height: 24),
                      _summaryRow('EXPECTED BILL', '${expectedAmount.toStringAsFixed(2)} ETB',
                          valueColor: AppColors.success),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Actual amount entry
                TextField(
                  controller: actualController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                  textAlign: TextAlign.center,
                  style: AppTypography.money(
                    size: 28,
                    color: isShortfall ? AppColors.danger : AppColors.textPrimary,
                  ),
                  onChanged: (_) => setSheetState(() {}),
                  decoration: InputDecoration(
                    labelText: 'ACTUAL AMOUNT IN BANK (ETB)',
                    prefixIcon: Icon(
                      Icons.account_balance_wallet,
                      color: isShortfall ? AppColors.danger : AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (hasInput && !isShortfall)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: ShapeDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      shape: AppShapes.cardSm,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('CALCULATED TIP',
                            style: AppTypography.microLabel(color: AppColors.success)),
                        Text('${tip.toStringAsFixed(2)} ETB',
                            style: AppTypography.money(size: 16, color: AppColors.success)),
                      ],
                    ),
                  ).animate().fadeIn(),
                if (isShortfall)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: ShapeDecoration(
                      color: AppColors.danger.withValues(alpha: 0.1),
                      shape: AppShapes.cardSm,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'SHORTFALL. Amount is less than the bill. Settlement blocked.',
                            style: AppTypography.microLabel(color: AppColors.danger)
                                .copyWith(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(),
                const SizedBox(height: 24),
                if (errorText != null) ...[
                  ErrorBanner(message: errorText!),
                ],
                if (isShortfall)
                  ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            setSheetState(() { isSubmitting = true; errorText = null; });
                            try {
                              await ApiService.rejectTicket(ticketId);
                              if (!mounted) return;
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Ticket rejected.'),
                                  backgroundColor: AppColors.danger,
                                ),
                              );
                            } catch (e) {
                              setSheetState(() => errorText = 'Network Error: $e');
                            } finally {
                              if (mounted) setSheetState(() => isSubmitting = false);
                            }
                          },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                    child: isSubmitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('REJECT TICKET'),
                  )
                else
                  ElevatedButton(
                    onPressed: (!hasInput || isSubmitting)
                        ? null
                        : () async {
                            setSheetState(() { isSubmitting = true; errorText = null; });
                            try {
                              await ApiService.settleTicket(
                                ticketId: ticketId,
                                actualAmount: actual!,
                                tipAmount: tip,
                              );
                              if (!mounted) return;
                              Navigator.pop(context);
                              await SuccessOverlay.show(context,
                                  message: tip > 0 ? 'SETTLED · +${tip.toStringAsFixed(2)} ETB TIP' : 'SETTLED');
                            } catch (e) {
                              setSheetState(() => errorText = 'Network Error: $e');
                            } finally {
                              if (mounted) setSheetState(() => isSubmitting = false);
                            }
                          },
                    child: isSubmitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('SETTLE TICKET'),
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
        Text(value,
            style: AppTypography.money(
              size: 14,
              weight: FontWeight.w700,
              color: valueColor ?? AppColors.textPrimary,
            )),
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
          return ErrorBanner(message: 'Connection error.');
        }
        final pending =
            (snapshot.data ?? []).where((t) => t['status'] == 'pending').toList();
        if (pending.isEmpty) {
          return const EmptyView(message: 'Queue is clear.', icon: Icons.check_circle_outline);
        }
        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.page),
          itemCount: pending.length,
          itemBuilder: (context, index) {
            final t = pending[index];
            final bank = (t['bank'] ?? '').toString();
            final amount = (t['bill_amount'] as num?)?.toDouble() ?? 0.0;
            return GestureDetector(
              onTap: () => _showSettlementSheet(t),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: const ShapeDecoration(
                  color: AppColors.surfaceContainer,
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
                      child: const Icon(Icons.notifications_active,
                          color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${amount.toStringAsFixed(2)} ETB',
                              style: AppTypography.money(size: 18)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              BankChip(bank: bank, color: AppColors.bank(bank)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('REF: ${t['transaction_ref']}',
                                    style: AppTypography.microLabel(),
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.textFaint),
                  ],
                ),
              ).animate().fadeIn(delay: AppMotion.stagger(index)).slideX(
                  begin: 0.1, end: 0, delay: AppMotion.stagger(index)),
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
          return const ErrorBanner(message: 'Connection error.');
        }
        final past =
            (snapshot.data ?? []).where((t) => t['status'] != 'pending').toList();
        if (past.isEmpty) {
          return const EmptyView(message: 'No settled tickets yet.', icon: Icons.receipt_long);
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
            final tip = (t['tip_amount'] as num?)?.toDouble() ?? 0.0;
            final status = isSettled ? 'settled' : 'rejected';
            final statusColor = isSettled ? AppColors.success : AppColors.danger;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: const ShapeDecoration(
                color: AppColors.surfaceContainer,
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
                        icon: isSettled ? Icons.check_circle : Icons.cancel,
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
                  Text('REF: ${t['transaction_ref']}  •  Waiter: ${t['waiter_id']}',
                      style: AppTypography.microLabel()),
                  if (isSettled && tip > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: ShapeDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          shape: const ContinuousRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                        ),
                        child: Text(
                          'Includes ${tip.toStringAsFixed(2)} ETB tip (total ${actual.toStringAsFixed(2)})',
                          style: AppTypography.microLabel(color: AppColors.success)
                              .copyWith(fontSize: 10),
                        ),
                      ),
                    ),
                ],
              ),
            ).animate().fadeIn(delay: AppMotion.stagger(index)).slideX(
                begin: 0.1, end: 0, delay: AppMotion.stagger(index));
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
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.logout, color: AppColors.danger),
          onPressed: _handleLogout,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshData,
          ),
        ],
        title: const Text('CASHIER DESK'),
        titleTextStyle: AppTypography.appBarTitle(),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.md),
            child: SegmentedTabs(
              tabs: const ['PENDING', 'SETTLED'],
              index: _tabIndex,
              onChanged: (i) => setState(() => _tabIndex = i),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _tabIndex,
              children: [_buildPendingQueue(), _buildSettledLedger()],
            ),
          ),
        ],
      ),
    );
  }
}
