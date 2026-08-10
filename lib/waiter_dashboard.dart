import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'api_service.dart';
import 'receipt_parser.dart';
import 'staff_login_screen.dart'; // FIXED: Points to the new login screen
import 'core/theme/app_colors.dart';
import 'core/theme/app_typography.dart';
import 'core/theme/app_spacing.dart';
import 'core/widgets/app_shell.dart';
import 'core/widgets/state_views.dart';
import 'localization_service.dart';

class WaiterDashboard extends StatefulWidget {
  const WaiterDashboard({super.key});

  @override
  State<WaiterDashboard> createState() => _WaiterDashboardState();
}

class _WaiterDashboardState extends State<WaiterDashboard> {
  late Stream<List<Map<String, dynamic>>> _myTicketsStream;
  late Stream<List<Map<String, dynamic>>> _attemptsStream;

  // Camera Variables
  CameraController? _cameraController;
  List<CameraDescription>? _availableCameras;
  bool _isCameraInitialized = false;
  bool _isCameraInitializing = false;
  bool _isExtracting = false;
  String? _selectedBank;
  String? _cameraError;

  static const _banks = <({String name, String subtitle, IconData icon})>[
    (
      name: 'Telebirr',
      subtitle: 'Mobile money',
      icon: Icons.phone_android_rounded,
    ),
    (
      name: 'CBE',
      subtitle: 'Commercial Bank',
      icon: Icons.account_balance_rounded,
    ),
    (
      name: 'CBEBirr',
      subtitle: 'CBE mobile wallet',
      icon: Icons.wallet_rounded,
    ),
    (
      name: 'Dashen',
      subtitle: 'Dashen Bank',
      icon: Icons.account_balance_outlined,
    ),
    (
      name: 'Abyssinia',
      subtitle: 'Bank of Abyssinia',
      icon: Icons.apartment_rounded,
    ),
    (
      name: 'MPesa',
      subtitle: 'M-Pesa wallet',
      icon: Icons.send_to_mobile_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _myTicketsStream = ApiService.streamWaiterTickets();
    _attemptsStream = ApiService.streamMyVerificationAttempts();
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
          _availableCameras![0],
          ResolutionPreset.high,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.jpeg,
        );

        await _cameraController!.initialize();
        if (mounted) {
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
          _cameraError =
              'Camera access failed. Check the device permission and try again.';
        });
      }
    }
  }

  Future<void> _changeBank() async {
    await _cameraController?.dispose();
    _cameraController = null;
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
    _cameraController?.dispose();
    super.dispose();
  }

  // --- TAB 1: THE TICKET FEED ---
  Widget _buildTicketFeed() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _myTicketsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF6366F1)),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text(
              'No active tickets. Swipe to scan a receipt.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
            ),
          );
        }

        final activeTickets = snapshot.data!
            .where((t) => t['status'] != 'rejected')
            .toList();

        if (activeTickets.isEmpty) {
          return const Center(
            child: Text(
              'No active tickets.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
            ),
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

            return Padding(
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
                        isSettled ? Icons.check_circle : Icons.hourglass_empty,
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
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        ticket['status'].toString().toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
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

  // --- TAB 2: THE LIVE SCANNER ---
  Widget _buildScannerTab() {
    if (_selectedBank == null) {
      return _buildBankPicker();
    }
    if (_isCameraInitializing) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 18),
            Text(
              'Opening the $_selectedBank scanner…',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }
    if (_cameraError != null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Center(child: ErrorBanner(message: _cameraError!)),
      );
    }
    if (!_isCameraInitialized || _cameraController == null) {
      return _buildBankPicker();
    }

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
                          const Icon(
                            Icons.account_balance_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _selectedBank!,
                            style: AppTypography.microLabel(
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.shield_outlined,
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
                    icon: const Icon(Icons.swap_horiz_rounded),
                  ),
                ],
              ),
            ),
            Center(
              child: SizedBox(
                width: 280,
                height: 190,
                child: CustomPaint(painter: _ScannerFramePainter()),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 24,
              child: Column(
                children: [
                  const Text(
                    'Align the transaction reference inside the frame',
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
                          : const Icon(Icons.document_scanner_rounded),
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
        final availableTips = settled.fold<double>(
          0,
          (sum, t) => sum + ((t['tip_amount'] as num?)?.toDouble() ?? 0),
        );
        final pendingTips = pending.fold<double>(
          0,
          (sum, t) => sum + ((t['tip_amount'] as num?)?.toDouble() ?? 0),
        );
        final totalChecked = checks.fold<double>(
          0,
          (sum, t) => sum + ((t['bill_amount'] as num?)?.toDouble() ?? 0),
        );
        final dark = Theme.of(context).brightness == Brightness.dark;
        final walletText = dark ? Colors.white : const Color(0xFF312E81);
        final walletMuted = dark ? Colors.white70 : const Color(0xFF6366A8);

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
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
                  child: const Icon(Icons.person_rounded, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Waiter ${ApiService.currentStaffNumber ?? ''}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Verified staff profile',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const ThemeToggleButton(),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Container(
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
                    color: AppColors.primary.withValues(alpha: dark ? .2 : .1),
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
                      Icon(
                        Icons.account_balance_wallet_rounded,
                        color: walletMuted,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        context.tr('AVAILABLE TIPS'),
                        style: AppTypography.microLabel(color: walletMuted),
                      ),
                      const Spacer(),
                      const BrandMark(size: 32),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    '${availableTips.toStringAsFixed(2)} ETB',
                    style: AppTypography.money(size: 32, color: walletText),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    pendingTips > 0
                        ? '${pendingTips.toStringAsFixed(2)} ETB pending settlement'
                        : context.tr('All recorded tips are settled'),
                    style: TextStyle(
                      color: walletMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: HoverSurface(
                    onTap: () => _showReceiptHistory(checks),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.receipt_long_rounded,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 18),
                        Text(
                          '${checks.length}',
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
                            Text(
                              context.tr('View receipts'),
                              style: AppTypography.microLabel(
                                color: AppColors.primary,
                              ),
                            ),
                            const Spacer(),
                            const Icon(Icons.arrow_forward_rounded, size: 16),
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
                        const Icon(
                          Icons.payments_outlined,
                          color: AppColors.success,
                        ),
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
                          '${settled.length} settled',
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
                      icon: Icons.document_scanner_outlined,
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
                              verified
                                  ? Icons.verified_rounded
                                  : Icons.error_outline_rounded,
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
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
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
                    Icons.badge_outlined,
                    'Staff ID',
                    ApiService.currentStaffNumber ?? '—',
                  ),
                  const Divider(height: 28),
                  _profileRow(
                    Icons.storefront_outlined,
                    'Workspace',
                    'Current restaurant',
                  ),
                  const Divider(height: 28),
                  _profileRow(Icons.shield_outlined, 'Access', 'Waiter'),
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
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
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
                        const SizedBox(height: 4),
                        Text(
                          '${tickets.length} verified transactions',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: tickets.isEmpty
                  ? EmptyView(
                      message: context.tr('No checked receipts yet.'),
                      icon: Icons.receipt_long_outlined,
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
                              Container(
                                padding: const EdgeInsets.all(11),
                                decoration: BoxDecoration(
                                  color: AppColors.bank(
                                    t['bank']?.toString(),
                                  ).withValues(alpha: .12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  Icons.receipt_rounded,
                                  color: AppColors.bank(t['bank']?.toString()),
                                  size: 20,
                                ),
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
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'REF ${t['transaction_ref'] ?? '—'} • Table ${t['table_number'] ?? '—'}',
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

  Future<void> _recordAttemptBestEffort({
    required String provider,
    required String reference,
    required double expectedAmount,
    double? verifiedAmount,
    double tipAmount = 0,
    required bool verified,
    String? error,
  }) async {
    try {
      await ApiService.recordVerificationAttempt(
        provider: provider,
        transactionRef: reference,
        expectedAmount: expectedAmount,
        verifiedAmount: verifiedAmount,
        tipAmount: tipAmount,
        verified: verified,
        errorMessage: error,
      );
    } catch (e) {
      debugPrint('Verification audit could not be recorded: $e');
    }
  }

  Widget _buildBankPicker() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Text(
          context.tr('Choose a payment provider'),
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'We’ll configure the scanner and receipt rules for that bank before opening the camera.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 620;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: wide ? 3 : 2,
                childAspectRatio: wide ? 1.55 : 1.22,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _banks.length,
              itemBuilder: (context, index) {
                final bank = _banks[index];
                return HoverSurface(
                  onTap: () => _selectBankAndStartCamera(bank.name),
                  accent: AppColors.bank(bank.name),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        bank.icon,
                        color: AppColors.bank(bank.name),
                        size: 26,
                      ),
                      const Spacer(),
                      Text(
                        bank.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
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
      _showSubmissionSheet(extractedId);
    } catch (e) {
      if (mounted) {
        setState(() => _isExtracting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Scanner Error: $e')));
      }
    }
  }

  // --- TICKET SUBMISSION SHEET ---
  void _showSubmissionSheet(String? initialTransactionId) {
    final refController = TextEditingController(
      text: initialTransactionId ?? '',
    );
    final billController = TextEditingController();
    final providerExtraController = TextEditingController();
    final tableController = TextEditingController();
    String selectedBank = _selectedBank ?? 'Telebirr';
    bool isSubmitting = false;
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(
        context,
      ).colorScheme.surface.withValues(alpha: .94),
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
                      'SUBMIT TICKET',
                      style: TextStyle(
                        color: Color(0xFF6366F1),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 24),

                    DropdownButtonFormField<String>(
                      initialValue: selectedBank,
                      dropdownColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHigh,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: _buildInputDecoration(
                        'SELECT BANK',
                        Icons.account_balance,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Telebirr',
                          child: Text('Telebirr'),
                        ),
                        DropdownMenuItem(
                          value: 'CBE',
                          child: Text('Commercial Bank of Ethiopia'),
                        ),
                        DropdownMenuItem(
                          value: 'Abyssinia',
                          child: Text('Bank of Abyssinia'),
                        ),
                        DropdownMenuItem(value: 'MPesa', child: Text('M-Pesa')),
                        DropdownMenuItem(
                          value: 'Dashen',
                          child: Text('Dashen Bank'),
                        ),
                        DropdownMenuItem(
                          value: 'CBEBirr',
                          child: Text('CBE Birr'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() => selectedBank = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    if (selectedBank == 'CBE' ||
                        selectedBank == 'Abyssinia' ||
                        selectedBank == 'CBEBirr') ...[
                      TextField(
                        controller: providerExtraController,
                        keyboardType: TextInputType.number,
                        style: Theme.of(context).textTheme.bodyLarge,
                        decoration: _buildInputDecoration(
                          selectedBank == 'CBE'
                              ? 'LAST 8 ACCOUNT DIGITS'
                              : selectedBank == 'Abyssinia'
                              ? '5-DIGIT ACCOUNT SUFFIX'
                              : 'CBE BIRR PHONE NUMBER',
                          selectedBank == 'CBEBirr' ? Icons.phone : Icons.pin,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    TextField(
                      controller: tableController,
                      textCapitalization: TextCapitalization.characters,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: _buildInputDecoration(
                        'TABLE NUMBER',
                        Icons.table_restaurant,
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
                        'TRANSACTION REF',
                        Icons.receipt,
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
                            'EXPECTED BILL AMOUNT (ETB)',
                            Icons.payments,
                          ).copyWith(
                            filled: true,
                            fillColor: const Color(
                              0xFF10B981,
                            ).withValues(alpha: 0.1),
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Any transferred amount exceeding this expected bill will be classified as a tip by the cashier.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 10),
                    ),
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
                              if (tableController.text.trim().isEmpty ||
                                  refController.text.isEmpty ||
                                  billController.text.isEmpty) {
                                setSheetState(
                                  () => errorText =
                                      'Please provide the table number, transaction ref, and bill amount.',
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
                                    'Enter a valid positive bill amount.',
                                  );
                                }

                                // 2. Fetch the Admin's Official Bank Config
                                final bizData =
                                    await ApiService.fetchCurrentBusiness();
                                final accounts = bizData['bank_accounts'] ?? {};

                                // 3. Verify with Leul's External API
                                final result =
                                    await ApiService.verifyTransaction(
                                      transactionId,
                                      selectedBank,
                                      expectedAmount: enteredAmount,
                                      suffix:
                                          selectedBank == 'CBE' ||
                                              selectedBank == 'Abyssinia'
                                          ? providerExtraController.text
                                          : null,
                                      phoneNumber: selectedBank == 'CBEBirr'
                                          ? providerExtraController.text
                                          : null,
                                    );

                                if (result.isSuccess) {
                                  final apiData =
                                      result.data?['data'] ?? result.data ?? {};
                                  final apiAmount =
                                      double.tryParse(
                                        apiData['amount']?.toString() ?? '0',
                                      ) ??
                                      0.0;
                                  final apiReceiverAccount =
                                      (apiData['receiverAccount'] ??
                                              apiData['receiver_account'] ??
                                              '')
                                          .toString();

                                  // --- SECURITY CHECK 1: Underpayment ---
                                  if (apiAmount < enteredAmount) {
                                    throw Exception(
                                      "FRAUD ALERT: Underpaid! Transaction is for $apiAmount ETB, but bill is $enteredAmount ETB.",
                                    );
                                  }

                                  // Calculate Tip
                                  double calculatedTip =
                                      apiAmount > enteredAmount
                                      ? apiAmount - enteredAmount
                                      : 0.0;

                                  // --- SECURITY CHECK 2: Destination Match ---
                                  String expectedAccount = '';
                                  if (selectedBank == 'Telebirr') {
                                    expectedAccount =
                                        (accounts['telebirr_number'] ?? '')
                                            .toString();
                                  } else if (selectedBank == 'CBE') {
                                    expectedAccount =
                                        (accounts['cbe_number'] ?? '')
                                            .toString();
                                  }

                                  if (expectedAccount.isNotEmpty &&
                                      !apiReceiverAccount.contains(
                                        expectedAccount,
                                      )) {
                                    throw Exception(
                                      "FRAUD ALERT: Money went to $apiReceiverAccount, not the official restaurant account.",
                                    );
                                  }

                                  // 4. Submit to Supabase with the calculated tip
                                  await ApiService.submitVerifiedTicket(
                                    transactionId: transactionId,
                                    bankName: selectedBank,
                                    amount: enteredAmount.toStringAsFixed(2),
                                    tableNumber: tableController.text.trim(),
                                    tipAmount: calculatedTip, // Pass the tip!
                                  );
                                  await _recordAttemptBestEffort(
                                    provider: selectedBank,
                                    reference: transactionId,
                                    expectedAmount: enteredAmount,
                                    verifiedAmount: apiAmount,
                                    tipAmount: calculatedTip,
                                    verified: true,
                                  );

                                  if (!context.mounted) return;
                                  Navigator.pop(context); // Close the sheet

                                  // Show visual feedback on the dashboard
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        calculatedTip > 0
                                            ? 'Ticket Verified! Tip: $calculatedTip ETB 🎉'
                                            : 'Ticket Verified!',
                                      ),
                                      backgroundColor: const Color(0xFF10B981),
                                    ),
                                  );
                                } else {
                                  await _recordAttemptBestEffort(
                                    provider: selectedBank,
                                    reference: transactionId,
                                    expectedAmount: enteredAmount,
                                    verified: false,
                                    error: result.errorMessage,
                                  );
                                  throw Exception(
                                    result.errorMessage ??
                                        "Invalid Transaction ID.",
                                  );
                                }
                              } catch (e) {
                                setSheetState(
                                  () => errorText = e.toString().replaceAll(
                                    'Exception: ',
                                    '',
                                  ),
                                );
                              } finally {
                                if (mounted) {
                                  setSheetState(() => isSubmitting = false);
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'SUBMIT TICKET',
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

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(labelText: label, prefixIcon: Icon(icon));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const BrandLockup(compact: true),
          titleTextStyle: AppTypography.appBarTitle(),
          leading: IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
            onPressed: () {
              ApiService.logoutStaff();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const StaffLoginScreen()),
              );
            },
          ),
          actions: const [LanguageToggleButton(), ThemeToggleButton()],
          bottom: TabBar(
            dividerHeight: 0,
            tabs: [
              Tab(
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                text: context.tr('Tickets'),
              ),
              Tab(
                icon: const Icon(Icons.document_scanner_outlined, size: 18),
                text: context.tr('Scan receipt'),
              ),
              Tab(
                icon: const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 18,
                ),
                text: context.tr('Wallet'),
              ),
            ],
          ),
        ),
        body: AppBackdrop(
          child: TabBarView(
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildTicketFeed(),
              _buildScannerTab(),
              _buildWalletProfile(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScannerFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primarySoft
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const corner = 34.0;
    const radius = 20.0;
    final path = Path()
      ..moveTo(0, corner)
      ..lineTo(0, radius)
      ..quadraticBezierTo(0, 0, radius, 0)
      ..lineTo(corner, 0)
      ..moveTo(size.width - corner, 0)
      ..lineTo(size.width - radius, 0)
      ..quadraticBezierTo(size.width, 0, size.width, radius)
      ..lineTo(size.width, corner)
      ..moveTo(size.width, size.height - corner)
      ..lineTo(size.width, size.height - radius)
      ..quadraticBezierTo(
        size.width,
        size.height,
        size.width - radius,
        size.height,
      )
      ..lineTo(size.width - corner, size.height)
      ..moveTo(corner, size.height)
      ..lineTo(radius, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - radius)
      ..lineTo(0, size.height - corner);
    canvas.drawPath(path, paint);

    final scan = Paint()
      ..shader = const LinearGradient(
        colors: [Colors.transparent, AppColors.primarySoft, Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 1))
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(18, size.height / 2),
      Offset(size.width - 18, size.height / 2),
      scan,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
