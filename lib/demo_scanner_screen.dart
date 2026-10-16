import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'core/services/demo_verification_client.dart';
import 'core/config/app_variant.dart';
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
  bool _loadingUsage = true;
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loadingUsage = true;
      _error = null;
    });
    try {
      final state = await _client.usage();
      if (mounted) {
        setState(() {
          _remaining = (state['remaining'] as num?)?.toInt();
          _error = state['error']?.toString();
          _loadingUsage = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _remaining = null;
          _loadingUsage = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
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
                  Text(
                    'Payment method',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _loadingUsage
                        ? 'Checking demo availability…'
                        : _error != null
                        ? 'Demo checks unavailable'
                        : '$_remaining free checks left',
                    key: const Key('demo-remaining'),
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(color: AppColors.aqua),
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
            const Text('Free checks used.'),
          ],
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, bounds) {
              final methods = AppVariant.enabledPaymentProviders;
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
                              : () => _open(methods[i].id, methods[i].label),
                          padding: const EdgeInsets.all(18),
                          accent: AppColors.bank(methods[i].label),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              PaymentLogo(provider: methods[i].label, size: 42),
                              const SizedBox(height: 14),
                              Text(
                                methods[i].label,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 10),
                              const Align(
                                alignment: Alignment.centerRight,
                                child: Icon(AppIcons.forward, size: 17),
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

class _DemoReceiptScreenState extends State<_DemoReceiptScreen> {
  final _reference = TextEditingController(),
      _account = TextEditingController();
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _result;
  late int? _remaining = widget.remaining;
  bool get _nativeCamera =>
      !widget.manualOnly &&
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);
  @override
  void dispose() {
    _reference.dispose();
    _account.dispose();
    super.dispose();
  }

  Future<void> _openCamera() async {
    final reference = await Navigator.of(context).push<String>(
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            _DemoCameraScreen(provider: widget.provider, label: widget.label),
      ),
    );
    if (!mounted || reference == null) return;
    setState(() {
      _reference.text = reference;
      _error = null;
    });
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
          Text(
            _remaining == null
                ? 'Demo availability unknown'
                : '$_remaining checks left',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          if (_nativeCamera) ...[
            OutlinedButton.icon(
              onPressed: _busy ? null : _openCamera,
              icon: const Icon(AppIcons.scanReceipt),
              label: const Text('Open camera to scan receipt'),
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
              ),
            ),
          ],
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
            child: const Text('Last result'),
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

class _DemoCameraScreen extends StatefulWidget {
  const _DemoCameraScreen({required this.provider, required this.label});

  final String provider;
  final String label;

  @override
  State<_DemoCameraScreen> createState() => _DemoCameraScreenState();
}

class _DemoCameraScreenState extends State<_DemoCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _camera;
  int _cameraGeneration = 0;
  bool _capturing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCamera();
  }

  Future<void> _stopCamera() async {
    _cameraGeneration++;
    final camera = _camera;
    _camera = null;
    try {
      await camera?.dispose();
    } catch (_) {
      // The camera may already have been released by the operating system.
    }
  }

  Future<void> _startCamera() async {
    final generation = ++_cameraGeneration;
    try {
      final cameras = await availableCameras();
      if (!mounted || generation != _cameraGeneration) return;
      if (cameras.isEmpty) throw Exception('No camera available');
      final camera = CameraController(
        cameras.firstWhere(
          (item) => item.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first,
        ),
        ResolutionPreset.high,
        enableAudio: false,
      );
      _camera = camera;
      await camera.initialize();
      if (!mounted || generation != _cameraGeneration) return;
      setState(() => _error = null);
    } catch (_) {
      if (mounted && generation == _cameraGeneration) {
        unawaited(_stopCamera());
        setState(
          () => _error = 'Camera access is unavailable. Enable camera permission or enter the reference manually.',
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      unawaited(_stopCamera());
    } else if (state == AppLifecycleState.resumed && _camera == null) {
      unawaited(_startCamera());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_stopCamera());
    super.dispose();
  }

  Future<void> _capture() async {
    if (_capturing || _camera?.value.isInitialized != true) return;
    setState(() {
      _capturing = true;
      _error = null;
    });
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
      if (reference == null) {
        setState(
          () => _error = 'Could not read the reference. Try another photo or enter it manually.',
        );
      } else {
        Navigator.of(context).pop(reference);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not read this photo. Try again or enter the reference manually.',
        );
      }
    } finally {
      await recognizer.close();
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    final ready = camera?.value.isInitialized == true;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (ready)
            Positioned.fill(
              child: ClipRect(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: camera!.value.previewSize?.height ?? 1,
                    height: camera.value.previewSize?.width ?? 1,
                    child: CameraPreview(camera),
                  ),
                ),
              ),
            )
          else if (_error == null)
            const Center(child: CircularProgressIndicator()),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: .65),
                      Colors.transparent,
                      Colors.black.withValues(alpha: .76),
                    ],
                    stops: const [0, .36, 1],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton.filledTonal(
                        tooltip: 'Close camera',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(AppIcons.back),
                      ),
                      const SizedBox(width: 12),
                      PaymentLogo(provider: widget.label, size: 34),
                      const SizedBox(width: 10),
                      Text(
                        '${widget.label} receipt',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Text(
                        _capturing
                            ? 'Reading receipt…'
                            : 'Fill the view with the receipt',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  Semantics(
                    label: 'Capture receipt',
                    button: true,
                    enabled: ready && !_capturing,
                    child: Pressable(
                      enabled: ready && !_capturing,
                      onTap: _capture,
                      pressedScale: .9,
                      child: Container(
                        width: 82,
                        height: 82,
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: _capturing
                              ? const Padding(
                                  padding: EdgeInsets.all(18),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Enter reference manually'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
