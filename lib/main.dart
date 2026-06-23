import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'receipt_parser.dart';
import 'api_service.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint('Error initializing cameras: $e');
  }
  runApp(const VerifyMeApp());
}

class VerifyMeApp extends StatelessWidget {
  const VerifyMeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Verify Me Engine',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xff121212),
        primaryColor: Colors.blue,
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final List<Widget> _screens = [
    const ScannerScreen(),
    const EngineTestScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.document_scanner), label: 'Live Scanner'),
          BottomNavigationBarItem(icon: Icon(Icons.science), label: 'Engine Lab'),
        ],
      ),
    );
  }
}

// --- LIVE SCANNER UI ---
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  bool _isCameraActive = false;
  bool _isExtracting = false;
  CameraController? _cameraController;

  Future<void> _initializeCamera() async {
    if (cameras.isEmpty) return;
    _cameraController = CameraController(cameras[0], ResolutionPreset.high, enableAudio: false);
    
    try {
      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() => _isCameraActive = true);
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  void _stopCamera() {
    _cameraController?.dispose();
    setState(() {
      _isCameraActive = false;
      _cameraController = null;
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _captureAndExtract() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    setState(() => _isExtracting = true);

    try {
      // 1. Capture and Process Image
      final XFile imageFile = await _cameraController!.takePicture();
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      // 2. Parse Text
      ParsedReceipt parsedData = ReceiptParser.parse(recognizedText.text);
      
      setState(() => _isExtracting = false);

      // 3. Open Editing Sheet (Even if ID is null, let user type it)
      _showVerificationSheet(parsedData.transactionId ?? "");

    } catch (e) {
      setState(() => _isExtracting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showVerificationSheet(String initialId) {
    TextEditingController idController = TextEditingController(text: initialId);
    bool isVerifying = false;
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: Colors.blueAccent, width: 2),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24, // Push up when keyboard opens
                left: 24, right: 24, top: 24
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Confirm Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 8),
                  const Text('OCR sometimes misreads characters (like S instead of 5). Please tap the box below to correct the ID if needed.', style: TextStyle(color: Colors.grey, fontSize: 14)),
                  const SizedBox(height: 16),
                  
                  // Editable Text Field
                  TextField(
                    controller: idController,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.black54,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      labelText: 'Transaction ID',
                      labelStyle: const TextStyle(color: Colors.blueAccent),
                    ),
                  ),
                  
                  if (errorText != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                      child: Text(errorText!, style: const TextStyle(color: Colors.redAccent)),
                    )
                  ],
                  
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: isVerifying ? null : () async {
                      if (idController.text.isEmpty) return;
                      
                      setSheetState(() {
                        isVerifying = true;
                        errorText = null;
                      });
                      
                      // Hit the API
                      VerificationResult result = await ApiService.verifyTransaction(idController.text.trim());
                      
                      if (result.isSuccess) {
                         if (!mounted) return;
                         Navigator.pop(context); // Close sheet
                         ScaffoldMessenger.of(context).showSnackBar(
                           const SnackBar(content: Text('Transaction Verified Successfully!', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green)
                         );
                      } else {
                         setSheetState(() {
                            isVerifying = false;
                            errorText = result.errorMessage;
                         });
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: isVerifying 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('VERIFY NOW', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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
      appBar: AppBar(
        title: const Text('Live Scanner'),
        actions: [
          if (_isCameraActive)
            IconButton(icon: const Icon(Icons.close, color: Colors.redAccent), onPressed: _stopCamera)
        ],
      ),
      body: Stack(
        children: [
          if (!_isCameraActive)
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.power_settings_new),
                label: const Text('START SCANNER'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
                onPressed: _initializeCamera,
              ),
            )
          else if (_cameraController != null && _cameraController!.value.isInitialized)
            SizedBox.expand(child: CameraPreview(_cameraController!)),
          
          if (_isCameraActive && _cameraController != null && _cameraController!.value.isInitialized)
            Positioned(
              bottom: 40, left: 0, right: 0,
              child: Center(
                child: _isExtracting 
                  ? const CircularProgressIndicator(color: Colors.blueAccent)
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.document_scanner),
                      onPressed: _captureAndExtract,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16)),
                      label: const Text('CAPTURE RECEIPT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

// --- ORIGINAL ENGINE LAB ---
class EngineTestScreen extends StatefulWidget {
  const EngineTestScreen({super.key});
  @override
  State<EngineTestScreen> createState() => _EngineTestScreenState();
}
class _EngineTestScreenState extends State<EngineTestScreen> {
  final TextEditingController _textController = TextEditingController();
  ParsedReceipt? _result;

  void _runParser() => setState(() => _result = ReceiptParser.parse(_textController.text));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verification Engine Lab')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: _textController, maxLines: 5, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Enter raw text...'), onChanged: (_) => _runParser()),
            const SizedBox(height: 24),
            if (_result != null)
              Card(
                color: _result!.isValid ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text('Extracted ID: ${_result!.transactionId ?? 'Not Found'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}