import 'package:flutter/material.dart';
import 'receipt_parser.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      home: const EngineTestScreen(),
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
  ParsedReceipt? _result;

  // Mock text mimicking a real transaction screenshot extraction log
  final String sampleReceiptText = 
      "Transaction Successful!\n"
      "Ref ID: AT498273641A\n"
      "Amount Paid: 2,500.00 ETB\n"
      "Date: 16-06-2026\n"
      "Status: Completed";

  void _runParser() {
    setState(() {
      _result = ReceiptParser.parse(_textController.text);
    });
  }

  @override
  void initState() {
    super.initState();
    _textController.text = sampleReceiptText;
    _runParser();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verification Engine Lab')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Paste Raw Scanned Text Here:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _textController,
              maxLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter text strings...',
              ),
              onChanged: (_) => _runParser(),
            ),
            const SizedBox(height: 24),
            const Text(
              'Engine Extraction Output:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            if (_result != null) ...[
              Card(
                color: _result!.isValid ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: _result!.isValid ? Colors.green : Colors.red),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildResultRow('Status', _result!.isValid ? 'VALID TRANSACTION' : 'INVALID / INCOMPLETE', isBold: true),
                      const Divider(),
                      _buildResultRow('Transaction ID', _result!.transactionId ?? 'Not Found'),
                      _buildResultRow('Amount (ETB)', _result!.amount != null ? '${_result!.amount}' : 'Not Found'),
                      _buildResultRow('Timestamp', _result!.date ?? 'Not Found'),
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

  Widget _buildResultRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}