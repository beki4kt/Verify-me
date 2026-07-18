import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_service.dart';
import 'staff_login_screen.dart'; // FIXED: Pointing to the correct login screen

class CashierDashboard extends StatefulWidget {
  const CashierDashboard({super.key});

  @override
  State<CashierDashboard> createState() => _CashierDashboardState();
}

class _CashierDashboardState extends State<CashierDashboard> {
  late Stream<List<Map<String, dynamic>>> _ticketsStream;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _ticketsStream = ApiService.streamTodayTickets();
    });
  }

  Color _getBankColor(String bank) {
    if (bank.toLowerCase().contains('telebirr')) return const Color(0xFF0EA5E9);
    if (bank.toLowerCase().contains('cbe')) return const Color(0xFFA855F7);
    if (bank.toLowerCase().contains('dashen')) return const Color(0xFFF59E0B);
    return const Color(0xFF64748B);
  }

  void _showSettlementSheet(Map<String, dynamic> ticket) {
    final actualController = TextEditingController();
    final expectedAmount = (ticket['bill_amount'] ?? 0).toDouble();
    bool isSubmitting = false;
    String? errorText;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final inputText = actualController.text.trim();
            final actualAmount = double.tryParse(inputText);
            final hasInput = inputText.isNotEmpty && actualAmount != null;
            
            final isShortfall = hasInput && actualAmount < expectedAmount;
            final tipAmount = (hasInput && actualAmount > expectedAmount) ? actualAmount - expectedAmount : 0.0;

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24, left: 24, right: 24, top: 32),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('VERIFY PAYMENT', style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: _getBankColor(ticket['bank']).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: Text(ticket['bank'].toString().toUpperCase(), style: TextStyle(color: _getBankColor(ticket['bank']), fontSize: 10, fontWeight: FontWeight.w900)),
                        )
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFF020617), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('REF:', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.bold)),
                              Text(ticket['transaction_ref'] ?? 'UNKNOWN', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1)),
                            ],
                          ),
                          const Divider(color: Colors.white10, height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('WAITER:', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.bold)),
                              Text('ID: ${ticket['waiter_id']}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                            ],
                          ),
                          const Divider(color: Colors.white10, height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('EXPECTED BILL:', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.bold)),
                              Text('${expectedAmount.toStringAsFixed(2)} ETB', style: const TextStyle(color: Color(0xFF10B981), fontSize: 18, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    TextField(
                      controller: actualController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                      style: TextStyle(color: isShortfall ? Colors.redAccent : Colors.white, fontWeight: FontWeight.w900, fontSize: 24),
                      textAlign: TextAlign.center,
                      onChanged: (_) => setSheetState(() {}), 
                      decoration: InputDecoration(
                        labelText: 'ACTUAL AMOUNT IN BANK (ETB)', 
                        labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                        prefixIcon: Icon(Icons.account_balance_wallet, color: isShortfall ? Colors.redAccent : const Color(0xFF6366F1)), 
                        filled: true, fillColor: isShortfall ? Colors.redAccent.withValues(alpha: 0.05) : const Color(0xFF020617),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                    
                    const SizedBox(height: 16),

                    if (hasInput && !isShortfall)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('CALCULATED TIP:', style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold)),
                            Text('${tipAmount.toStringAsFixed(2)} ETB', style: const TextStyle(color: Color(0xFF10B981), fontSize: 16, fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ).animate().fadeIn(),

                    if (isShortfall)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
                            SizedBox(width: 8),
                            Expanded(child: Text('SHORTFALL DETECTED. Amount is less than the expected bill. Settlement blocked.', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold))),
                          ],
                        ),
                      ).animate().fadeIn(),

                    const SizedBox(height: 24),

                    if (errorText != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(errorText!, style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),

                    if (isShortfall)
                      ElevatedButton(
                        onPressed: isSubmitting ? null : () async {
                          setSheetState(() { isSubmitting = true; errorText = null; });
                          try {
                            await Supabase.instance.client.from('tickets').update({
                              'status': 'rejected',
                              'updated_at': DateTime.now().toIso8601String(),
                            }).eq('id', ticket['id']);
                            
                            if (context.mounted) Navigator.pop(context);
                          } catch (e) {
                            setSheetState(() => errorText = 'Network Error: $e');
                          } finally {
                            setSheetState(() => isSubmitting = false);
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        child: isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('REJECT TICKET', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                      )
                    else
                      ElevatedButton(
                        onPressed: (!hasInput || isSubmitting) ? null : () async {
                          setSheetState(() { isSubmitting = true; errorText = null; });
                          try {
                            await Supabase.instance.client.from('tickets').update({
                              'status': 'settled',
                              'actual_amount': actualAmount,
                              'tip_amount': tipAmount,
                              'updated_at': DateTime.now().toIso8601String(),
                            }).eq('id', ticket['id']);
                            
                            if (context.mounted) Navigator.pop(context);
                          } catch (e) {
                            setSheetState(() => errorText = 'Network Error: $e');
                          } finally {
                            setSheetState(() => isSubmitting = false);
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        child: isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('SETTLE TICKET', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                      )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPendingQueue() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _ticketsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('No active tickets.', style: TextStyle(color: Color(0xFF64748B))));

        final pendingTickets = snapshot.data!.where((t) => t['status'] == 'pending').toList();

        if (pendingTickets.isEmpty) return const Center(child: Text('Queue is clear.', style: TextStyle(color: Color(0xFF64748B))));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: pendingTickets.length,
          itemBuilder: (context, index) {
            final ticket = pendingTickets[index];
            final bankColor = _getBankColor(ticket['bank'] ?? '');

            return GestureDetector(
              onTap: () => _showSettlementSheet(ticket),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.notifications_active, color: Color(0xFF6366F1), size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${ticket['bill_amount']} ETB', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(ticket['bank'] ?? 'N/A', style: TextStyle(color: bankColor, fontSize: 10, fontWeight: FontWeight.w900)),
                              const SizedBox(width: 8),
                              Text('REF: ${ticket['transaction_ref']}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          )
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Color(0xFF64748B)),
                  ],
                ),
              ).animate().fadeIn(delay: (20 * index).ms).slideX(begin: 0.1, end: 0),
            );
          },
        );
      },
    );
  }

  Widget _buildSettledLedger() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _ticketsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('No settled tickets.', style: TextStyle(color: Color(0xFF64748B))));

        final pastTickets = snapshot.data!.where((t) => t['status'] != 'pending').toList();

        if (pastTickets.isEmpty) return const Center(child: Text('No settled tickets yet.', style: TextStyle(color: Color(0xFF64748B))));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: pastTickets.length,
          itemBuilder: (context, index) {
            final ticket = pastTickets[index];
            final isSettled = ticket['status'] == 'settled';
            final bankColor = _getBankColor(ticket['bank'] ?? '');
            
            final actualAmt = ticket['actual_amount'] ?? 0.0;
            final tipAmt = ticket['tip_amount'] ?? 0.0;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(isSettled ? Icons.check_circle : Icons.cancel, color: isSettled ? const Color(0xFF10B981) : Colors.redAccent, size: 16),
                          const SizedBox(width: 8),
                          Text(isSettled ? '${ticket['bill_amount']} ETB' : 'REJECTED', style: TextStyle(color: isSettled ? Colors.white : Colors.redAccent, fontSize: 16, fontWeight: FontWeight.w900)),
                        ],
                      ),
                      Text(ticket['bank'] ?? 'N/A', style: TextStyle(color: bankColor, fontSize: 10, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('REF: ${ticket['transaction_ref']}  •  Waiter ID: ${ticket['waiter_id']}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold)),
                  if (isSettled && tipAmt > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text('Includes ${tipAmt.toStringAsFixed(2)} ETB Tip (Total: ${actualAmt.toStringAsFixed(2)})', style: const TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.w900)),
                      ),
                    )
                ],
              ),
            ).animate().fadeIn(delay: (20 * index).ms).slideX(begin: 0.1, end: 0);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF020617),
        appBar: AppBar(
          backgroundColor: const Color(0xFF020617), elevation: 0,
          title: const Text('CASHIER DESK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 2)).animate().fadeIn(),
          leading: IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () {
              ApiService.currentStaffNumber = null;
              // FIXED: Routing to StaffLoginScreen
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const StaffLoginScreen()));
            }
          ),
          bottom: const TabBar(
            indicatorColor: Color(0xFF6366F1),
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 11),
            unselectedLabelColor: Color(0xFF64748B),
            labelColor: Colors.white,
            tabs: [
              Tab(text: 'PENDING QUEUE'),
              Tab(text: 'SETTLED TICKETS'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildPendingQueue(),
            _buildSettledLedger(),
          ],
        ),
      ),
    );
  }
}