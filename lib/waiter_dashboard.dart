import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:verify_me/core/theme/app_icons.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'api_service.dart';
import 'offline_storage.dart';
import 'receipt_parser.dart';
import 'staff_login_screen.dart'; // FIXED: Points to the new login screen
import 'core/theme/app_colors.dart';
import 'core/theme/app_motion.dart';
import 'core/theme/app_typography.dart';
import 'core/theme/app_spacing.dart';
import 'core/widgets/app_shell.dart';
import 'core/widgets/payment_brand.dart';
import 'core/widgets/skeleton.dart';
import 'core/widgets/state_views.dart';
import 'core/widgets/status_pill.dart';
import 'core/widgets/success_overlay.dart';
import 'core/widgets/transaction_filter_bar.dart';
import 'localization_service.dart';
import 'support_privacy_screen.dart';
import 'core/config/app_variant.dart';
import 'core/config/payment_context.dart';
import 'iphone/iphone_dashboard_shell.dart';

class WaiterDashboard extends StatefulWidget {
  const WaiterDashboard({
    super.key,
    @visibleForTesting this.forceManualReceiptEntry = false,
    this.trialMode = false,
  });

  final bool forceManualReceiptEntry;
  final bool trialMode;

  @override
  State<WaiterDashboard> createState() => _WaiterDashboardState();
}

