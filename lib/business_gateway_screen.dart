import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:vibration/vibration.dart';
import 'api_service.dart';
import 'offline_storage.dart';
import 'staff_login_screen.dart';

class BusinessGatewayScreen extends StatefulWidget {
  const BusinessGatewayScreen({super.key});

  @override
  State<BusinessGatewayScreen> createState() => _BusinessGatewayScreenState();
}

class _BusinessGatewayScreenState extends State<BusinessGatewayScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _verifyAndLock() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    FocusScope.of(context).unfocus();

    try {
      final bizData = await ApiService.verifyBusinessCode(code);
      
      if (bizData != null) {
        // Lock the device
        await DeviceStorage.lockDeviceToBusiness(
          bizData['business_id'],
          bizData['name'],
          bizData['business_code'],
        );

        final hasVib = await Vibration.hasVibrator();
        if (hasVib == true) Vibration.vibrate(pattern: [0, 50, 100, 50]);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            CupertinoPageRoute(builder: (_) => const StaffLoginScreen()),
          );
        }
      }
    } catch (e) {
      final hasVib = await Vibration.hasVibrator();
      if (hasVib == true) Vibration.vibrate(duration: 200);
      setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _isLoading = false);
    }
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
              const Icon(Icons.storefront_outlined, size: 80, color: Color(0xFF6366F1))
                  .animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
              const SizedBox(height: 24),
              const Text(
                'DEVICE PROVISIONING',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2),
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 8),
              const Text(
                'Enter your unique tenant code to lock this terminal to your restaurant.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ).animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 48),

              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white10),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    TextField(
                      controller: _codeController,
                      textCapitalization: TextCapitalization.characters,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 4),
                      decoration: InputDecoration(
                        hintText: 'ENTER CODE',
                        hintStyle: const TextStyle(color: Color(0xFF334155), fontSize: 16, letterSpacing: 2),
                        filled: true,
                        fillColor: const Color(0xFF020617),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                      ).animate().fadeIn(),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _verifyAndLock,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('LOCK TERMINAL', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                      ),
                    ),
                  ],
                ),
              ).animate().slideY(begin: 0.2, end: 0, delay: 400.ms).fadeIn(delay: 400.ms),
            ],
          ),
        ),
      ),
    );
  }
}