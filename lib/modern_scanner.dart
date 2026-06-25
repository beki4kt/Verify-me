import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:lottie/lottie.dart';
import 'package:vibration/vibration.dart';
import 'main.dart'; 
import 'receipt_parser.dart';
import 'api_service.dart';

class ModernScannerScreen extends StatefulWidget {
  const ModernScannerScreen({super.key});

  @override
  State<ModernScannerScreen> createState() => _ModernScannerScreenState();
}

class _ModernScannerScreenState extends State<ModernScannerScreen> with SingleTickerProviderStateMixin {
  bool _isExtracting = false;
  CameraController? _cameraController;
  
  late AnimationController _laserController;
  late Animation<double> _laserAnimation;
  final double _cutoutHeight = 350.0;
  final double _cutoutWidth = 300.0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();

    _laserController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _laserAnimation = Tween<double>(begin: 0, end: _cutoutHeight - 4).animate(
      CurvedAnimation(parent: _laserController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initializeCamera() async {
    if (cameras.isEmpty) return;
    _cameraController = CameraController(cameras[0], ResolutionPreset.high, enableAudio: false);
    try {
      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() {}); 
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _laserController.dispose();
    super.dispose();
  }

  Future<void> _captureAndExtract() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    setState(() => _isExtracting = true);
    
    // Light Haptic tap when they hit the button
    if (await Vibration.hasVibrator() ?? false) Vibration.vibrate(duration: 50);

    try {
      final XFile imageFile = await _cameraController!.takePicture();
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      ParsedReceipt parsedData = ReceiptParser.parse(recognizedText.text);
      setState(() => _isExtracting = false);
      _showVerificationSheet(parsedData);

    } catch (e) {
      setState(() => _isExtracting = false);
    }
  }

  void _showResultAnimation(bool isSuccess, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (context) {
        // Auto-dismiss after 2.5 seconds
        Future.delayed(const Duration(milliseconds: 2500), () {
          if (mounted) {
            Navigator.pop(context); // Close animation
            if (isSuccess) Navigator.pop(context); // Return to dashboard only if success
          }
        });

        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.network(
                isSuccess 
                  ? 'https://lottie.host/8e209827-0205-4f46-8dd3-1456a00df890/ZlKjL9tH1F.json' // Success Checkmark
                  : 'https://lottie.host/7f7e915b-188d-4a11-8e54-3e9a5944d180/gL4t16QvB3.json', // Error Cross
                width: 200,
                height: 200,
                repeat: false,
              ),
              const SizedBox(height: 16),
              Material(
                color: Colors.transparent,
                child: Text(
                  message.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2
                  ),
                ),
              )
            ],
          ),
        );
      }
    );
  }

  void _showVerificationSheet(ParsedReceipt parsedData) {
    TextEditingController idController = TextEditingController(text: parsedData.transactionId ?? "");
    String selectedEndpoint = parsedData.endpoint ?? '/verify-telebirr';
    bool isVerifying = false;
    String? errorText;

    final Map<String, String> bankEndpoints = {
      'Telebirr': '/verify-telebirr',
      'CBE': '/verify-cbe',
      'Universal': '/verify',
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A), 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(40))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24, left: 24, right: 24, top: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('CONFIRM PAYMENT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF6366F1), letterSpacing: 2)),
                  const SizedBox(height: 24),
                  
                  TextField(
                    controller: idController,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 4),
                    decoration: InputDecoration(
                      labelText: 'TRANSACTION ID',
                      labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12, letterSpacing: 2),
                      filled: true,
                      fillColor: const Color(0xFF020617),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    ),
                  ),
                  
                  if (errorText != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFFEF4444).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                      child: Text(errorText!, style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                    )
                  ],
                  
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: isVerifying ? null : () async {
                      if (idController.text.isEmpty) return;
                      
                      setSheetState(() {
                        isVerifying = true;
                        errorText = null;
                      });
                      
                      VerificationResult result = await ApiService.verifyTransaction(idController.text.trim(), selectedEndpoint);
                      
                      if (result.isSuccess) {
                         // Haptic Resolution: Double pulse for success
                         if (await Vibration.hasVibrator() ?? false) {
                           Vibration.vibrate(pattern: [0, 100, 100, 100]);
                         }
                         if (!mounted) return;
                         Navigator.pop(context); // Close sheet
                         _showResultAnimation(true, "Payment Verified");
                      } else {
                         // Haptic Resolution: Harsh long vibration for failure
                         if (await Vibration.hasVibrator() ?? false) {
                           Vibration.vibrate(duration: 500, amplitudes: [255]);
                         }
                         setSheetState(() {
                            isVerifying = false;
                            errorText = result.errorMessage;
                         });
                         // Optional: Show giant red cross Lottie on failure
                         // _showResultAnimation(false, "Verification Failed"); 
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981), 
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                    ),
                    child: isVerifying 
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                      : const Text('VERIFY NOW', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 2)),
                  )
                ],
              )
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Hero(
            tag: 'scanner_hero_core',
            child: Container(width: double.infinity, height: double.infinity, color: const Color(0xFF0F172A)),
          ),
          
          if (_cameraController != null && _cameraController!.value.isInitialized)
            SizedBox.expand(child: CameraPreview(_cameraController!)),

          Container(color: Colors.black.withOpacity(0.7)), 
          
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 32),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text('ALIGN RECEIPT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 4)),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                Center(
                  child: Container(
                    width: _cutoutWidth,
                    height: _cutoutHeight,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF6366F1), width: 4),
                      borderRadius: BorderRadius.circular(32),
                      color: Colors.transparent, 
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Stack(
                        children: [
                          Container(color: Colors.black.withOpacity(0.01)), 
                          AnimatedBuilder(
                            animation: _laserAnimation,
                            builder: (context, child) {
                              return Positioned(
                                top: _laserAnimation.value,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1),
                                    boxShadow: [
                                      BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.8), blurRadius: 20, spreadRadius: 5)
                                    ]
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const Spacer(),
                
                Padding(
                  padding: const EdgeInsets.only(bottom: 48.0),
                  child: GestureDetector(
                    onTap: _isExtracting ? null : _captureAndExtract,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isExtracting ? const Color(0xFF1E293B) : const Color(0xFF6366F1),
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          if (!_isExtracting) BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.5), blurRadius: 30, spreadRadius: 5)
                        ]
                      ),
                      child: _isExtracting 
                        ? const Padding(padding: EdgeInsets.all(28.0), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 4))
                        : const Icon(Icons.camera_alt, color: Colors.white, size: 40),
                    ),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}