class _WaiterDashboardState extends State<WaiterDashboard>
    with TickerProviderStateMixin {
  late Stream<List<Map<String, dynamic>>> _myTicketsStream;
  late Stream<List<Map<String, dynamic>>> _attemptsStream;
  late Stream<List<Map<String, dynamic>>> _withdrawalRequestsStream;
  bool _hideTipBalance = false;
  TransactionPeriod _historyPeriod = TransactionPeriod.all;
  DateTimeRange? _historyCustomRange;
  String? _historyPaymentMethod;

  /// Drives the scanner's sweeping beam and breathing frame. Runs only while
  /// the camera preview is live; muted by TickerMode when the Scan tab is not
  /// visible, and explicitly stopped when the picker replaces the camera.
  late final AnimationController _scanPulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  // Camera Variables
  CameraController? _cameraController;
  List<CameraDescription>? _availableCameras;
  bool _isCameraInitialized = false;
  bool _isCameraInitializing = false;
  bool _isExtracting = false;
  String? _selectedBank;
  String? _cameraError;

  static const _banks = <({String name, String subtitle, IconData icon})>[
    (name: 'Telebirr', subtitle: 'Mobile money', icon: AppIcons.mobile),
    (name: 'CBE', subtitle: 'Commercial Bank', icon: AppIcons.banking),
    (name: 'CBEBirr', subtitle: 'CBE mobile wallet', icon: AppIcons.wallet),
    (name: 'Dashen', subtitle: 'Dashen Bank', icon: AppIcons.banking),
    (name: 'Abyssinia', subtitle: 'Bank of Abyssinia', icon: AppIcons.business),
    (name: 'MPesa', subtitle: 'M-Pesa wallet', icon: AppIcons.sendToMobile),
  ];

  bool get _manualReceiptEntryOnly =>
      (kIsWeb && !AppVariant.webCameraTest) || widget.forceManualReceiptEntry;

  @override
  void initState() {
    super.initState();
    _myTicketsStream = ApiService.streamWaiterTickets();
    _attemptsStream = ApiService.streamMyVerificationAttempts();
    _withdrawalRequestsStream = ApiService.streamTipWithdrawalRequests();
    _hideTipBalance = DeviceStorage.getHideTipBalance();
  }

  void _refreshData() {
    ApiService.refreshDashboardData();
  }

  Future<void> _changeHistoryPeriod(TransactionPeriod period) async {
    if (period == TransactionPeriod.custom) {
      final now = DateTime.now();
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 2),
        lastDate: now,
        initialDateRange: _historyCustomRange,
      );
      if (range == null || !mounted) return;
      setState(() {
        _historyPeriod = period;
        _historyCustomRange = range;
      });
      return;
    }
    setState(() => _historyPeriod = period);
  }

  Future<void> _toggleTipBalance() async {
    final hidden = !_hideTipBalance;
    setState(() => _hideTipBalance = hidden);
    await DeviceStorage.saveHideTipBalance(hidden);
  }

  Future<void> _showWithdrawalRequest(double available) async {
    final amountController = TextEditingController();
    var submitting = false;
    String? errorText;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Request tip withdrawal'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Available: ${available.toStringAsFixed(2)} ETB'),
              const SizedBox(height: 14),
              TextField(
                controller: amountController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                decoration: InputDecoration(
                  labelText: 'Amount (ETB)',
                  errorText: errorText,
                  prefixIcon: const Icon(AppIcons.money),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: submitting
                  ? null
                  : () async {
                      final amount = double.tryParse(amountController.text);
                      if (amount == null || amount <= 0 || amount > available) {
                        setDialogState(
                          () => errorText =
                              'Enter an amount within your balance.',
                        );
                        return;
                      }
                      setDialogState(() {
                        submitting = true;
                        errorText = null;
                      });
                      try {
                        await ApiService.requestTipWithdrawal(amount);
                        if (!dialogContext.mounted || !mounted) return;
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(content: Text('Request sent.')),
                        );
                      } catch (error) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() {
                          submitting = false;
                          errorText = error.toString().replaceFirst(
                            'Exception: ',
                            '',
                          );
                        });
                      }
                    },
              child: submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send request'),
            ),
          ],
        ),
      ),
    );
    amountController.dispose();
  }

  Future<void> _selectBankAndStartCamera(String bank) async {
    await _cameraController?.dispose();
    _cameraController = null;
    setState(() {
      _selectedBank = bank;
      _isCameraInitialized = false;
      _isCameraInitializing = true;
      _cameraError = null;
    });
    try {
      _availableCameras = await availableCameras();
      if (_availableCameras != null && _availableCameras!.isNotEmpty) {
        _cameraController = CameraController(
          _availableCameras!.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.back,
            orElse: () => _availableCameras!.first,
          ),
          ResolutionPreset.high,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.jpeg,
        );

        await _cameraController!.initialize();
        if (mounted) {
          _scanPulse.repeat();
          setState(() {
            _isCameraInitialized = true;
            _isCameraInitializing = false;
          });
        }
      } else if (mounted) {
        setState(() {
          _isCameraInitializing = false;
          _cameraError = 'No camera was found on this device.';
        });
      }
    } catch (e) {
      debugPrint('Camera Initialization Error: $e');
      if (mounted) {
        setState(() {
          _isCameraInitializing = false;
          _cameraError = 'Camera access failed. Check the device permission and try again.';
        });
      }
    }
  }

  Future<void> _changeBank() async {
    await _cameraController?.dispose();
    _cameraController = null;
    _scanPulse.stop();
    if (mounted) {
      setState(() {
        _selectedBank = null;
        _isCameraInitialized = false;
        _cameraError = null;
      });
    }
  }

  @override
  void dispose() {
    _scanPulse.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  // --- TAB 1: THE TICKET FEED ---
  Widget _buildTicketFeed() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _myTicketsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: List.generate(
              5,
              (index) =>
                  FadeSlideIn(index: index, child: const TicketSkeletonRow()),
            ),
          );
        }

        final tickets = snapshot.data ?? const <Map<String, dynamic>>[];
        final activeTickets = tickets
            .where((t) => t['status'] != 'rejected')
            .toList();

        if (activeTickets.isEmpty) {
          return EmptyView(
            icon: AppIcons.receipt,
            title: AppVariant.usesMinimalCopy
                ? 'No payments'
                : context.tr('No open payments'),
            message: AppVariant.usesMinimalCopy
                ? 'Scan to add one'
                : context.tr(
                    'Scan a receipt to verify a payment and record a payment.',
                  ),
            actionLabel: context.tr('Scan a receipt'),
            onAction: () => DefaultTabController.maybeOf(context)?.animateTo(1),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: activeTickets.length,
          itemBuilder: (context, index) {
            final ticket = activeTickets[index];
            final isSettled = ticket['status'] == 'settled';
            final statusColor = isSettled
                ? const Color(0xFF10B981)
                : const Color(0xFFF59E0B);

            return FadeSlideIn(
              index: index.clamp(0, 5),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: HoverSurface(
                  accent: statusColor,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isSettled ? AppIcons.success : AppIcons.pending,
                          color: statusColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${ticket['bill_amount']} ETB',
                              style: AppTypography.money(),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'REF: ${ticket['transaction_ref']}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              PaymentContext.display(ticket['table_number']),
                              style: Theme.of(context).textTheme.bodySmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      StatusPill(
                        label: ticket['status'].toString(),
                        color: statusColor,
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

  // --- TAB 2: THE LIVE SCANNER ---
  Widget _buildScannerTab() {
    Widget content;
    if (_selectedBank == null) {
      content = KeyedSubtree(
        key: const ValueKey('scanner-picker'),
        child: _buildBankPicker(),
      );
    } else if (_isCameraInitializing) {
      content = KeyedSubtree(
        key: const ValueKey('scanner-opening'),
        child: LoadingView(message: 'Opening the $_selectedBank scanner…'),
      );
    } else if (_cameraError != null) {
      content = KeyedSubtree(
        key: const ValueKey('scanner-error'),
        child: _buildCameraError(),
      );
    } else if (!_isCameraInitialized || _cameraController == null) {
      content = KeyedSubtree(
        key: const ValueKey('scanner-picker'),
        child: _buildBankPicker(),
      );
    } else {
      content = KeyedSubtree(
        key: const ValueKey('scanner-live'),
        child: _buildLiveCamera(),
      );
    }
    return FadeThroughSwitcher(child: content);
  }

  Widget _buildCameraError() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            ErrorView(
              message: _cameraError!,
              onRetry: _selectedBank == null
                  ? null
                  : () => _selectBankAndStartCamera(_selectedBank!),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: () =>
                  _showSubmissionSheet(null, initialProvider: _selectedBank),
              icon: const Icon(AppIcons.keyboard, size: 18),
              label: Text(
                AppVariant.usesMinimalCopy
                    ? 'Enter manually'
                    : 'Enter payment details manually',
              ),
            ),
            TextButton.icon(
              onPressed: _changeBank,
              icon: const Icon(AppIcons.transfer, size: 18),
              label: Text(
                AppVariant.usesMinimalCopy
                    ? 'Change provider'
                    : 'Choose another provider',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveCamera() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize?.height ?? 1,
                  height: _cameraController!.value.previewSize?.width ?? 1,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: .58),
                      Colors.transparent,
                      Colors.black.withValues(alpha: .82),
                    ],
                    stops: const [0, .48, 1],
                  ),
                ),
              ),
            ),
            if (_isExtracting)
              Positioned.fill(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  opacity: 1,
                  child: ColoredBox(
                    color: Colors.white.withValues(alpha: .85),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox.square(
                            dimension: 44,
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                              strokeWidth: 3,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Reading receipt…',
                            style: AppTypography.microLabel(
                              color: Colors.black.withValues(alpha: .72),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .48),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        children: [
                          PaymentLogo(provider: _selectedBank!, size: 28),
                          const SizedBox(width: 10),
                          Text(
                            _selectedBank!,
                            style: AppTypography.microLabel(
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          const Icon(
                            AppIcons.shield,
                            color: AppColors.success,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Change bank',
                    onPressed: _changeBank,
                    icon: const Icon(AppIcons.transfer),
                  ),
                ],
              ),
            ),
            Center(
              child: SizedBox(
                width: 280,
                height: 190,
                child: AnimatedBuilder(
                  animation: _scanPulse,
                  builder: (context, _) => CustomPaint(
                    painter: _ScannerFramePainter(progress: _scanPulse.value),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 24,
              child: Column(
                children: [
                  Text(
                    AppVariant.usesMinimalCopy
                        ? 'Align receipt'
                        : 'Align the transaction reference inside the frame',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isExtracting ? null : _captureAndExtract,
                      icon: _isExtracting
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(AppIcons.scanReceipt),
                      label: Text(
                        context.tr(
                          _isExtracting ? 'READING RECEIPT' : 'CAPTURE RECEIPT',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletProfile() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _myTicketsStream,
      builder: (context, snapshot) {
        final tickets = snapshot.data ?? const <Map<String, dynamic>>[];
        final checks = tickets.where((t) => t['status'] != 'rejected').toList();
        final settled = checks.where((t) => t['status'] == 'settled').toList();
        final pending = checks.where((t) => t['status'] == 'pending').toList();
        final historyChecks = filterTransactions(
          checks,
          period: _historyPeriod,
          customRange: _historyCustomRange,
          paymentMethod: _historyPaymentMethod,
        );
        final historySettled = historyChecks
            .where((t) => t['status'] == 'settled')
            .toList();
        final availableTips = settled.fold<double>(
          0,
          (sum, t) => sum + ((t['tip_amount'] as num?)?.toDouble() ?? 0),
        );
        final pendingTips = pending.fold<double>(
          0,
          (sum, t) => sum + ((t['tip_amount'] as num?)?.toDouble() ?? 0),
        );
        final totalChecked = historyChecks.fold<double>(
          0,
          (sum, t) =>
              sum +
              ((t['verified_amount'] as num?)?.toDouble() ??
                  (t['actual_amount'] as num?)?.toDouble() ??
                  (t['bill_amount'] as num?)?.toDouble() ??
                  0),
        );
        final dark = Theme.of(context).brightness == Brightness.dark;
        final walletText = dark ? Colors.white : const Color(0xFF312E81);
        final walletMuted = dark ? Colors.white70 : const Color(0xFF6366A8);

        return ListView(
          padding: EdgeInsets.all(AppVariant.usesIPhoneUi ? 16 : AppSpacing.xl),
          children: [
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.violet],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(AppIcons.user, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Staff ${ApiService.currentStaffNumber ?? ''}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (!AppVariant.usesMinimalCopy &&
                          !AppVariant.usesIPhoneUi) ...[
                        const SizedBox(height: 3),
                        Text(
                          'Verified staff profile',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                if (!AppVariant.usesIPhoneUi) const GlassThemeToggleButton(),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            FadeSlideIn(
              index: 1,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: dark
                        ? const [Color(0xFF4338CA), Color(0xFF6D28D9)]
                        : const [Color(0xFFE8EAFF), Color(0xFFF1EAFE)],
                  ),
                  border: dark
                      ? null
                      : Border.all(
                          color: AppColors.primary.withValues(alpha: .16),
                        ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(
                        alpha: dark ? .2 : .1,
                      ),
                      blurRadius: 32,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(AppIcons.receipt, color: walletMuted),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            context.tr('VERIFIED PAYMENTS'),
                            style: AppTypography.microLabel(color: walletMuted),
                          ),
                        ),
                        IconButton(
                          tooltip: _hideTipBalance
                              ? 'Show balance'
                              : 'Hide balance',
                          onPressed: _toggleTipBalance,
                          color: walletMuted,
                          icon: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: Icon(
                              _hideTipBalance
                                  ? AppIcons.hidden
                                  : AppIcons.visible,
                              key: ValueKey(_hideTipBalance),
                            ),
                          ),
                        ),
                        const BrandMark(size: 32),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      _hideTipBalance
                          ? '••••••'
                          : '${totalChecked.toStringAsFixed(2)} ETB',
                      style: AppTypography.money(size: 32, color: walletText),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${_historyPeriod.label} · ${historyChecks.length} payments · ${historySettled.length} settled',
                      style: TextStyle(
                        color: walletMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _withdrawalRequestsStream,
              builder: (context, withdrawalSnapshot) {
                final requests = withdrawalSnapshot.data ?? const [];
                final committed = requests
                    .where(
                      (request) =>
                          request['status'] == 'pending' ||
                          request['status'] == 'approved',
                    )
                    .fold<double>(
                      0,
                      (sum, request) =>
                          sum + ((request['amount'] as num?)?.toDouble() ?? 0),
                    );
                final withdrawable = (availableTips - committed)
                    .clamp(0, double.infinity)
                    .toDouble();
                final pendingRequests = requests
                    .where((request) => request['status'] == 'pending')
                    .length;
                return GlassPanel(
                  padding: const EdgeInsets.all(16),
                  child: ExpansionTile(
                    key: const Key('optional-staff-tips'),
                    tilePadding: EdgeInsets.zero,
                    title: Text(context.tr('Staff tips')),
                    subtitle: Text(context.tr('For teams that accept tips')),
                    children: [
                      Row(
                        children: [
                          const Icon(AppIcons.outbox, color: AppColors.success),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppVariant.usesMinimalCopy
                                      ? 'Withdraw'
                                      : 'Tip withdrawal',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  pendingRequests > 0
                                      ? '$pendingRequests request pending'
                                      : '${withdrawable.toStringAsFixed(2)} ETB available · ${pendingTips.toStringAsFixed(2)} pending',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: withdrawable > 0
                                ? () => _showWithdrawalRequest(withdrawable)
                                : null,
                            icon: const Icon(AppIcons.send, size: 18),
                            label: const Text('Request'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            TransactionFilterBar(
              period: _historyPeriod,
              customRange: _historyCustomRange,
              onPeriodChanged: _changeHistoryPeriod,
              paymentMethods:
                  checks
                      .map((ticket) => ticket['bank']?.toString() ?? '')
                      .where((method) => method.isNotEmpty)
                      .toSet()
                      .toList()
                    ..sort(),
              paymentMethod: _historyPaymentMethod,
              onPaymentMethodChanged: (value) =>
                  setState(() => _historyPaymentMethod = value),
            ),
            const SizedBox(height: AppSpacing.lg),
            FadeSlideIn(
              index: 2,
              child: Row(
                children: [
                  Expanded(
                    child: HoverSurface(
                      onTap: () => _showReceiptHistory(historyChecks),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            AppIcons.receipt,
                            color: AppColors.primary,
                          ),
                          const SizedBox(height: 18),
                          Text(
                            '${historyChecks.length}',
                            style: AppTypography.money(size: 26),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.tr('Total checks'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  context.tr('View receipts'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.microLabel(
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(AppIcons.forward, size: 16),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: HoverSurface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(AppIcons.money, color: AppColors.success),
                          const SizedBox(height: 18),
                          Text(
                            '${totalChecked.toStringAsFixed(0)} ETB',
                            style: AppTypography.money(size: 26),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.tr('Verified volume'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${historySettled.length} settled',
                            style: AppTypography.microLabel(
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Text(
                  context.tr('RECENT SCANS'),
                  style: AppTypography.microLabel(),
                ),
                const Spacer(),
                Text(
                  context.tr('Verified and failed attempts'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 10),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _attemptsStream,
              builder: (context, attemptSnapshot) {
                final attempts =
                    attemptSnapshot.data ?? const <Map<String, dynamic>>[];
                if (attempts.isEmpty) {
                  return HoverSurface(
                    child: EmptyView(
                      message: context.tr('No receipt scans recorded yet.'),
                      icon: AppIcons.scanReceipt,
                    ),
                  );
                }
                return Column(
                  children: attempts.take(5).map((attempt) {
                    final verified = attempt['outcome'] == 'verified';
                    final amount = (attempt['verified_amount'] as num?)
                        ?.toDouble();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: HoverSurface(
                        accent: verified ? AppColors.success : AppColors.danger,
                        child: Row(
                          children: [
                            Icon(
                              verified ? AppIcons.verified : AppIcons.error,
                              color: verified
                                  ? AppColors.success
                                  : AppColors.danger,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    attempt['transaction_ref']?.toString() ??
                                        'Reference not extracted',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${attempt['provider'] ?? 'provider'} • ${_formatTicketTime(attempt['created_at'])}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  verified ? 'VERIFIED' : 'FAILED',
                                  style: AppTypography.microLabel(
                                    color: verified
                                        ? AppColors.success
                                        : AppColors.danger,
                                  ),
                                ),
                                if (amount != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '${amount.toStringAsFixed(2)} ETB',
                                    style: AppTypography.money(size: 13),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('ACCOUNT', style: AppTypography.microLabel()),
            const SizedBox(height: 10),
            HoverSurface(
              child: Column(
                children: [
                  _profileRow(
                    AppIcons.staffBadge,
                    'Staff ID',
                    ApiService.currentStaffNumber ?? '—',
                  ),
                  const Divider(height: 28),
                  _profileRow(
                    AppIcons.storefront,
                    'Workspace',
                    'Current business',
                  ),
                  const Divider(height: 28),
                  _profileRow(AppIcons.shield, 'Access', 'Staff'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _profileRow(IconData icon, String label, String value) => Row(
    children: [
      Icon(icon, size: 20, color: AppColors.textMuted),
      const SizedBox(width: 12),
      Text(label, style: Theme.of(context).textTheme.bodyMedium),
      const Spacer(),
      Text(
        value,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
    ],
  );

  void _showReceiptHistory(List<Map<String, dynamic>> tickets) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .78,
        maxChildSize: .94,
        builder: (context, controller) => Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('Checked receipts'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (!AppVariant.usesMinimalCopy) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${tickets.length} verified transactions',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(AppIcons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: tickets.isEmpty
                  ? EmptyView(
                      message: context.tr('No checked receipts yet.'),
                      icon: AppIcons.receipt,
                    )
                  : ListView.separated(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                      itemCount: tickets.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final t = tickets[index];
                        final amount =
                            (t['bill_amount'] as num?)?.toDouble() ?? 0;
                        final tip = (t['tip_amount'] as num?)?.toDouble() ?? 0;
                        final settled = t['status'] == 'settled';
                        return HoverSurface(
                          accent: settled
                              ? AppColors.success
                              : AppColors.warning,
                          child: Row(
                            children: [
                              PaymentLogo(
                                provider: t['bank']?.toString() ?? '',
                                size: 42,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${amount.toStringAsFixed(2)} ETB',
                                      style: AppTypography.money(size: 16),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${t['bank'] ?? 'Bank'} • ${_formatTicketTime(t['created_at'])}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'REF ${t['transaction_ref'] ?? '—'} • ${PaymentContext.display(t['table_number'])}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.microLabel(),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    settled ? 'SETTLED' : 'PENDING',
                                    style: AppTypography.microLabel(
                                      color: settled
                                          ? AppColors.success
                                          : AppColors.warning,
                                    ),
                                  ),
                                  if (tip > 0) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      '+${tip.toStringAsFixed(2)} tip',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: AppColors.success),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTicketTime(dynamic raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (date == null) return 'Time unavailable';
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)} ${two(date.hour)}:${two(date.minute)}';
  }

  Widget _buildBankPicker() {
    return ListView(
      padding: EdgeInsets.all(AppVariant.usesIPhoneUi ? 16 : AppSpacing.xl),
      children: [
        Text(
          context.tr('Payment method'),
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (!AppVariant.usesMinimalCopy && !AppVariant.usesIPhoneUi) ...[
          const SizedBox(height: 8),
          Text(
            _manualReceiptEntryOnly
                ? 'Select a provider, then enter the payment details from the receipt.'
                : 'Select a provider to scan its receipt.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
        if (_manualReceiptEntryOnly) ...[
          const SizedBox(height: AppSpacing.lg),
          GlassPanel(
            padding: EdgeInsets.all(AppSpacing.md),
            accent: AppColors.aqua,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(AppIcons.language, color: AppColors.aqua),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    context.tr(
                      'Use manual entry in Safari. Camera scanning works in the iPhone app.',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 620;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: wide ? 3 : 2,
                // Slightly taller cards on phones so the iPhone text theme
                // (and larger accessibility text) never overflows the tile.
                childAspectRatio: wide ? 1.55 : 1.05,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _banks.length,
              itemBuilder: (context, index) {
                final bank = _banks[index];
                return HoverSurface(
                  onTap: () {
                    if (_manualReceiptEntryOnly) {
                      _showSubmissionSheet(null, initialProvider: bank.name);
                    } else {
                      _selectBankAndStartCamera(bank.name);
                    }
                  },
                  accent: AppColors.bank(bank.name),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PaymentLogo(provider: bank.name, size: 42),
                      const SizedBox(height: 10),
                      Flexible(
                        child: Text(
                          bank.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        bank.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  // --- SCANNER EXECUTION & EXTRACTION ---
  Future<void> _captureAndExtract() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() => _isExtracting = true);

    try {
      final XFile imageFile = await _cameraController!.takePicture();
      final originalBytes = await imageFile.readAsBytes();
      // ML Kit text recognition is native-only. The HTTPS browser test captures
      // the receipt and lets the tester enter its reference manually.
      if (kIsWeb) {
        if (!mounted) return;
        setState(() => _isExtracting = false);
        _showSubmissionSheet(null, receiptImageBytes: originalBytes);
        return;
      }
      final receiptImageBytes = await FlutterImageCompress.compressWithList(
        originalBytes,
        minWidth: 1280,
        minHeight: 1600,
        quality: 68,
        format: CompressFormat.jpeg,
        keepExif: false,
      );
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final textRecognizer = TextRecognizer(
        script: TextRecognitionScript.latin,
      );
      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );
      await textRecognizer.close();

      String? extractedId = ReceiptParser.extractTransactionId(
        recognizedText.text,
        _selectedBank ?? 'Universal / Unknown',
      );

      setState(() => _isExtracting = false);

      if (!mounted) return;
      _showSubmissionSheet(extractedId, receiptImageBytes: receiptImageBytes);
    } catch (e) {
      if (mounted) {
        setState(() => _isExtracting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Scanner Error: $e')));
      }
    }
  }

  // --- TICKET SUBMISSION SHEET ---
  void _showSubmissionSheet(
    String? initialTransactionId, {
    Uint8List? receiptImageBytes,
    String? initialProvider,
  }) {
    final refController = TextEditingController(
      text: initialTransactionId ?? '',
    );
    final billController = TextEditingController();
    final tableController = TextEditingController();
    PaymentContextKind contextKind = PaymentContextKind.invoice;
    String selectedBank = initialProvider ?? _selectedBank ?? 'Telebirr';
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
                      AppVariant.usesMinimalCopy
                          ? 'NEW PAYMENT'
                          : 'VERIFY PAYMENT',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 24),

                    DropdownButtonFormField<String>(
                      initialValue: selectedBank,
                      dropdownColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHigh,
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                      decoration: _buildInputDecoration(
                        AppVariant.usesMinimalCopy ? 'BANK' : 'SELECT BANK',
                        AppIcons.banking,
                      ),
                      items: const [
                        DropdownMenuItem<String>(
                          value: 'Telebirr',
                          child: PaymentBrand(provider: 'Telebirr'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'CBE',
                          child: PaymentBrand(provider: 'CBE'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'Abyssinia',
                          child: PaymentBrand(provider: 'Abyssinia'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'MPesa',
                          child: PaymentBrand(provider: 'M-Pesa'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'Dashen',
                          child: PaymentBrand(provider: 'Dashen'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'CBEBirr',
                          child: PaymentBrand(provider: 'CBE Birr'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() => selectedBank = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<PaymentContextKind>(
                      key: const Key('payment-context-kind'),
                      initialValue: contextKind,
                      isExpanded: true,
                      decoration: _buildInputDecoration(
                        context.tr('LINK PAYMENT TO'),
                        AppIcons.receipt,
                      ),
                      items: PaymentContextKind.values
                          .map(
                            (kind) => DropdownMenuItem(
                              value: kind,
                              child: Text(context.tr(kind.label)),
                            ),
                          )
                          .toList(),
                      onChanged: isSubmitting
                          ? null
                          : (kind) {
                              if (kind != null) {
                                setSheetState(() => contextKind = kind);
                              }
                            },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('payment-context-value'),
                      controller: tableController,
                      enabled: !isSubmitting,
                      maxLength: 80,
                      textCapitalization: TextCapitalization.characters,
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                      decoration:
                          _buildInputDecoration(
                            '${context.tr(contextKind.fieldLabel)} (${context.tr('optional')})',
                            contextKind == PaymentContextKind.table
                                ? AppIcons.table
                                : AppIcons.receipt,
                          ).copyWith(
                            hintText: contextKind.hint,
                            helperText: context.tr(
                              'Leave blank to use the bank reference.',
                            ),
                            helperMaxLines: 2,
                          ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: refController,
                      textCapitalization: TextCapitalization.characters,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                      decoration: _buildInputDecoration(
                        AppVariant.usesMinimalCopy
                            ? 'REFERENCE'
                            : 'TRANSACTION REF',
                        AppIcons.receipt,
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: billController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'),
                        ),
                      ],
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                      decoration:
                          _buildInputDecoration(
                            AppVariant.usesMinimalCopy
                                ? 'AMOUNT (ETB)'
                                : 'AMOUNT DUE (ETB)',
                            AppIcons.money,
                          ).copyWith(
                            filled: true,
                            fillColor: const Color(0xFF10B981)
                                .withValues(alpha: 0.1),
                          ),
                    ),
                    if (!AppVariant.usesMinimalCopy) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Enter the full amount due. Any excess payment is currently recorded as a staff tip.',
                        style: TextStyle(
                          color: AppColors.textFaint,
                          fontSize: 10,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    if (errorText != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
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
                              if (refController.text.trim().isEmpty ||
                                  billController.text.isEmpty) {
                                setSheetState(
                                  () => errorText = 'Enter the bank transaction reference and amount due.',
                                );
                                return;
                              }

                              setSheetState(() {
                                isSubmitting = true;
                                errorText = null;
                              });

                              try {
                                final amountStr = billController.text.trim();
                                final enteredAmount = double.tryParse(
                                  amountStr,
                                );
                                final transactionId = refController.text
                                    .trim()
                                    .toUpperCase();
                                if (enteredAmount == null ||
                                    !enteredAmount.isFinite ||
                                    enteredAmount <= 0) {
                                  throw Exception(
                                    'Enter a valid positive amount due.',
                                  );
                                }

                                final result =
                                    await ApiService.verifyAndCreateTicket(
                                      transactionId: transactionId,
                                      provider: selectedBank,
                                      expectedAmount: enteredAmount,
                                      tableNumber: PaymentContext.encode(
                                        contextKind,
                                        tableController.text,
                                        transactionId,
                                      ),
                                      receiptImageBytes: receiptImageBytes,
                                    );

                                if (result.isSuccess) {
                                  final data =
                                      result.data?['data'] as Map? ?? const {};
                                  final calculatedTip =
                                      (data['tipAmount'] as num?)?.toDouble() ??
                                      (data['tip_amount'] as num?)
                                          ?.toDouble() ??
                                      0;

                                  if (!mounted || !context.mounted) return;
                                  submissionSucceeded = true;
                                  Navigator.pop(context); // Close the sheet

                                  // Success animation only ever follows the
                                  // backend's authoritative verification —
                                  // pending and failed results never reach it.
                                  await SuccessOverlay.show(
                                    this.context,
                                    message: calculatedTip > 0
                                        ? 'VERIFIED · +${calculatedTip.toStringAsFixed(2)} ETB TIP'
                                        : 'VERIFIED',
                                  );
                                } else {
                                  throw Exception(result.displayErrorMessage);
                                }
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
                          : Text(
                              AppVariant.usesMinimalCopy
                                  ? 'SUBMIT'
                                  : 'VERIFY PAYMENT',
                              style: const TextStyle(
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

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(labelText: label, prefixIcon: Icon(icon));
  }

  Future<void> _signOutOrExit() async {
    if (widget.trialMode) {
      Navigator.of(context).pop();
      return;
    }
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppVariant.usesIPhoneUi
            ? IPhoneDashboardNavigationBar(
                title: Text(context.tr(widget.trialMode ? 'Demo' : 'Staff')),
                onSignOut: _signOutOrExit,
                onHelp: _openHelpAndPrivacy,
                onRefresh: _refreshData,
              )
            : AppBar(
                title: const BrandLockup(compact: true),
                titleTextStyle: AppTypography.appBarTitle(),
                leading: IconButton(
                  tooltip: widget.trialMode ? 'Exit demo' : 'Sign out',
                  icon: Icon(
                    widget.trialMode ? AppIcons.close : AppIcons.logout,
                    color: AppColors.danger,
                  ),
                  onPressed: _signOutOrExit,
                ),
                actions: [
                  const GlassLanguageToggleButton(),
                  const GlassThemeToggleButton(),
                  IconButton(
                    tooltip: 'Help and privacy',
                    icon: const Icon(AppIcons.support),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SupportPrivacyScreen(),
                      ),
                    ),
                  ),
                ],
                bottom: TabBar(
                  dividerHeight: 0,
                  tabs: [
                    Tab(
                      icon: const Icon(AppIcons.receipt, size: 18),
                      text: context.tr('Payments'),
                    ),
                    Tab(
                      icon: const Icon(AppIcons.scanReceipt, size: 18),
                      text: context.tr('Scan receipt'),
                    ),
                    Tab(
                      icon: const Icon(AppIcons.history, size: 18),
                      text: context.tr('Activity'),
                    ),
                  ],
                ),
              ),
        body: AppBackdrop(
          child: DashboardTabView(
            preserveState: AppVariant.usesIPhoneUi,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildTicketFeed(),
              _buildScannerTab(),
              _buildWalletProfile(),
            ],
          ),
        ),
        bottomNavigationBar: AppVariant.usesIPhoneUi
            ? IPhoneBottomTabBar(
                items: [
                  IPhoneTabItem(
                    label: context.tr('Payments'),
                    icon: AppIcons.receipt,
                  ),
                  IPhoneTabItem(
                    label: context.tr('Scan'),
                    icon: AppIcons.scanReceipt,
                  ),
                  IPhoneTabItem(
                    label: context.tr('Activity'),
                    icon: AppIcons.history,
                  ),
                ],
              )
            : null,
      ),
    );
  }
}

/// The scanner's guidance frame. [progress] (0..1, looping) drives:
///  • corner brackets that breathe gently in and out,
///  • a horizontal beam that sweeps down the frame and back,
///  • a faint violet wash that follows the beam, like light catching paper.
class _ScannerFramePainter extends CustomPainter {
  _ScannerFramePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    // Corner brackets breathe between 96% and 100% scale around the center.
    final breathe = Curves.easeInOut.transform(
      (sin(progress * 2 * pi) + 1) / 2,
    );
    final bracketPaint = Paint()
      ..color = AppColors.primarySoft.withValues(alpha: .85 + .15 * breathe)
      ..strokeWidth = 3 + breathe
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const corner = 34.0;
    const radius = 20.0;
    final inset = 6 * breathe;
    final path = Path()
      ..moveTo(inset, corner)
      ..lineTo(inset, radius + inset)
      ..quadraticBezierTo(inset, inset, radius + inset, inset)
      ..lineTo(corner, inset)
      ..moveTo(size.width - corner, inset)
      ..lineTo(size.width - radius - inset, inset)
      ..quadraticBezierTo(
        size.width - inset,
        inset,
        size.width - inset,
        radius + inset,
      )
      ..lineTo(size.width - inset, corner)
      ..moveTo(size.width - inset, size.height - corner)
      ..lineTo(size.width - inset, size.height - radius - inset)
      ..quadraticBezierTo(
        size.width - inset,
        size.height - inset,
        size.width - radius - inset,
        size.height - inset,
      )
      ..lineTo(size.width - corner, size.height - inset)
      ..moveTo(corner, size.height - inset)
      ..lineTo(radius + inset, size.height - inset)
      ..quadraticBezierTo(
        inset,
        size.height - inset,
        inset,
        size.height - radius - inset,
      )
      ..lineTo(inset, size.height - corner);
    canvas.drawPath(path, bracketPaint);

    // The beam sweeps top→bottom→top over the loop.
    final sweep = Curves.easeInOutCubic.transform(
      progress < .5 ? progress * 2 : 2 - progress * 2,
    );
    final beamY = 20 + (size.height - 40) * sweep;

    // Soft wash trailing the beam.
    final wash = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.primary.withValues(alpha: 0),
          AppColors.primary.withValues(alpha: .10),
        ],
      ).createShader(Rect.fromLTWH(0, beamY - 46, size.width, 46));
    canvas.drawRect(Rect.fromLTWH(0, beamY - 46, size.width, 46), wash);

    // Bright beam line.
    final beam = Paint()
      ..shader = LinearGradient(
        colors: const [
          Colors.transparent,
          AppColors.primarySoft,
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, beamY - 1, size.width, 2))
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(14, beamY), Offset(size.width - 14, beamY), beam);
  }

  @override
  bool shouldRepaint(covariant _ScannerFramePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
