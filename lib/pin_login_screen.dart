import 'package:flutter/material.dart';
import 'api_service.dart';
import 'admin_dashboard.dart';
import 'waiter_dashboard.dart'; 
import 'cashier_dashboard.dart'; 

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
      // Use Henok's new SaaS Session Manager
      final sessionData = await ApiService.loginWithPin(code);

      if (sessionData == null) {
        setState(() => _errorMessage = "Invalid Access Code or Inactive Account.");
        return;
      }

      if (!mounted) return;

      // Auto-route based on the database role
      final role = ApiService.currentUserRole;

      if (role == 'admin') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminDashboard()));
      } else if (role == 'cashier') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CashierDashboard()));
      } else if (role == 'waiter') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const WaiterDashboard()));
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
      backgroundColor: const Color(0xFF020617), 
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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

              if (_errorMessage != null) ...[
                Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
              ],

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