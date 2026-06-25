import 'package:flutter/material.dart';
import 'modern_scanner.dart';

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
            const CircleAvatar(
              backgroundColor: Color(0xFF1E293B),
              child: Icon(Icons.person, color: Colors.white70),
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
            // Pulsing Live Connection Dot
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
          
          // THE MASSIVE HERO BUTTON
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

          // THE BOTTOM SHEET: Shift History
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