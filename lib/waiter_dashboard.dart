import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'api_service.dart';
import 'dual_login_screen.dart';
import 'modern_scanner.dart';
import 'offline_storage.dart';

class WaiterDashboard extends StatefulWidget {
  const WaiterDashboard({super.key});

  @override
  State<WaiterDashboard> createState() => _WaiterDashboardState();
}

class _WaiterDashboardState extends State<WaiterDashboard> {
  late Stream<List<Map<String, dynamic>>> _myScansStream;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  // --- REFRESH DATA ENGINE ---
  void _refreshData() {
    setState(() {
      _myScansStream = ApiService.streamWaiterTickets();
    });
  }

  void _openScanner(String bankName, String endpoint) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ModernScannerScreen(
          targetBank: bankName,
          targetEndpoint: endpoint,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        title: Text('FLOOR STAFF: ${ApiService.currentStaffNumber ?? ''}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _refreshData),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () {
              ApiService.currentBusinessId = null;
              ApiService.currentStaffNumber = null;
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DualLoginScreen()));
            },
          )
        ],
      ),
      body: Column(
        children: [
          // --- THE HIVE OFFLINE WARNING BADGE ---
          ValueListenableBuilder<Box<PendingTicket>>(
            valueListenable: Hive.box<PendingTicket>('pending_tickets_queue').listenable(),
            builder: (context, box, _) {
              if (box.isEmpty) return const SizedBox.shrink();
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                color: const Color(0xFFF59E0B),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off, color: Colors.black, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '${box.length} TICKETS OFFLINE - WILL SYNC AUTOMATICALLY',
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 10),
                    ),
                  ],
                ),
              ).animate().slideY(begin: -1, end: 0);
            },
          ),

          // --- SCANNER LAUNCH BUTTONS ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(child: _buildScanButton('TELEBIRR', const Color(0xFF0EA5E9), '/verify-telebirr')),
                const SizedBox(width: 12),
                Expanded(child: _buildScanButton('CBE', const Color(0xFFA855F7), '/verify-cbe')),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(child: _buildScanButton('DASHEN', const Color(0xFFF59E0B), '/verify-dashen')),
                const SizedBox(width: 12),
                Expanded(child: _buildScanButton('OTHER', const Color(0xFF64748B), '/verify')),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('MY RECENT SCANS', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.5)),
            ),
          ),

          // --- WAITER'S PERSONAL TICKET HISTORY ---
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _myScansStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
                if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('No recent scans.', style: TextStyle(color: Colors.white54)));

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final ticket = snapshot.data![index];
                    final isSettled = ticket['status'] == 'settled';
                    final isRejected = ticket['status'] == 'rejected';
                    final statusColor = isSettled ? const Color(0xFF10B981) : (isRejected ? Colors.redAccent : const Color(0xFFF59E0B));

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${ticket['bill_amount']} ETB', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text('${ticket['bank']} - REF: ${ticket['transaction_ref'] ?? ticket['ticket_id'].toString().substring(0,8)}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 10)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                            child: Text(ticket['status'].toString().toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w900)),
                          )
                        ],
                      ),
                    ).animate().fadeIn().slideX();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanButton(String bank, Color color, String endpoint) {
    return GestureDetector(
      onTap: () => _openScanner(bank, endpoint),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.5))),
        child: Center(
          child: Text(bank, style: TextStyle(color: color, fontWeight: FontWeight.w900, letterSpacing: 1)),
        ),
      ),
    );
  }
}