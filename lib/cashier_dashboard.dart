import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'localization_service.dart';
import 'api_service.dart';
import 'dual_login_screen.dart';

class CashierDashboard extends StatefulWidget {
  const CashierDashboard({super.key});

  @override
  State<CashierDashboard> createState() => _CashierDashboardState();
}

class _CashierDashboardState extends State<CashierDashboard> {
  String? _selectedTransactionId;
  
  // The Bulletproof Streams
  late Stream<List<Map<String, dynamic>>> _ticketsStream;
  late Stream<List<Map<String, dynamic>>> _staffStream;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  // --- REFRESH DATA ENGINE ---
  void _refreshData() {
    setState(() {
      _ticketsStream = ApiService.streamTodayTickets();
      _staffStream = ApiService.streamStaffRoster();
    });
  }

  Future<void> _assignToWaiter(String waiterId, String waiterName) async {
    if (_selectedTransactionId == null) return;
    final targetTxn = _selectedTransactionId!;
    setState(() => _selectedTransactionId = null); // Optimistic UI reset

    try {
      await Supabase.instance.client.from('tickets').update({
        'status': 'settled',
        'waiter_id': waiterId,
      }).eq('ticket_id', targetTxn);

      final assignVib = await Vibration.hasVibrator();
      if (assignVib == true) Vibration.vibrate(pattern: [0, 50, 100, 50]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text('Cleared to $waiterName', style: const TextStyle(fontWeight: FontWeight.bold)),
          ]),
          backgroundColor: const Color(0xFF10B981), behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20), duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
    }
  }

  Future<void> _rejectPayment() async {
    if (_selectedTransactionId == null) return;
    final targetTxn = _selectedTransactionId!;
    setState(() => _selectedTransactionId = null); 

    try {
      await Supabase.instance.client.from('tickets').update({'status': 'rejected'}).eq('ticket_id', targetTxn);
      final rejectVib = await Vibration.hasVibrator();
      if (rejectVib == true) Vibration.vibrate(duration: 200);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white), SizedBox(width: 12),
            Text('Payment Flagged & Removed', style: TextStyle(fontWeight: FontWeight.bold)),
          ]),
          backgroundColor: const Color(0xFFEF4444), behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
    }
  }

  Color _getBankColor(String bank) {
    if (bank.toLowerCase().contains('telebirr')) return const Color(0xFF0EA5E9);
    if (bank.toLowerCase().contains('cbe')) return const Color(0xFFA855F7);
    if (bank.toLowerCase().contains('dashen')) return const Color(0xFFF59E0B);
    return const Color(0xFF64748B);
  }

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF020617), elevation: 0,
          title: Row(
            children: [
              Container(
                width: 12, height: 12,
                decoration: BoxDecoration(color: const Color(0xFF10B981), shape: BoxShape.circle, boxShadow: [BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.5), blurRadius: 10)]),
              ),
              const SizedBox(width: 12),
              Text(loc.translate('cashier_terminal'), style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 16)),
            ],
          ).animate().fadeIn(duration: 500.ms),
          leading: IconButton(icon: const Icon(CupertinoIcons.back), onPressed: () => Navigator.pop(context)),
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
          bottom: TabBar(
            indicatorColor: const Color(0xFF10B981), labelColor: const Color(0xFF10B981), unselectedLabelColor: const Color(0xFF64748B),
            tabs: [Tab(text: loc.translate('live_feed')), Tab(text: loc.translate('cleared_ledger'))],
          ),
        ),
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _ticketsStream,
          builder: (context, ticketSnapshot) {
            final allTickets = ticketSnapshot.data ?? [];
            final pendingTickets = allTickets.where((t) => t['status'] == 'pending').toList();
            final settledTickets = allTickets.where((t) => t['status'] == 'settled').toList();

            return TabBarView(
              children: [
                // TAB 1: LIVE FEED
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(color: Color(0xFF020617), border: Border(bottom: BorderSide(color: Color(0xFF1E293B), width: 2))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(loc.translate('unassigned'), style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12)),
                              if (_selectedTransactionId != null)
                                GestureDetector(
                                  onTap: _rejectPayment,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFEF4444))),
                                    child: Text(loc.translate('flag_reject'), style: const TextStyle(color: Color(0xFFEF4444), fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ).animate().fadeIn().scale(curve: Curves.easeOutBack)
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 140,
                            child: pendingTickets.isEmpty 
                              ? Center(child: Text(loc.translate('queue_clear'), style: const TextStyle(color: Color(0xFF64748B))))
                              : ListView.builder(
                                  scrollDirection: Axis.horizontal, itemCount: pendingTickets.length,
                                  itemBuilder: (context, index) {
                                    final payment = pendingTickets[index];
                                    final isSelected = _selectedTransactionId == payment['ticket_id'];
                                    final bankColor = _getBankColor(payment['bank'] ?? 'Unknown');
                                    
                                    return GestureDetector(
                                      onTap: () async {
                                        setState(() => _selectedTransactionId = isSelected ? null : payment['ticket_id']);
                                        if (!isSelected) {
                                          final cardVib = await Vibration.hasVibrator();
                                          if (cardVib == true) Vibration.vibrate(duration: 30);
                                        }
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        margin: const EdgeInsets.only(right: 16), width: 220, padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: isSelected ? const Color(0xFF10B981).withValues(alpha: 0.1) : const Color(0xFF0F172A),
                                          borderRadius: BorderRadius.circular(16), border: Border.all(color: isSelected ? const Color(0xFF10B981) : const Color(0xFF1E293B), width: 2),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
                                                  decoration: BoxDecoration(color: bankColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)), 
                                                  child: Text(payment['bank'] ?? 'N/A', style: TextStyle(color: bankColor, fontSize: 10, fontWeight: FontWeight.w900))
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Text('${payment['bill_amount']} ETB', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                                            const SizedBox(height: 4),
                                            Text('REF: ${payment['transaction_ref'] ?? payment['ticket_id'].toString().substring(0,8)}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                                          ],
                                        ),
                                      ),
                                    ).animate(key: ValueKey(payment['ticket_id'])).fadeIn(delay: (100 * index).ms, duration: 300.ms).slideX(begin: 0.1, end: 0, delay: (100 * index).ms);
                                  },
                                ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(loc.translate('active_waitstaff'), style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12)),
                                if (_selectedTransactionId != null)
                                  Text(loc.translate('assign_prompt'), style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12)).animate().fadeIn().slideY(begin: -0.2, end: 0),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: StreamBuilder<List<Map<String, dynamic>>>(
                                stream: _staffStream,
                                builder: (context, staffSnapshot) {
                                  if (!staffSnapshot.hasData) return const Center(child: CircularProgressIndicator());
                                  final activeWaiters = staffSnapshot.data!.where((s) => s['is_active'] == true && s['role'] == 'waiter').toList();
                                  
                                  return GridView.builder(
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.0),
                                    itemCount: activeWaiters.length,
                                    itemBuilder: (context, index) {
                                      final waiter = activeWaiters[index];
                                      final canAssign = _selectedTransactionId != null;
                                      return GestureDetector(
                                        onTap: canAssign ? () => _assignToWaiter(waiter['staff_number'].toString(), waiter['name']) : null,
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          decoration: BoxDecoration(
                                            color: canAssign ? const Color(0xFF1E293B) : const Color(0xFF020617), 
                                            borderRadius: BorderRadius.circular(16), 
                                            border: Border.all(color: canAssign ? const Color(0xFF3B82F6).withValues(alpha: 0.5) : const Color(0xFF1E293B))
                                          ),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(CupertinoIcons.person_solid, color: canAssign ? Colors.white : const Color(0xFF334155), size: 28),
                                              const SizedBox(height: 8),
                                              Text(waiter['name'].toString().split(' ').first, style: TextStyle(color: canAssign ? Colors.white : const Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                                            ],
                                          ),
                                        ),
                                      ).animate().fadeIn(delay: (30 * index).ms).scale(delay: (30 * index).ms, duration: 300.ms, curve: Curves.easeOutBack);
                                    },
                                  );
                                }
                              ),
                            )
                          ],
                        ),
                      ),
                    )
                  ],
                ),
                
                // TAB 2: CLEARED LEDGER
                ListView.builder(
                  padding: const EdgeInsets.all(24), itemCount: settledTickets.length,
                  itemBuilder: (context, index) {
                    final entry = settledTickets[index];
                    final bankColor = _getBankColor(entry['bank'] ?? '');
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Waiter ID: ${entry['waiter_id']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: bankColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                                    child: Text(entry['bank'] ?? 'Bank', style: TextStyle(color: bankColor, fontSize: 10, fontWeight: FontWeight.bold))
                                  ),
                                  const SizedBox(width: 8),
                                  Text('REF: ${entry['transaction_ref'] ?? entry['ticket_id'].toString().substring(0,8)}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                                ],
                              )
                            ],
                          ),
                          Text('${entry['bill_amount']} ETB', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 16)),
                        ],
                      ),
                    ).animate().fadeIn(delay: (50 * index).ms, duration: 300.ms).slideX(begin: 0.1, end: 0, delay: (50 * index).ms);
                  },
                ),
              ],
            );
          }
        ),
      ),
    );
  }
}