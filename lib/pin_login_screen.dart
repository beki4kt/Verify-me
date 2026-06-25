import 'package:flutter/material.dart';
import 'waiter_dashboard.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart'; // <-- Add this to link your files!
// import 'waiter_scanner_screen.dart'; // We will build this next

class PinLoginScreen extends StatefulWidget {
  const PinLoginScreen({super.key});

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> {
  String _pin = '';
  bool _isLoading = false;

  void _addPinDigit(String digit) {
    if (_pin.length < 4) {
      setState(() {
        _pin += digit;
      });
      if (_pin.length == 4) {
        _verifyPinAndLogin();
      }
    }
  }

  void _removePinDigit() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  Future<void> _verifyPinAndLogin() async {
    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client
          .from('staff')
          .select()
          .eq('auth_pin', _pin)
          .eq('is_active', true)
          .maybeSingle();

      if (response != null) {
        final role = response['role'];
        final staffId = response['id'];
        
        // Success! Route based on role
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Welcome, ${response['full_name']}')),
        );

       if (role == 'waiter') {
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(builder: (context) => WaiterDashboard()) // <-- Updated!
          );
        } else if (role == 'cashier') {
          // Route to Cashier Dashboard
        }
      } else {
        // Wrong PIN
        setState(() => _pin = '');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid PIN'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      // Handle network errors
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildNumpadButton(String number) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: InkWell(
        onTap: () => _addPinDigit(number),
        borderRadius: BorderRadius.circular(40),
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.fingerprint, size: 80, color: Color(0xFF6366F1)),
            const SizedBox(height: 20),
            const Text(
              'ENTER PIN',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: 2),
            ),
            const SizedBox(height: 40),
            
            // PIN Dots Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index < _pin.length ? const Color(0xFF6366F1) : const Color(0xFF334155),
                  ),
                );
              }),
            ),
            const SizedBox(height: 60),

            if (_isLoading)
              const CircularProgressIndicator(color: Color(0xFF6366F1))
            else ...[
              // Custom Numpad
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [_buildNumpadButton('1'), _buildNumpadButton('2'), _buildNumpadButton('3')],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [_buildNumpadButton('4'), _buildNumpadButton('5'), _buildNumpadButton('6')],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [_buildNumpadButton('7'), _buildNumpadButton('8'), _buildNumpadButton('9')],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 96), // Spacer for alignment
                  _buildNumpadButton('0'),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: IconButton(
                      iconSize: 40,
                      color: Colors.white54,
                      icon: const Icon(Icons.backspace_outlined),
                      onPressed: _removePinDigit,
                    ),
                  ),
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }
}