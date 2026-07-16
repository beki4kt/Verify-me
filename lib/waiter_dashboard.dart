import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'api_service.dart';
import 'receipt_parser.dart';
import 'staff_login_screen.dart'; 

class WaiterDashboard extends StatefulWidget {
  const WaiterDashboard({super.key});

  @override
  State<WaiterDashboard> createState() => _WaiterDashboardState();
}

class _WaiterDashboardState extends State<WaiterDashboard> {
  late Stream<List<Map<String, dynamic>>> _myTicketsStream;
  
  // Camera Variables
  CameraController? _cameraController;
  List<CameraDescription>? _availableCameras;
  bool _isCameraInitialized = false;
  bool _isExtracting = false;

  @override
  void initState() {
    super.initState();
    _myTicketsStream = ApiService.streamWaiterTickets();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
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
          setState(() => _isCameraInitialized = true);
        }
      }
    } catch (e) {
      debugPrint('Camera Initialization Error: $e');
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
          return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
        }
        
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text('No active tickets. Swipe to scan a receipt.', style: TextStyle(color: Color(0xFF64748B), fontSize: 14)),
          );
        }

        final activeTickets = snapshot.data!.where((t) => t['status'] != 'rejected').toList();

        if (activeTickets.isEmpty) {
          return const Center(
            child: Text('No active tickets.', style: TextStyle(color: Color(0xFF64748B), fontSize: 14)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: activeTickets.length,
          itemBuilder: (context, index) {
            final ticket = activeTickets[index];
            final isSettled = ticket['status'] == 'settled';
            final statusColor = isSettled ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isSettled ? const Color(0xFF10B981).withValues(alpha: 0.3) : Colors.white10),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: Icon(isSettled ? Icons.check_circle : Icons.hourglass_empty, color: statusColor, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${ticket['bill_amount']} ETB', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text('REF: ${ticket['transaction_ref']}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFF020617), borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      ticket['status'].toString().toUpperCase(),
                      style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: (20 * index).ms).slideX(begin: 0.1, end: 0);
          },
        );
      },
    );
  }

  // --- TAB 2: THE LIVE SCANNER ---
  Widget _buildScannerTab() {
    if (!_isCameraInitialized || _cameraController == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF6366F1)),
            SizedBox(height: 16),
            Text('Initializing Optical Engine...', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, letterSpacing: 1)),
          ],
        ),
      );
    }

    return Stack(
      children: [
        SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _cameraController!.value.previewSize?.height ?? 1,
              height: _cameraController!.value.previewSize?.width ?? 1,
              child: CameraPreview(_cameraController!),
            ),
          ),
        ),
        
        Center(
          child: Container(
            width: 250, height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.5), width: 2),
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),

        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0xFF020617), Colors.transparent]),
            ),
            child: ElevatedButton(
              onPressed: _isExtracting ? null : _captureAndExtract,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1), padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: _isExtracting
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.document_scanner, color: Colors.white),
                        SizedBox(width: 12),
                        Text('SCAN RECEIPT', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  // --- SCANNER EXECUTION & EXTRACTION ---
  Future<void> _captureAndExtract() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    setState(() => _isExtracting = true);

    try {
      final XFile imageFile = await _cameraController!.takePicture();
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      String? extractedId = ReceiptParser.extractTransactionId(recognizedText.text, 'Universal / Unknown');
      
      setState(() => _isExtracting = false);
      
      if (!mounted) return;
      _showSubmissionSheet(extractedId);

    } catch (e) {
      setState(() => _isExtracting = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scanner Error: $e')));
    }
  }

  // --- TICKET SUBMISSION SHEET ---
  void _showSubmissionSheet(String? initialTransactionId) {
    final refController = TextEditingController(text: initialTransactionId ?? '');
    final billController = TextEditingController(); 
    String selectedBank = 'Telebirr';
    bool isSubmitting = false;
    String? errorText;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24, left: 24, right: 24, top: 32),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('SUBMIT TICKET', style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12)),
                    const SizedBox(height: 24),
                    
                    DropdownButtonFormField<String>(
                      initialValue: selectedBank, dropdownColor: const Color(0xFF020617),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      decoration: _buildInputDecoration('SELECT BANK', Icons.account_balance),
                      items: const [
                        DropdownMenuItem(value: 'Telebirr', child: Text('Telebirr')),
                        DropdownMenuItem(value: 'CBE', child: Text('CBE / CBE Birr')),
                        DropdownMenuItem(value: 'Dashen', child: Text('Dashen Bank')),
                      ],
                      onChanged: (val) => setSheetState(() => selectedBank = val!),
                    ),
                    const SizedBox(height: 16),
                    
                    TextField(
                      controller: refController,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                      decoration: _buildInputDecoration('TRANSACTION REF', Icons.receipt),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: billController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                      style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 20),
                      decoration: _buildInputDecoration('EXPECTED BILL AMOUNT (ETB)', Icons.payments).copyWith(
                        filled: true, fillColor: const Color(0xFF10B981).withValues(alpha: 0.1),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Any transferred amount exceeding this expected bill will be classified as a tip by the cashier.', style: TextStyle(color: Color(0xFF64748B), fontSize: 10)),
                    const SizedBox(height: 24),

                    if (errorText != null)
                      Container(
                        padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text(errorText!, style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),

                    ElevatedButton(
                      onPressed: isSubmitting ? null : () async {
                        if (refController.text.isEmpty || billController.text.isEmpty) {
                          setSheetState(() => errorText = 'Please provide both the Transaction Ref and the Bill Amount.');
                          return;
                        }

                        setSheetState(() { isSubmitting = true; errorText = null; });
                        try {
                          await ApiService.submitVerifiedTicket(
                            transactionId: refController.text.trim().toUpperCase(),
                            bankName: selectedBank,
                            amount: billController.text.trim(), // FIXED: Passes as String directly
                          );
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          setSheetState(() => errorText = e.toString().replaceAll('Exception: ', ''));
                        } finally {
                          setSheetState(() => isSubmitting = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      child: isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('SUBMIT TICKET', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    )
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
    return InputDecoration(
      labelText: label, labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
      prefixIcon: Icon(icon, color: const Color(0xFF6366F1)), 
      filled: true, fillColor: const Color(0xFF020617),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF020617),
        appBar: AppBar(
          backgroundColor: const Color(0xFF020617), elevation: 0,
          title: const Text('FLOOR DASHBOARD', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 2)).animate().fadeIn(),
          leading: IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () {
              ApiService.currentStaffNumber = null;
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const StaffLoginScreen()));
            }
          ),
          bottom: const TabBar(
            indicatorColor: Color(0xFF6366F1),
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 11),
            unselectedLabelColor: Color(0xFF64748B),
            labelColor: Colors.white,
            tabs: [
              Tab(text: 'ACTIVE TICKETS'),
              Tab(text: 'LIVE SCANNER'),
            ],
          ),
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(), 
          children: [
            _buildTicketFeed(),
            _buildScannerTab(),
          ],
        ),
      ),
    );
  }
}