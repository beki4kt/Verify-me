import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'core/services/demo_verification_client.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_icons.dart';
import 'core/theme/app_motion.dart';
import 'core/widgets/app_shell.dart';
import 'core/widgets/payment_brand.dart';
import 'core/widgets/state_views.dart';
import 'receipt_parser.dart';

class DemoScannerScreen extends StatefulWidget {
  const DemoScannerScreen({super.key, this.client, this.manualOnly = false});
  final DemoVerificationClient? client;
  final bool manualOnly;
  @override
  State<DemoScannerScreen> createState() => _DemoScannerScreenState();
}

class _DemoScannerScreenState extends State<DemoScannerScreen> {
  late final DemoVerificationClient _client =
      widget.client ?? DemoVerificationClient();
  int? _remaining;
  String? _error;
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final state = await _client.usage();
      if (mounted) {
        setState(() {
          _remaining = (state['remaining'] as num?)?.toInt();
          _error = state['error']?.toString();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  void dispose() {
    if (widget.client == null) _client.close();
    super.dispose();
  }

  Future<void> _open(String provider, String label) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _DemoReceiptScreen(
          provider: provider,
          label: label,
          client: _client,
          remaining: _remaining,
          manualOnly: widget.manualOnly,
        ),
      ),
    );
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    appBar: AppBar(
      title: const Text('Demo scanner'),
      actions: const [GlassLanguageToggleButton(), GlassThemeToggleButton()],
    ),
    body: AppBackdrop(
      maxWidth: 760,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          FadeSlideIn(
            child: GlassPanel(
              padding: const EdgeInsets.all(24),
              accent: AppColors.aqua,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const HeroPillBadge(
                    label: 'TRY A REAL RECEIPT',
                    icon: AppIcons.scanReceipt,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Choose a payment method.',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Scan a receipt or enter its reference. See the provider’s result without connecting a business.',
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _remaining == null
                        ? '10 free checks per installation'
                        : '$_remaining of 10 free checks remaining',
                    key: const Key('demo-remaining'),
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(color: AppColors.aqua),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Each lookup uses one check, including unsuccessful lookups. Demo results are not saved as business payments.',
                    style: TextStyle(fontSize: 12, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            ErrorBanner(message: _error!),
            TextButton(
              onPressed: _refresh,
              child: const Text('Refresh demo status'),
            ),
          ],
          if (_remaining == 0) ...[
            const SizedBox(height: 20),
            const Text(
              'Your 10 free checks are complete. Connect your business from the welcome screen to continue.',
            ),
          ],
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, bounds) {
              const methods = [
                ('telebirr', 'Telebirr'),
                ('cbe', 'CBE'),
                ('cbebirr', 'CBE Birr'),
                ('dashen', 'Dashen'),
                ('abyssinia', 'Abyssinia'),
                ('mpesa', 'M-Pesa'),
              ];
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (var i = 0; i < methods.length; i++)
                    SizedBox(
                      width: (bounds.maxWidth - 12) / 2,
                      child: FadeSlideIn(
                        index: i + 1,
                        child: HoverSurface(
                          onTap: _remaining == 0
                              ? null
                              : () => _open(methods[i].$1, methods[i].$2),
                          padding: const EdgeInsets.all(18),
                          accent: AppColors.bank(methods[i].$2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              PaymentLogo(provider: methods[i].$2, size: 42),
                              const SizedBox(height: 14),
                              Text(
                                methods[i].$2,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              const Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Try a receipt',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  Icon(AppIcons.forward, size: 17),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}

class _DemoReceiptScreen extends StatefulWidget {
  const _DemoReceiptScreen({
    required this.provider,
    required this.label,
    required this.client,
    required this.remaining,
    required this.manualOnly,
  });
  final String provider, label;
  final DemoVerificationClient client;
  final int? remaining;
  final bool manualOnly;
  @override
  State<_DemoReceiptScreen> createState() => _DemoReceiptScreenState();
}

class _DemoReceiptScreenState extends State<_DemoReceiptScreen>
    with WidgetsBindingObserver {
  final _reference = TextEditingController(),
      _account = TextEditingController();
  CameraController? _camera;
  int _cameraGeneration = 0;
  bool _busy = false, _capturing = false;
  String? _error, _cameraError;
  Map<String, dynamic>? _result;
  late int? _remaining = widget.remaining;
  bool get _nativeCamera =>
      !widget.manualOnly &&
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_nativeCamera) _startCamera();
  }

  Future<void> _stopCamera() async {
    _cameraGeneration++;
    final camera = _camera;
    _camera = null;
    await camera?.dispose();
  }

  Future<void> _startCamera() async {
    final generation = ++_cameraGeneration;
    try {
      final cameras = await availableCameras();
      if (!mounted || generation != _cameraGeneration) return;
      if (cameras.isEmpty) throw Exception('No camera is available.');
      final camera = CameraController(
        cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first,
        ),
        ResolutionPreset.high,
        enableAudio: false,
      );
      _camera = camera;
      await camera.initialize();
      if (!mounted || generation != _cameraGeneration) return;
      setState(() => _cameraError = null);
    } catch (_) {
      if (mounted && generation == _cameraGeneration) {
        setState(
          () => _cameraError = 'Camera access is unavailable. Enter the reference below or enable camera permission.',
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_nativeCamera) return;
    if (state == AppLifecycleState.inactive) {
      _stopCamera();
    }
    if (state == AppLifecycleState.resumed && _camera == null) {
      _startCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopCamera();
    _reference.dispose();
    _account.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (_capturing || _busy || _camera?.value.isInitialized != true) return;
    setState(() => _capturing = true);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final file = await _camera!.takePicture();
      final text = await recognizer.processImage(
        InputImage.fromFilePath(file.path),
      );
      if (!mounted) return;
      final reference = ReceiptParser.extractTransactionId(
        text.text,
        widget.provider,
      );
      setState(() {
        if (reference != null) _reference.text = reference;
        _error = reference == null
            ? 'Could not read the reference. You can type it below.'
            : null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not read this photo. Try again or enter the reference.',
        );
      }
    } finally {
      await recognizer.close();
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _verify({bool statusOnly = false}) async {
    if (_busy) return;
    if (!statusOnly && _reference.text.trim().isEmpty) {
      setState(() => _error = 'Enter the receipt reference.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    FocusScope.of(context).unfocus();
    try {
      final result = statusOnly
          ? await widget.client.checkResult()
          : await widget.client.verify(
              provider: widget.provider,
              reference: _reference.text,
              receivingAccount: _account.text,
            );
      if (!mounted) return;
      setState(() {
        _remaining = (result['remaining'] as num?)?.toInt() ?? _remaining;
        _result = result['success'] == true && result['receipt'] is Map
            ? Map<String, dynamic>.from(result['receipt'])
            : null;
        _error = _result == null
            ? (result['error']?.toString() ?? 'No completed demo result yet.')
            : null;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('${widget.label} demo')),
    body: AppBackdrop(
      maxWidth: 620,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const HeroPillBadge(
            label: 'DEMO SCAN MODE',
            icon: AppIcons.scanReceipt,
          ),
          const SizedBox(height: 16),
          Text(
            _remaining == null
                ? '10 free checks per installation'
                : '$_remaining checks remaining',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          if (_nativeCamera) ...[
            if (_camera?.value.isInitialized == true)
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(height: 210, child: CameraPreview(_camera!)),
              ),
            if (_cameraError != null) Text(_cameraError!),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _busy || _capturing ? null : _capture,
              icon: const Icon(AppIcons.scanReceipt),
              label: Text(_capturing ? 'Reading receipt…' : 'Scan receipt'),
            ),
            const SizedBox(height: 18),
          ],
          TextField(
            key: const Key('demo-reference'),
            controller: _reference,
            enabled: !_busy,
            autocorrect: false,
            textCapitalization: widget.provider == 'cbe'
                ? TextCapitalization.none
                : TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Receipt reference',
              hintText: 'Reference or CBE receipt link',
            ),
          ),
          if (['cbe', 'abyssinia', 'cbebirr'].contains(widget.provider)) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _account,
              enabled: !_busy,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: widget.provider == 'cbebirr'
                    ? 'Receiving phone number'
                    : 'Receiving bank account',
                helperText: 'Use the destination shown on this receipt.',
                helperMaxLines: 2,
              ),
            ),
          ],
          const SizedBox(height: 18),
          const Text(
            'This checks the receipt with the provider. It does not confirm payment to a connected business.',
            style: TextStyle(fontSize: 12, height: 1.5),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            ErrorBanner(message: _error!),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy || _remaining == 0 ? null : () => _verify(),
            child: Text(_busy ? 'Checking receipt…' : 'Use 1 free check'),
          ),
          TextButton(
            onPressed: _busy ? null : () => _verify(statusOnly: true),
            child: const Text('Check last result · no extra check'),
          ),
          if (_result != null) ...[
            const SizedBox(height: 20),
            SuccessPop(
              child: GlassPanel(
                accent: AppColors.success,
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      AppIcons.verified,
                      color: AppColors.success,
                      size: 36,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Receipt verified',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '${_result!['amount']} ${_result!['currency']}',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    Text('Reference: ${_result!['reference']}'),
                    Text('Date: ${_result!['date']}'),
                    if (_result!['receiverName'] != null)
                      Text('Recipient: ${_result!['receiverName']}'),
                    if (_result!['receiverAccount'] != null)
                      Text('Account: ${_result!['receiverAccount']}'),
                    const SizedBox(height: 14),
                    const Text(
                      'Demo only · no business payment recorded.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
