import 'package:flutter/material.dart';
import 'modern_scanner.dart';
import 'pin_login_screen.dart'; // For logging out

class WaiterDashboard extends StatelessWidget {
  const WaiterDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617), // True OLED Black
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            // Clickable Avatar for Profile
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (context) => const WaiterProfileScreen())
                );
              },
              child: const CircleAvatar(
                backgroundColor: Color(0xFF1E293B),
                child: Icon(Icons.person, color: Colors.white70),
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ACTIVE SHIFT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 1.5)),
                Text('Henok', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
              ],
            ),
            const Spacer(),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF10B981),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF10B981).withOpacity(0.6), blurRadius: 8, spreadRadius: 2)
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          const Expanded(flex: 3, child: SizedBox()), 
          
          Center(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => const ModernScannerScreen(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    transitionDuration: const Duration(milliseconds: 500),
                  ),
                );
              },
              child: Hero(
                tag: 'scanner_hero_core',
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF4338CA)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.4), blurRadius: 50, spreadRadius: 10),
                    ],
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.document_scanner_outlined, size: 72, color: Colors.white),
                      SizedBox(height: 16),
                      Material(
                        color: Colors.transparent,
                        child: Text(
                          'SCAN',
                          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 4, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          const Expanded(flex: 2, child: SizedBox()), 

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('RECENT SCANS', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w800, letterSpacing: 1.5, fontSize: 12)),
                const SizedBox(height: 24),
                _buildHistoryRow('Telebirr', 'DET5G6ZLWE', 'Just now'),
                const SizedBox(height: 20),
                _buildHistoryRow('CBE Birr', 'CBE9X7P2LQ', '12 mins ago'),
                const SizedBox(height: 20),
                _buildHistoryRow('Telebirr', 'DET1A2B3C4', '45 mins ago'),
                const SizedBox(height: 12),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildHistoryRow(String bank, String id, String time) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), shape: BoxShape.circle),
          child: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 24),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(bank, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
            Text(id, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, letterSpacing: 1)),
          ],
        ),
        const Spacer(),
        Text(time, style: const TextStyle(color: Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// --- NEW: Waiter Profile Screen ---
class WaiterProfileScreen extends StatelessWidget {
  const WaiterProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF6366F1), width: 4),
                ),
                child: const Icon(Icons.person, size: 64, color: Colors.white70),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Henok', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.2),
                borderRadius: BorderRadius.circular(20)
              ),
              child: const Text('WAITER', style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold, letterSpacing: 2)),
            ),
            const SizedBox(height: 48),
            
            // Stats Board
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn('SCANS TODAY', '42'),
                  Container(width: 1, height: 40, color: const Color(0xFF1E293B)),
                  _buildStatColumn('SHIFT TIME', '4h 12m'),
                ],
              ),
            ),
            
            const Spacer(),
            
            // Logout Button
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {
                  // Navigate back to the PIN login screen and clear history
                  Navigator.pushAndRemoveUntil(
                    context, 
                    MaterialPageRoute(builder: (context) => const PinLoginScreen()), 
                    (route) => false
                  );
                },
                icon: const Icon(Icons.logout, color: Color(0xFFEF4444)),
                label: const Text('END SHIFT & LOGOUT', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  backgroundColor: const Color(0xFFEF4444).withOpacity(0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
      ],
    );
  }
}