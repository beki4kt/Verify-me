import 'package:flutter/material.dart';

class SuperAdminDashboard extends StatelessWidget {
  const SuperAdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('GOD MODE: SYSTEM CONTROL', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 2)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('PLATFORM VITALS', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildControlCard('ACTIVE TENANTS', '1', Icons.business, Colors.blueAccent)),
                const SizedBox(width: 16),
                Expanded(child: _buildControlCard('API HEALTH', '100%', Icons.network_check, Colors.greenAccent)),
              ],
            ),
            const SizedBox(height: 16),
            _buildControlCard('TOTAL NETWORK VOLUME (ETB)', '0.00', Icons.account_balance_wallet, const Color(0xFFF59E0B)),
            
            const SizedBox(height: 48),
            
            const Text('TENANT MANAGEMENT', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const SizedBox(height: 16),
            
            ElevatedButton.icon(
              onPressed: () {
                // Functionality to register a new restaurant client
              },
              icon: const Icon(Icons.add_business, color: Colors.white),
              label: const Text('PROVISION NEW RESTAURANT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                padding: const EdgeInsets.symmetric(vertical: 24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}