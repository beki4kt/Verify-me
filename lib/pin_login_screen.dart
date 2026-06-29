import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_dashboard.dart';
// Note: Bereket will create these two later, we just need placeholders for the router
// import 'waiter_dashboard.dart'; 
// import 'cashier_dashboard.dart'; 

class PinLoginScreen extends StatefulWidget {
  const PinLoginScreen({super.key});

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _authenticate() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Query the database for this specific access code
      final response = await Supabase.instance.client
          .from('staff')
          .select()
          .eq('staff_number', code)
          .maybeSingle();

      if (response == null) {
        setState(() => _errorMessage = "Invalid Access Code");
        return;
      }

      if (response['is_active'] == false) {
        setState(() => _errorMessage = "This account has been deactivated.");
        return;
      }

      // 2. The "UX Magic Trick": Auto-route based on the database role
      final role = response['role'] as String;
      
      if (!mounted) return;

      if (role == 'admin') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminDashboard()));
      } else if (role == 'cashier') {
        // Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CashierDashboard()));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cashier UI pending...')));
      } else if (role == 'waiter') {
        // Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const WaiterDashboard()));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Waiter UI pending...')));
      }

    } catch (e) {
      setState(() => _errorMessage = "Connection Error. Try again.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617), // Deep OLED Black
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Branding / Logo Area
              const Icon(Icons.verified_user_rounded, size: 80, color: Color(0xFF6366F1)),
              const SizedBox(height: 24),
              const Text(
                'VERIFY-ME',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 4),
              ),
              const SizedBox(height: 8),
              const Text(
                'ENTER YOUR ACCESS CODE',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
              const SizedBox(height: 48),

              // Error Message
              if (_errorMessage != null) ...[
                Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
              ],

              // Input Field
              TextField(
                controller: _codeController,
                obscureText: true,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 24),
                ),
                onSubmitted: (_) => _authenticate(),
              ),
              const SizedBox(height: 32),

              // Login Button
              ElevatedButton(
                onPressed: _isLoading ? null : _authenticate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('SECURE LOGIN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}