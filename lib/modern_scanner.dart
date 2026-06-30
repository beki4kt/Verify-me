import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:vibration/vibration.dart';
import 'main.dart'; 
import 'receipt_parser.dart';
import 'api_service.dart';
import 'offline_storage.dart';

class ModernScannerScreen extends StatefulWidget {
  final String targetBank;
  final String targetEndpoint;

  const ModernScannerScreen({
    super.key, 
    required this.targetBank, 
    required this.targetEndpoint
  });

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
    
    final designVibrator = await Vibration.hasVibrator();
    if (designVibrator == true) Vibration.vibrate(duration: 50);

    try {
      final XFile imageFile = await _cameraController!.takePicture();
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      ParsedReceipt parsedData = ReceiptParser.parse(
        recognizedText.text, 
        widget.targetBank, 
        widget.targetEndpoint
      );
      
      if (!mounted) return;
      setState(() => _isExtracting = false);
      _showVerificationSheet(parsedData);

    } catch (e) {
      if (!mounted) return;
      setState(() => _isExtracting = false);
    }
  }

  void _showSuccessDialog(Map<String, dynamic>? data, String transactionId) {
    final amount = data?['amount']?.toString() ?? 'Verified';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFF10B981), width: 2), 
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 64),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                const Text('PAYMENT SUCCESS', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 2)),
                const SizedBox(height: 16),
                
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFF020617), borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      _buildDetailRow('AMOUNT', amount, isHighlight: true),
                      const Divider(color: Color(0xFF1E293B), height: 24),
                      _buildDetailRow('ID', transactionId),
                      const Divider(color: Color(0xFF1E293B), height: 24),
                      _buildDetailRow('BANK', widget.targetBank),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); 
                      Navigator.pop(context); 
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('FINISH', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 2)),
                  ),
                )
              ],
            ),
          ),
        );
      }
    );
  }

  void _showOfflineSavedDialog(String transactionId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFFF59E0B), width: 2), 
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.wifi_off, color: Color(0xFFF59E0B), size: 48),
                ),
                const SizedBox(height: 24),
                const Text('SAVED LOCALLY', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 2)),
                const SizedBox(height: 8),
                const Text('Network error. Ticket queued for sync.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF64748B), fontSize: 14)),
                const SizedBox(height: 24),
                
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFF020617), borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      _buildDetailRow('ID', transactionId),
                      const Divider(color: Color(0xFF1E293B), height: 16),
                      _buildDetailRow('STATUS', 'Pending Sync', isHighlight: true),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); 
                      Navigator.pop(context); 
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('CONTINUE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 2)),
                  ),
                )
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
        Text(value, style: TextStyle(
          color: isHighlight ? (value == 'Pending Sync' ? const Color(0xFFF59E0B) : Colors.white) : const Color(0xFFCBD5E1), 
          fontSize: isHighlight ? 16 : 14, 
          fontWeight: isHighlight ? FontWeight.w900 : FontWeight.bold
        )),
      ],
    );
  }

  void _showVerificationSheet(ParsedReceipt parsedData) {
    TextEditingController idController = TextEditingController(text: parsedData.transactionId ?? "");
    bool isVerifying = false;
    String? errorText;

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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('CONFIRM PAYMENT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF6366F1), letterSpacing: 2)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
                        child: Text(widget.targetBank, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      )
                    ],
                  ),
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
                      decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
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
                      
                      VerificationResult result = await ApiService.verifyTransaction(idController.text.trim(), widget.targetEndpoint);
                      
                      if (!mounted) return;
                      
                      if (result.isSuccess) {
                         final verifyVib = await Vibration.hasVibrator();
                         if (verifyVib == true) Vibration.vibrate(pattern: [0, 100, 100, 100]);
                         Navigator.pop(context); 
                         _showSuccessDialog(result.data, idController.text.trim());
                      } else if (result.errorMessage != null && result.errorMessage!.contains('Network Error')) {
                         final saveVib = await Vibration.hasVibrator();
                         if (saveVib == true) Vibration.vibrate(duration: 150);
                         
                         final pendingTicket = PendingTicket(
                           transactionId: idController.text.trim(),
                           endpoint: widget.targetEndpoint,
                           timestamp: DateTime.now().millisecondsSinceEpoch,
                         );
                         await SyncManager.instance.enqueueTicket(pendingTicket);
                         
                         if (!mounted) return;
                         Navigator.pop(context); 
                         _showOfflineSavedDialog(idController.text.trim()); 
                      } else {
                         final failVib = await Vibration.hasVibrator();
                         if (failVib == true) Vibration.vibrate(duration: 500);
                         
                         setSheetState(() {
                            isVerifying = false;
                            errorText = result.errorMessage;
                         });
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

          Container(color: Colors.black.withValues(alpha: 0.7)), 
          
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
                      Text('SCANNING ${widget.targetBank.toUpperCase()}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2)),
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
                          Container(color: Colors.black.withValues(alpha: 0.01)), 
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
                                      BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.8), blurRadius: 20, spreadRadius: 5)
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
                          if (!_isExtracting) BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.5), blurRadius: 30, spreadRadius: 5)
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