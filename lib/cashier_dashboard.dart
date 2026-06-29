import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';
import 'dart:async';
import 'localization_service.dart';

class CashierDashboard extends StatefulWidget {
  const CashierDashboard({super.key});

  @override
  State<CashierDashboard> createState() => _CashierDashboardState();
}

class _CashierDashboardState extends State<CashierDashboard> {
  String? _selectedTransactionId;
  
  // Simulated Real-Time Stream (To be replaced by Supabase Stream)
  final StreamController<List<Map<String, dynamic>>> _livePaymentsController = StreamController();
  List<Map<String, dynamic>> _mockPayments = [
    {'id': 'TXN-8842', 'amount': '1,250 ETB', 'bank': 'Telebirr', 'time': 'Just now', 'waiter_id': null},
    {'id': 'TXN-9931', 'amount': '450 ETB', 'bank': 'CBE', 'time': '2 min ago', 'waiter_id': null},
  ];

  // The Cleared Ledger Data
  final List<Map<String, dynamic>> _clearedLedger = [
    {'waiter': 'Waiter 1', 'id': 'TXN-1101', 'amount': '800 ETB', 'bank': 'CBE'},
    {'waiter': 'Waiter 2', 'id': 'TXN-2234', 'amount': '1,500 ETB', 'bank': 'Telebirr'},
  ];

  final List<String> _activeWaiters = [
    'Waiter 1', 'Waiter 2', 'Waiter 3', 
    'Waiter 4', 'Waiter 5', 'Waiter 6',
    'Waiter 7', 'Waiter 8', 'Waiter 9'
  ];

  @override
  void initState() {
    super.initState();
    _livePaymentsController.add(_mockPayments);
    
    // Simulate incoming payments every 15 seconds
    Timer.periodic(const Duration(seconds: 15), (timer) {
      if (!mounted) return;
      _mockPayments.insert(0, {
        'id': 'TXN-${(1000 + DateTime.now().millisecondsSinceEpoch % 9000).toInt()}',
        'amount': '8${(DateTime.now().second * 10)} ETB',
        'bank': 'Telebirr',
        'time': 'Just now',
        'waiter_id': null
      });
      _livePaymentsController.add(_mockPayments);
    });
  }

  @override
  void dispose() {
    _livePaymentsController.close();
    super.dispose();
  }

