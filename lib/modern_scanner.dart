import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'receipt_parser.dart';
import 'api_service.dart';

class ModernScannerScreen extends StatefulWidget {
  final String targetBank;
  final String targetEndpoint;

  const ModernScannerScreen({
    super.key,
    required this.targetBank,
    required this.targetEndpoint,
  });

  @override
  State<ModernScannerScreen> createState() => _ModernScannerScreenState();
}

class _ModernScannerScreenState extends State<ModernScannerScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  
  bool _isProcessingImage = false;
  bool _isCameraInitialized = false;
  bool _transactionFound = false;
  String? _extractedTransactionId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopCamera();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _stopCamera();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();
      
      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
      });

      _cameraController!.startImageStream(_processCameraImage);
    } catch (e) {
      debugPrint("Camera Initialization Error: $e");
    }
  }

  Future<void> _stopCamera() async {
    if (_cameraController != null) {
      if (_cameraController!.value.isStreamingImages) {
        await _cameraController!.stopImageStream();
      }
      await _cameraController!.dispose();
      _cameraController = null;
    }
    _isCameraInitialized = false;
  }

  void _processCameraImage(CameraImage image) async {
    if (_isProcessingImage || _transactionFound) return;
    _isProcessingImage = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) {
        _isProcessingImage = false;
        return;
      }

      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      // Pass the extracted raw text to your bulletproof parser
      final String? foundId = ReceiptParser.extractTransactionId(recognizedText.text, widget.targetBank);

      if (foundId != null && !_transactionFound) {
        _transactionFound = true;
        _extractedTransactionId = foundId;
        
        // Stop streaming to save battery and freeze the frame
        await _cameraController?.stopImageStream();
        
        final hasVibe = await Vibration.hasVibrator();
        if (hasVibe == true) Vibration.vibrate(pattern: [0, 50, 100, 50]);

        if (mounted) {
          _showAmountEntrySheet(_extractedTransactionId!);
        }
      }
    } catch (e) {
      debugPrint("OCR Processing Error: $e");
    } finally {
      _isProcessingImage = false;
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final camera = _cameraController!.description;
    final sensorOrientation = camera.sensorOrientation;
    
    InputImageRotation? rotation;
    if (sensorOrientation == 90) rotation = InputImageRotation.rotation90deg;
    else if (sensorOrientation == 180) rotation = InputImageRotation.rotation180deg;
    else if (sensorOrientation == 270) rotation = InputImageRotation.rotation270deg;
    else rotation = InputImageRotation.rotation0deg;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null || rotation == null) return null;

    if (image.planes.isEmpty) return null;

    return InputImage.fromBytes(
      bytes: image.planes[0].bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  void _showAmountEntrySheet(String transactionId) {
    final amountController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TRANSACTION FOUND',
                        style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12),
                      ).animate().fadeIn().slideX(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() {
                            _transactionFound = false;
                            _extractedTransactionId = null;
                          });
                          _cameraController?.startImageStream(_processCameraImage);
                        },
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFF020617), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF1E293B))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('BANK: ${widget.targetBank.toUpperCase()}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('ID: $transactionId', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: 'ENTER BILL AMOUNT (ETB)',
                      labelStyle: const TextStyle(color: Color(0xFF6366F1), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                      filled: true,
                      fillColor: const Color(0xFF020617),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      prefixIcon: const Icon(CupertinoIcons.money_dollar, color: Color(0xFF10B981)),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: isSubmitting
    ? null
    : () async {
        final amount = amountController.text.trim();
        if (amount.isEmpty) return;

        setSheetState(() => isSubmitting = true);
        
        try {
          // 1. Fetch the Admin's Official Bank Config from Supabase
          final bizData = await ApiService.streamCurrentBusiness().first;
          final accounts = bizData['bank_accounts'] ?? {};
          
          // 2. Verify with Leul's External API
          final result = await ApiService.verifyTransaction(transactionId, widget.targetEndpoint);
          
          if (result.isSuccess) {
            // Extract the normalized payload data
            final apiData = result.data?['data'] ?? result.data ?? {};
            
            final apiAmount = double.tryParse(apiData['amount']?.toString() ?? '0') ?? 0.0;
            final apiReceiverName = (apiData['receiverName'] ?? apiData['receiver_name'] ?? '').toString().toUpperCase();
            final apiReceiverAccount = (apiData['receiverAccount'] ?? apiData['receiver_account'] ?? '').toString();
            
            final enteredAmount = double.tryParse(amount) ?? 0.0;

            // --- SECURITY CHECK 1: Amount Match ---
            if (apiAmount != enteredAmount) {
              throw Exception("FRAUD ALERT: Scanned receipt is for $apiAmount ETB, but you entered $enteredAmount ETB.");
            }

            // --- SECURITY CHECK 2: Destination Match ---
            String expectedAccount = '';
            
            if (widget.targetBank.toLowerCase().contains('telebirr')) {
              expectedAccount = (accounts['telebirr_number'] ?? '').toString();
            } else if (widget.targetBank.toLowerCase().contains('cbe')) {
              expectedAccount = (accounts['cbe_number'] ?? '').toString();
            }

            // Only enforce if the Admin actually set up their bank config
            if (expectedAccount.isNotEmpty && !apiReceiverAccount.contains(expectedAccount)) {
                throw Exception("FRAUD ALERT: Money went to $apiReceiverAccount, not the official restaurant account ($expectedAccount).");
            }

            // 3. Log to Database if all security checks pass
            await ApiService.submitVerifiedTicket(
              transactionId: transactionId,
              amount: amount,
              bankName: widget.targetBank,
            );
            
            if (mounted) {
              Navigator.pop(context); // Close sheet
              Navigator.pop(context); // Go back to Waiter Dashboard
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Ticket Logged & Verified!'),
                backgroundColor: Color(0xFF10B981),
              ));
            }
          } else {
            throw Exception(result.errorMessage ?? "Invalid Transaction ID.");
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: const Color(0xFFEF4444),
              duration: const Duration(seconds: 4),
            ));
          }
        } finally {
          setSheetState(() => isSubmitting = false);
        }
      },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: isSubmitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('VERIFY & QUEUE TICKET', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. The Live Camera Feed
          if (_isCameraInitialized && _cameraController != null)
            Positioned.fill(
              child: CameraPreview(_cameraController!),
            )
          else
            const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))),

          // 2. The Targeting Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(CupertinoIcons.back, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF6366F1)),
                            ),
                            child: Text(
                              'SCANNING ${widget.targetBank.toUpperCase()}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.5),
                            ),
                          ).animate().fadeIn().shimmer(duration: 2000.ms, curve: Curves.easeInOut),
                        ],
                      ),
                    ),
                    const Spacer(),
                    
                    // The Viewfinder Box
                    Container(
                      width: MediaQuery.of(context).size.width * 0.85,
                      height: 180,
                      decoration: BoxDecoration(
                        border: Border.all(color: _transactionFound ? const Color(0xFF10B981) : const Color(0xFF6366F1), width: 3),
                        borderRadius: BorderRadius.circular(24),
                        color: Colors.transparent,
                        boxShadow: [
                          BoxShadow(
                            color: _transactionFound ? const Color(0xFF10B981).withValues(alpha: 0.3) : const Color(0xFF6366F1).withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          )
                        ]
                      ),
                      child: _transactionFound
                          ? const Center(child: Icon(Icons.check_circle, color: Color(0xFF10B981), size: 64)).animate().scale()
                          : null,
                    ),
                    
                    const SizedBox(height: 32),
                    const Text(
                      'ALIGN RECEIPT ID WITHIN FRAME',
                      style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 12),
                    ).animate(onPlay: (controller) => controller.repeat()).fadeIn(duration: 800.ms).then().fadeOut(duration: 800.ms),
                    const Spacer(flex: 2),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}