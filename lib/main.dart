import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'receipt_parser.dart'; // Restored to power the Engine Test Lab
import 'offline_storage.dart';
import 'localization_service.dart';
import 'business_gateway_screen.dart';
import 'staff_login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase Connection
  await Supabase.initialize(
    url: 'https://lpbdxtzyzlaioggefscc.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxwYmR4dHp5emxhaW9nZ2Vmc2NjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIyOTMyMDUsImV4cCI6MjA5Nzg2OTIwNX0.X9d4_FkisQRQXYFhyVJ_-5XSsbkS1VCHMLLybfGfpzs',
  );

  // Spin up the local Hive engine and automatic background sync loops
  await SyncManager.initialize();
  SyncManager.instance.startBackgroundSync();

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
    // Dynamic Root Routing: Instantly look up device configuration lock state
    final lockedBiz = DeviceStorage.getLockedBusiness();
    final Widget initialScreen = lockedBiz['id'] != null 
        ? const StaffLoginScreen() 
        : const BusinessGatewayScreen();

    return MaterialApp(
      title: 'Verify-Me',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF6366F1), 
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        fontFamily: 'Roboto',
      ),
      home: initialScreen,
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

class ScannerScreen extends StatelessWidget {
  const ScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Live Camera Module Migrated to Modern Scanner Screen.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.bold),
        ),
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
            TextField(
              controller: _textController, 
              maxLines: 5, 
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Enter raw text...'), 
              onChanged: (_) => _runParser(),
            ),
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