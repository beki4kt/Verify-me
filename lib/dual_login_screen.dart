import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'localization_service.dart';
import 'api_service.dart';
import 'admin_dashboard.dart';
import 'waiter_dashboard.dart'; 
import 'cashier_dashboard.dart';
import 'super_admin_dashboard.dart'; 

class DualLoginScreen extends StatefulWidget {
  const DualLoginScreen({super.key});

  @override
  State<DualLoginScreen> createState() => _DualLoginScreenState();
}

class _DualLoginScreenState extends State<DualLoginScreen> {
  bool _isStaffMode = true; // The Double Face Toggle is back
  bool _isLoading = false;
  String? _errorMessage;

  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  Future<void> _handleLogin() async {
    if (_phoneController.text.isEmpty || _passwordController.text.isEmpty) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    
    try {
      final role = await ApiService.loginWithPhone(_phoneController.text.trim(), _passwordController.text.trim());
      
      if (role == null) {
        setState(() => _errorMessage = "Invalid Credentials or Inactive Account.");
        return;
      }
      
      // UX Check: Prevent Waiters from logging into the Management face, and vice versa
      if (_isStaffMode && (role == 'admin' || role == 'super_admin')) {
        setState(() => _errorMessage = "Please switch to Management Portal.");
        return;
      } else if (!_isStaffMode && (role == 'waiter' || role == 'cashier')) {
        setState(() => _errorMessage = "Please switch to Staff Terminal.");
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

  void _toggleMode() {
    setState(() {
      _isStaffMode = !_isStaffMode;
      _errorMessage = null;
      _phoneController.clear();
      _passwordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: () => loc.toggleLanguage(),
                  child: Text(loc.translate('switch_lang'), style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                ),
              ),
              const Spacer(),
              
              const Icon(Icons.verified_user_rounded, size: 80, color: Color(0xFF6366F1))
                  .animate().scale(duration: 600.ms, curve: Curves.easeOutBack).fadeIn(duration: 600.ms),
              const SizedBox(height: 24),
              const Text('VERIFY-ME', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 4))
                  .animate().fadeIn(delay: 200.ms, duration: 500.ms).slideY(begin: 0.2, end: 0),
              const SizedBox(height: 48),

              if (_errorMessage != null) ...[
                Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))
                    .animate().shakeX(duration: 300.ms),
                const SizedBox(height: 16),
              ],

              // The Double Face Animated Switcher
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _isStaffMode ? _buildStaffForm(loc) : _buildManagementForm(loc),
              ),

              const SizedBox(height: 32),
              
              TextButton(
                onPressed: _toggleMode,
                child: Text(
                  _isStaffMode ? 'Switch to Management Portal' : 'Switch to Staff Terminal',
                  style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                ),
              ).animate().fadeIn(delay: 600.ms, duration: 400.ms),
              
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStaffForm(LocalizationService loc) {
    return Column(
      key: const ValueKey('staff_face'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('STAFF FLOOR TERMINAL', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
        const SizedBox(height: 16),
        TextField(
          controller: _phoneController, keyboardType: TextInputType.phone, style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration(const Color(0xFF10B981)).copyWith(hintText: loc.translate('phone_hint')),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController, obscureText: true, style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration(const Color(0xFF10B981)).copyWith(hintText: loc.translate('password_hint')),
          onSubmitted: (_) => _handleLogin(),
        ),
        const SizedBox(height: 24),
        _buildSubmitButton(loc.translate('authenticate'), const Color(0xFF10B981)),
      ],
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildManagementForm(LocalizationService loc) {
    return Column(
      key: const ValueKey('management_face'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('MANAGEMENT PORTAL', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFF59E0B), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
        const SizedBox(height: 16),
        TextField(
          controller: _phoneController, keyboardType: TextInputType.phone, style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration(const Color(0xFFF59E0B)).copyWith(hintText: loc.translate('phone_hint')),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController, obscureText: true, style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration(const Color(0xFFF59E0B)).copyWith(hintText: loc.translate('password_hint')),
          onSubmitted: (_) => _handleLogin(),
        ),
        const SizedBox(height: 24),
        _buildSubmitButton(loc.translate('secure_login'), const Color(0xFFF59E0B)),
      ],
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  InputDecoration _inputDecoration(Color accentColor) {
    return InputDecoration(
      filled: true, fillColor: const Color(0xFF0F172A),
      prefixIcon: Icon(Icons.lock_outline, color: accentColor),
      hintStyle: const TextStyle(color: Colors.white30),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
    );
  }

  Widget _buildSubmitButton(String label, Color btnColor) {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handleLogin,
      style: ElevatedButton.styleFrom(
        backgroundColor: btnColor,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: _isLoading 
          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Text(label, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
    );
  }
}