import 'package:flutter/material.dart';
import 'api_service.dart';
import 'admin_dashboard.dart';
import 'waiter_dashboard.dart'; 
import 'cashier_dashboard.dart';
import 'super_admin_dashboard.dart'; // We will build this next

class DualLoginScreen extends StatefulWidget {
  const DualLoginScreen({super.key});

  @override
  State<DualLoginScreen> createState() => _DualLoginScreenState();
}

class _DualLoginScreenState extends State<DualLoginScreen> {
  bool _isPinMode = true; // Toggles between Face A and Face B
  bool _isLoading = false;
  String? _errorMessage;

  final _pinController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  Future<void> _handlePinLogin() async {
    if (_pinController.text.isEmpty) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final sessionData = await ApiService.loginWithPin(_pinController.text.trim());
      if (sessionData == null) {
        setState(() => _errorMessage = "Invalid Access Code or Inactive Account.");
        return;
      }
      _routeUser(ApiService.currentUserRole!);
    } catch (e) {
      setState(() => _errorMessage = "Connection Error.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePhoneLogin() async {
    if (_phoneController.text.isEmpty || _passwordController.text.isEmpty) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final role = await ApiService.loginWithPhone(
        _phoneController.text.trim(), 
        _passwordController.text.trim()
      );

      if (role == null) {
        setState(() => _errorMessage = "Invalid Credentials.");
        return;
      }
      _routeUser(role);
    } catch (e) {
      setState(() => _errorMessage = "Connection Error.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _routeUser(String role) {
    if (!mounted) return;
    Widget destination;
    
    switch (role) {
      case 'super_admin': destination = const SuperAdminDashboard(); break;
      case 'admin': destination = const AdminDashboard(); break;
      case 'cashier': destination = const CashierDashboard(); break;
      case 'waiter': destination = const WaiterDashboard(); break;
      default: return;
    }
    
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => destination));
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
              const Text('VERIFY-ME', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 4)),
              const SizedBox(height: 48),

              if (_errorMessage != null) ...[
                Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
              ],

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _isPinMode ? _buildPinForm() : _buildPhoneForm(),
              ),

              const SizedBox(height: 32),
              
              TextButton(
                onPressed: () {
                  setState(() {
                    _isPinMode = !_isPinMode;
                    _errorMessage = null;
                  });
                },
                child: Text(
                  _isPinMode ? 'Secure Admin Login' : 'Switch to Staff PIN',
                  style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinForm() {
    return Column(
      key: const ValueKey('pin'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('ENTER FLOOR ACCESS CODE', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
        const SizedBox(height: 16),
        TextField(
          controller: _pinController,
          obscureText: true,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
          decoration: _inputDecoration(),
          onSubmitted: (_) => _handlePinLogin(),
        ),
        const SizedBox(height: 24),
        _buildSubmitButton('ACCESS TERMINAL', _handlePinLogin),
      ],
    );
  }

  Widget _buildPhoneForm() {
    return Column(
      key: const ValueKey('phone'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('MANAGEMENT PORTAL', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
        const SizedBox(height: 16),
        TextField(
          controller: _phoneController,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration().copyWith(hintText: 'Phone Number', hintStyle: const TextStyle(color: Colors.white30)),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          obscureText: true,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration().copyWith(hintText: 'Password', hintStyle: const TextStyle(color: Colors.white30)),
          onSubmitted: (_) => _handlePhoneLogin(),
        ),
        const SizedBox(height: 24),
        _buildSubmitButton('SECURE LOGIN', _handlePhoneLogin),
      ],
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFF0F172A),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
    );
  }

  Widget _buildSubmitButton(String label, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: _isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF6366F1),
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: _isLoading 
          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
    );
  }
}