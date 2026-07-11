import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'api_service.dart';
import 'dual_login_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  late final Stream<List<Map<String, dynamic>>> _ticketsStream;
  late final Stream<List<Map<String, dynamic>>> _staffStream;
  late final Stream<Map<String, dynamic>> _businessStream;
  
  String _selectedTimeRange = 'Today';

  @override
  void initState() {
    super.initState();
    _ticketsStream = ApiService.streamTodayTickets();
    _staffStream = ApiService.streamStaffRoster();
    _businessStream = ApiService.streamCurrentBusiness();
  }

  List<DropdownMenuItem<String>> _getAvailableRoles() {
    List<DropdownMenuItem<String>> roles = [
      const DropdownMenuItem(value: 'waiter', child: Text('Waiter')),
      const DropdownMenuItem(value: 'admin', child: Text('Admin')),
    ];
    if (ApiService.currentBusinessHasCashier == true) {
      roles.insert(1, const DropdownMenuItem(value: 'cashier', child: Text('Cashier')));
    }
    return roles;
  }

  Color _getBankColor(String bank) {
    if (bank.toLowerCase().contains('telebirr')) return const Color(0xFF0EA5E9);
    if (bank.toLowerCase().contains('cbe')) return const Color(0xFFA855F7);
    if (bank.toLowerCase().contains('dashen')) return const Color(0xFFF59E0B);
    return const Color(0xFF64748B);
  }

  // --- NEW: BANK ACCOUNT CONFIGURATION SHEET ---
  void _showBankConfigSheet(Map<String, dynamic> currentAccounts) {
    final tNum = TextEditingController(text: currentAccounts['telebirr_number'] ?? '');
    final tName = TextEditingController(text: currentAccounts['telebirr_name'] ?? '');
    final cNum = TextEditingController(text: currentAccounts['cbe_number'] ?? '');
    final cName = TextEditingController(text: currentAccounts['cbe_name'] ?? '');
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24, left: 24, right: 24, top: 32),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('OFFICIAL BANK ACCOUNTS', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12)),
                    const SizedBox(height: 8),
                    const Text('Scanned receipts will be cross-referenced against these exact details to prevent fraud.', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                    const SizedBox(height: 24),
                    
                    // Telebirr Section
                    const Text('TELEBIRR', style: TextStyle(color: Color(0xFF0EA5E9), fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: tNum, keyboardType: TextInputType.phone, style: const TextStyle(color: Colors.white), decoration: _buildInputDecoration('ACCOUNT NUMBER', Icons.numbers))),
                        const SizedBox(width: 12),
                        Expanded(child: TextField(controller: tName, style: const TextStyle(color: Colors.white), decoration: _buildInputDecoration('MERCHANT NAME', Icons.person))),
                      ],
                    ),
                    const Divider(color: Colors.white10, height: 32, thickness: 2),

                    // CBE Section
                    const Text('CBE / CBE BIRR', style: TextStyle(color: Color(0xFFA855F7), fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: cNum, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: _buildInputDecoration('ACCOUNT NUMBER', Icons.numbers))),
                        const SizedBox(width: 12),
                        Expanded(child: TextField(controller: cName, style: const TextStyle(color: Colors.white), decoration: _buildInputDecoration('MERCHANT NAME', Icons.person))),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: isSubmitting ? null : () async {
                        setSheetState(() => isSubmitting = true);
                        try {
                          await ApiService.updateBankAccounts({
                            'telebirr_number': tNum.text.trim(), 'telebirr_name': tName.text.trim(),
                            'cbe_number': cNum.text.trim(), 'cbe_name': cName.text.trim(),
                          });
                          if (context.mounted) Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bank Details Locked.'), backgroundColor: Color(0xFF10B981)));
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
                        } finally {
                          setSheetState(() => isSubmitting = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      child: isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('SAVE BANK DETAILS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
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

  // --- STAFF PROVISIONING (Unchanged) ---
  void _showAddStaffSheet() {
    final _pinController = TextEditingController(); final _nameController = TextEditingController();
    final _phoneController = TextEditingController(); final _passwordController = TextEditingController();
    String _selectedRole = 'waiter'; bool _isSubmitting = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24, left: 24, right: 24, top: 32),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('PROVISION NEW STAFF', style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12)),
                    const SizedBox(height: 24),
                    TextField(controller: _nameController, style: const TextStyle(color: Colors.white), decoration: _buildInputDecoration('FULL NAME', Icons.person_outline)),
                    const SizedBox(height: 16),
                    TextField(controller: _phoneController, keyboardType: TextInputType.phone, style: const TextStyle(color: Colors.white), decoration: _buildInputDecoration('PHONE NUMBER', Icons.phone)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(flex: 2, child: TextField(controller: _passwordController, style: const TextStyle(color: Colors.white), decoration: _buildInputDecoration('PASSWORD', Icons.lock))),
                        const SizedBox(width: 12),
                        Expanded(flex: 1, child: TextField(controller: _pinController, keyboardType: TextInputType.number, maxLength: 4, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2), decoration: _buildInputDecoration('ID', Icons.badge).copyWith(counterText: ""))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedRole, dropdownColor: const Color(0xFF0F172A),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      decoration: _buildInputDecoration('SYSTEM ROLE', Icons.work), items: _getAvailableRoles(),
                      onChanged: (val) => setSheetState(() => _selectedRole = val!),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : () async {
                        if (_nameController.text.isEmpty || _pinController.text.length < 4 || _phoneController.text.isEmpty || _passwordController.text.isEmpty) return;
                        setSheetState(() => _isSubmitting = true);
                        try {
                          await ApiService.createStaffMember(pin: _pinController.text.trim(), name: _nameController.text.trim(), phone: _phoneController.text.trim(), password: _passwordController.text.trim(), role: _selectedRole);
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.redAccent));
                        } finally {
                          setSheetState(() => _isSubmitting = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('SAVE USER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
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

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label, labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
      prefixIcon: Icon(icon, color: const Color(0xFF6366F1)), filled: true, fillColor: const Color(0xFF020617),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        title: const Text('MASTER OPERATIONS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 2)).animate().fadeIn(),
        leading: IconButton(
          icon: const Icon(Icons.logout, color: Colors.redAccent),
          onPressed: () {
            ApiService.currentBusinessId = null; ApiService.currentStaffNumber = null;
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DualLoginScreen()));
          }
        ),
        actions: [
          StreamBuilder<Map<String, dynamic>>(
            stream: _businessStream,
            builder: (context, snapshot) {
              final accounts = snapshot.data?['bank_accounts'] ?? {};
              return IconButton(
                icon: Icon(Icons.account_balance, color: accounts.isEmpty ? Colors.redAccent : const Color(0xFF10B981)), 
                onPressed: () => _showBankConfigSheet(accounts)
              );
            }
          ),
          IconButton(icon: const Icon(Icons.person_add_alt_1, color: Color(0xFF6366F1)), onPressed: _showAddStaffSheet)
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // TIME FILTER TOGGLES
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: ['Today', 'Weekly', 'Monthly'].map((range) {
                    bool isSelected = _selectedTimeRange == range;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTimeRange = range),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(color: isSelected ? const Color(0xFF6366F1) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                          child: Center(child: Text(range.toUpperCase(), style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1))),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ).animate().fadeIn(duration: 400.ms),
          ),

          // FINANCIAL ANALYTICS
          SliverToBoxAdapter(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _ticketsStream,
              builder: (context, snapshot) {
                double totalRevenue = 0; int pendingCount = 0;
                Map<String, double> bankTotals = {}; 

                if (snapshot.hasData) {
                  for (var ticket in snapshot.data!) {
                    if (ticket['status'] == 'settled') {
                      double amount = (ticket['bill_amount'] ?? 0).toDouble();
                      totalRevenue += amount;
                      String bankName = ticket['bank'] ?? 'Unknown';
                      bankTotals[bankName] = (bankTotals[bankName] ?? 0) + amount;
                    } else if (ticket['status'] == 'pending') {
                      pendingCount++;
                    }
                  }
                }

                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildMetricCard('TOTAL REVENUE', '${totalRevenue.toStringAsFixed(0)} ETB', const Color(0xFF10B981))),
                          const SizedBox(width: 12),
                          Expanded(child: _buildMetricCard('ACTIVE BILLS', '$pendingCount', const Color(0xFFF59E0B))),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text('BANK DEPOSIT BREAKDOWN', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.5)),
                      const SizedBox(height: 16),
                      if (bankTotals.isEmpty)
                        Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(24)), child: const Center(child: Text('No verified transactions yet.', style: TextStyle(color: Color(0xFF64748B)))))
                      else
                        Container(
                          padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(24)),
                          child: Column(
                            children: bankTotals.entries.map((entry) {
                              Color bColor = _getBankColor(entry.key);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: Row(
                                  children: [
                                    Container(width: 12, height: 12, decoration: BoxDecoration(color: bColor, shape: BoxShape.circle, boxShadow: [BoxShadow(color: bColor.withValues(alpha: 0.5), blurRadius: 6)])),
                                    const SizedBox(width: 16),
                                    Text(entry.key, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                    const Spacer(),
                                    Text('${entry.value.toStringAsFixed(0)} ETB', style: TextStyle(color: bColor, fontWeight: FontWeight.w900, fontSize: 14)),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms);
              },
            ),
          ),

          // THE MASTER TRANSACTION LEDGER
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text('MASTER TRANSACTION LEDGER', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.5)),
            ),
          ),

          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _ticketsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator(color: Color(0xFF6366F1)))));
              if (!snapshot.hasData || snapshot.data!.isEmpty) return const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(24.0), child: Text('Ledger is clear.', style: TextStyle(color: Colors.white30)))));

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final ticket = snapshot.data![index];
                    final isSettled = ticket['status'] == 'settled';
                    final isRejected = ticket['status'] == 'rejected';
                    final bankColor = _getBankColor(ticket['bank'] ?? '');
                    final statusColor = isSettled ? const Color(0xFF10B981) : (isRejected ? Colors.redAccent : const Color(0xFFF59E0B));

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.receipt_long, color: statusColor, size: 16),
                                  const SizedBox(width: 8),
                                  Text('${ticket['bill_amount']} ETB', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(ticket['bank'] ?? 'N/A', style: TextStyle(color: bankColor, fontSize: 10, fontWeight: FontWeight.w900)),
                                  const SizedBox(width: 8),
                                  Text('REF: ${ticket['transaction_ref'] ?? ticket['ticket_id'].toString().substring(0,8)}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 10)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('Waiter ID: ${ticket['waiter_id']} | Status: ${ticket['status'].toString().toUpperCase()}', style: const TextStyle(color: Color(0xFF475569), fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: (20 * index).ms).slideX(begin: 0.1, end: 0, delay: (20 * index).ms);
                  },
                  childCount: snapshot.data!.length,
                ),
              );
            },
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 40)) // Bottom padding
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String val, Color accents) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(24), border: Border(left: BorderSide(color: accents, width: 4))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          Text(val, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}