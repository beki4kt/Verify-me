import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'receipt_parser.dart';
import 'api_service.dart';
import 'offline_storage.dart';
import 'localization_service.dart';
import 'dual_login_screen.dart'; // The new secure gateway

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://lpbdxtzyzlaioggefscc.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxwYmR4dHp5emxhaW9nZ2Vmc2NjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIyOTMyMDUsImV4cCI6MjA5Nzg2OTIwNX0.X9d4_FkisQRQXYFhyVJ_-5XSsbkS1VCHMLLybfGfpzs',
  );

  await SyncManager.initialize();
  SyncManager.instance.startBackgroundSync();

  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint('Error initializing cameras: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocalizationService()),
      ],
      child: const VerifyMeApp(),
    ),
  );
}

class VerifyMeApp extends StatelessWidget {
  const VerifyMeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Verify-Me',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF6366F1), 
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        fontFamily: 'Roboto',
      ),
      home: const DualLoginScreen(), // Boots straight to firewall
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
      final XFile imageFile = await _cameraController!.takePicture();
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      //  NEW CORRECTED CODE
      String? extractedId = ReceiptParser.extractTransactionId(recognizedText.text, 'Universal / Unknown');
      
      setState(() => _isExtracting = false);
      if (!mounted) return;
      _showVerificationSheet(extractedId);

    } catch (e) {
      setState(() => _isExtracting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showVerificationSheet(String? transactionId) {
    TextEditingController idController = TextEditingController(text: transactionId ?? "");
    String selectedEndpoint = '/verify-telebirr'; // Default fallback
    bool isVerifying = false;
    String? errorText;

    final Map<String, String> bankEndpoints = {
      'Telebirr': '/verify-telebirr',
      'CBE (Mobile Banking)': '/verify-cbe',
      'CBE Birr': '/verify-cbebirr',
      'Dashen': '/verify-dashen',
      'Bank of Abyssinia': '/verify-abyssinia',
      'M-Pesa': '/verify-mpesa',
      'Universal / Unknown': '/verify',
    };

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
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 24, right: 24, top: 24
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Confirm Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 16),
                  
                  const Text('Detected Payment Method:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    value: selectedEndpoint,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.black54,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    dropdownColor: const Color(0xFF2C2C2C),
                    items: bankEndpoints.entries.map((entry) {
                      return DropdownMenuItem<String>(
                        value: entry.value,
                        child: Text(entry.key, style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setSheetState(() => selectedEndpoint = newValue);
                      }
                    },
                  ),
                  
                  const SizedBox(height: 16),

                  const Text('Detected Transaction ID:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: idController,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.black54,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                      
                      VerificationResult result = await ApiService.verifyTransaction(
                        idController.text.trim(), 
                        selectedEndpoint 
                      );
                      
                      if (!mounted) return;
                      
                      if (result.isSuccess) {
                         Navigator.pop(context);
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

class EngineTestScreen extends StatefulWidget {
  const EngineTestScreen({super.key});
  @override
  State<EngineTestScreen> createState() => _EngineTestScreenState();
}
class _EngineTestScreenState extends State<EngineTestScreen> {
  final TextEditingController _textController = TextEditingController();
  
  //  NEW CORRECTED CODE
  String? _result;

  void _runParser() => setState(() => _result = ReceiptParser.extractTransactionId(_textController.text, 'Universal / Unknown'));

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
                color: Colors.green.withValues(alpha: 0.15),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text('Extracted ID: $_result', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
              )
            else if (_textController.text.isNotEmpty)
               Card(
                color: Colors.red.withValues(alpha: 0.15),
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text('Extracted ID: Not Found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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