  void _assignToWaiter(String waiterName) async {
    if (_selectedTransactionId == null) return;
    if (await Vibration.hasVibrator() ?? false) Vibration.vibrate(pattern: [0, 50, 100, 50]);
    
    setState(() {
      final payment = _mockPayments.firstWhere((p) => p['id'] == _selectedTransactionId);
      _mockPayments.removeWhere((p) => p['id'] == _selectedTransactionId);
      
      // Move to Ledger
      _clearedLedger.insert(0, {
        'waiter': waiterName,
        'id': payment['id'],
        'amount': payment['amount'],
        'bank': payment['bank'],
      });
      
      _livePaymentsController.add(_mockPayments);
      _selectedTransactionId = null;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text('Cleared to $waiterName', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
        duration: const Duration(seconds: 2),
      )
    );
  }

  void _rejectPayment() async {
    if (_selectedTransactionId == null) return;
    if (await Vibration.hasVibrator() ?? false) Vibration.vibrate(duration: 200);
    
    setState(() {
      _mockPayments.removeWhere((p) => p['id'] == _selectedTransactionId);
      _livePaymentsController.add(_mockPayments);
      _selectedTransactionId = null;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white),
            SizedBox(width: 12),
            Text('Payment Flagged & Removed', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
      )
    );
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
          backgroundColor: const Color(0xFF020617),
          elevation: 0,
          title: Row(
            children: [
              Container(
                width: 12, height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.5), blurRadius: 10)]
                ),
              ),
              const SizedBox(width: 12),
              Text(
                loc.translate('cashier_terminal'), 
                style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 16)
              ),
            ],
          ),
          leading: IconButton(
            icon: const Icon(CupertinoIcons.back), 
            onPressed: () => Navigator.pop(context)
          ),
          bottom: TabBar(
            indicatorColor: const Color(0xFF10B981),
            labelColor: const Color(0xFF10B981),
            unselectedLabelColor: const Color(0xFF64748B),
            tabs: [
              Tab(text: loc.translate('live_feed')),
              Tab(text: loc.translate('cleared_ledger')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // TAB 1: LIVE TRIAGE FEED
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Color(0xFF020617),
                    border: Border(bottom: BorderSide(color: Color(0xFF1E293B), width: 2))
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            loc.translate('unassigned'), 
                            style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12)
                          ),
                          if (_selectedTransactionId != null)
                            GestureDetector(
                              onTap: _rejectPayment,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444).withOpacity(0.2), 
                                  borderRadius: BorderRadius.circular(8), 
                                  border: Border.all(color: const Color(0xFFEF4444))
                                ),
                                child: Text(
                                  loc.translate('flag_reject'), 
                                  style: const TextStyle(color: Color(0xFFEF4444), fontSize: 10, fontWeight: FontWeight.bold)
                                ),
                              ),
                            )
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 140,
                        child: StreamBuilder<List<Map<String, dynamic>>>(
                          stream: _livePaymentsController.stream,
                          builder: (context, snapshot) {
                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return Center(
                                child: Text(
                                  loc.translate('queue_clear'), 
                                  style: const TextStyle(color: Color(0xFF64748B))
                                )
                              );
                            }
                            return ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: snapshot.data!.length,
                              itemBuilder: (context, index) {
                                final payment = snapshot.data![index];
                                final isSelected = _selectedTransactionId == payment['id'];
                                final bankColor = _getBankColor(payment['bank']);
                                
                                return GestureDetector(
                                  onTap: () {
                                    setState(() => _selectedTransactionId = isSelected ? null : payment['id']);
                                    if (isSelected == false) Vibration.vibrate(duration: 30);
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.only(right: 16),
                                    width: 220,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFF10B981).withOpacity(0.1) : const Color(0xFF0F172A),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: isSelected ? const Color(0xFF10B981) : const Color(0xFF1E293B), width: 2),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
                                              decoration: BoxDecoration(color: bankColor.withOpacity(0.2), borderRadius: BorderRadius.circular(4)), 
                                              child: Text(payment['bank'], style: TextStyle(color: bankColor, fontSize: 10, fontWeight: FontWeight.w900))
                                            ),
                                            Text(payment['time'], style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Text(payment['amount'], style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                                        const SizedBox(height: 4),
                                        Text('ID: ${payment['id']}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          }
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
                            Text(
                              loc.translate('active_waitstaff'), 
                              style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12)
                            ),
                            if (_selectedTransactionId != null)
                              Text(
                                loc.translate('assign_prompt'), 
                                style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12)
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3, 
                              crossAxisSpacing: 16, 
                              mainAxisSpacing: 16, 
                              childAspectRatio: 1.0
                            ),
                            itemCount: _activeWaiters.length,
                            itemBuilder: (context, index) {
                              final canAssign = _selectedTransactionId != null;
                              return GestureDetector(
                                onTap: canAssign ? () => _assignToWaiter(_activeWaiters[index]) : null,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  decoration: BoxDecoration(
                                    color: canAssign ? const Color(0xFF1E293B) : const Color(0xFF020617), 
                                    borderRadius: BorderRadius.circular(16), 
                                    border: Border.all(color: canAssign ? const Color(0xFF3B82F6).withOpacity(0.5) : const Color(0xFF1E293B))
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        CupertinoIcons.person_solid, 
                                        color: canAssign ? Colors.white : const Color(0xFF334155), 
                                        size: 28
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _activeWaiters[index], 
                                        style: TextStyle(color: canAssign ? Colors.white : const Color(0xFF64748B), fontSize: 14, fontWeight: FontWeight.bold)
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
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
              padding: const EdgeInsets.all(24),
              itemCount: _clearedLedger.length,
              itemBuilder: (context, index) {
                final entry = _clearedLedger[index];
                final bankColor = _getBankColor(entry['bank']);
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B), 
                    borderRadius: BorderRadius.circular(16)
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry['waiter'], 
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: bankColor.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                                child: Text(entry['bank'], style: TextStyle(color: bankColor, fontSize: 10, fontWeight: FontWeight.bold))
                              ),
                              const SizedBox(width: 8),
                              Text('ID: ${entry['id']}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                            ],
                          )
                        ],
                      ),
                      Text(
                        entry['amount'], 
                        style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 16)
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}