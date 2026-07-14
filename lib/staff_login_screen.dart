import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'api_service.dart';
import 'offline_storage.dart';
import 'business_gateway_screen.dart';
import 'waiter_dashboard.dart';
import 'cashier_dashboard.dart';
import 'super_admin_dashboard.dart';
import 'admin_dashboard.dart';

class StaffLoginScreen extends StatefulWidget {
  const StaffLoginScreen({super.key});

  @override
  State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  late Map<String, String?> _lockedBusiness;

  @override
  void initState() {
    super.initState();
    _lockedBusiness = DeviceStorage.getLockedBusiness();
  }

  Future<void> _handleLogin() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    if (phone.isEmpty || password.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    FocusScope.of(context).unfocus();

    try {
      final role = await ApiService.loginStaffUnderBusiness(
        _lockedBusiness['id']!,
        phone,
        password,
      );

      if (!mounted) return;

      if (role != null) {
        Widget nextScreen;
        if (role == 'super_admin') nextScreen = const SuperAdminDashboard();
        else if (role == 'admin') nextScreen = const AdminDashboard();
        else if (role == 'cashier') nextScreen = const CashierDashboard();
        else nextScreen = const WaiterDashboard();

        Navigator.pushReplacement(context, CupertinoPageRoute(builder: (_) => nextScreen));
      } else {
        setState(() => _errorMessage = "Invalid credentials or inactive account.");
      }
    } catch (e) {
      setState(() => _errorMessage = "Login Error: Check connection.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _confirmUnbindDevice() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('Unbind Terminal?', style: TextStyle(color: Colors.white)),
        content: const Text('This will remove the current restaurant connection from this device.', style: TextStyle(color: Colors.white54)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL', style: TextStyle(color: Color(0xFF64748B)))),
          TextButton(
            onPressed: () async {
              await DeviceStorage.clearDeviceLock();
              if (mounted) {
                Navigator.pop(context);
                Navigator.pushReplacement(context, CupertinoPageRoute(builder: (_) => const BusinessGatewayScreen()));
              }
            },
            child: const Text('UNBIND', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.verified_user, color: Color(0xFF10B981), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      _lockedBusiness['name']?.toUpperCase() ?? 'UNKNOWN TENANT',
                      style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
                    ),
                  ],
                ),
              ).animate().fadeIn(),
              const SizedBox(height: 32),
              
              const Text('STAFF LOGIN', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2)).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: 32),

              Container(
                decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white10)),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'PHONE NUMBER',
                        labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                        prefixIcon: const Icon(Icons.phone, color: Color(0xFF6366F1)),
                        filled: true, fillColor: const Color(0xFF020617),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'PASSWORD',
                        labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                        prefixIcon: const Icon(Icons.lock, color: Color(0xFF6366F1)),
                        filled: true, fillColor: const Color(0xFF020617),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('AUTHORIZE', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                      ),
                    ),
                  ],
                ),
              ).animate().slideY(begin: 0.1, end: 0, delay: 200.ms).fadeIn(delay: 200.ms),

              const SizedBox(height: 32),
              TextButton(
                onPressed: _confirmUnbindDevice,
                child: const Text('Terminal Mismatch? Unbind Device', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              ).animate().fadeIn(delay: 500.ms),
            ],
          ),
        ),
      ),
    );
  }
}