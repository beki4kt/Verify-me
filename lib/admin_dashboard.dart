import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'api_service.dart';
import 'dual_login_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  late Stream<List<Map<String, dynamic>>> _ticketsStream;
  late Stream<List<Map<String, dynamic>>> _staffStream;
  late Stream<Map<String, dynamic>> _businessStream;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _ticketsStream = ApiService.streamTodayTickets();
      _staffStream = ApiService.streamStaffRoster();
      _businessStream = ApiService.streamCurrentBusiness();
    });
  }

  List<DropdownMenuItem<String>> _getAvailableRoles() {
    List<DropdownMenuItem<String>> roles = [
      const DropdownMenuItem(value: 'waiter', child: Text('Waiter')),
    ];
    if (ApiService.currentBusinessHasCashier == true) {
      roles.insert(0, const DropdownMenuItem(value: 'cashier', child: Text('Cashier')));
    }
    return roles;
  }

  Color _getBankColor(String bank) {
    if (bank.toLowerCase().contains('telebirr')) return const Color(0xFF0EA5E9);
    if (bank.toLowerCase().contains('cbe')) return const Color(0xFFA855F7);
    if (bank.toLowerCase().contains('dashen')) return const Color(0xFFF59E0B);
    return const Color(0xFF64748B);
  }

  void _showBankConfigSheet(Map<String, dynamic> currentAccounts) {
    final tNum = TextEditingController(text: currentAccounts['telebirr_number'] ?? '');
    final tName = TextEditingController(text: currentAccounts['telebirr_name'] ?? '');
    final cNum = TextEditingController(text: currentAccounts['cbe_number'] ?? '');
    final cName = TextEditingController(text: currentAccounts['cbe_name'] ?? '');
    bool isSubmitting = false;
    String? errorText;

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
                    const Text('CBE / CBE BIRR', style: TextStyle(color: Color(0xFFA855F7), fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: cNum, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: _buildInputDecoration('ACCOUNT NUMBER', Icons.numbers))),
                        const SizedBox(width: 12),
                        Expanded(child: TextField(controller: cName, style: const TextStyle(color: Colors.white), decoration: _buildInputDecoration('MERCHANT NAME', Icons.person))),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    if (errorText != null)
                      Container(
                        padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.redAccent)),
                        child: Text(errorText!, style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),

                    ElevatedButton(
                      onPressed: isSubmitting ? null : () async {
                        setSheetState(() { isSubmitting = true; errorText = null; });
                        try {
                          await ApiService.updateBankAccounts({
                            'telebirr_number': tNum.text.trim(), 'telebirr_name': tName.text.trim(),
                            'cbe_number': cNum.text.trim(), 'cbe_name': cName.text.trim(),
                          });
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          setSheetState(() => errorText = e.toString().replaceAll('Exception: ', ''));
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

  void _showAddStaffSheet() {
    final pinController = TextEditingController(); final nameController = TextEditingController();
    final phoneController = TextEditingController(); final passwordController = TextEditingController();
    String selectedRole = 'waiter'; bool isSubmitting = false;
    String? errorText;

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
                    TextField(controller: nameController, style: const TextStyle(color: Colors.white), decoration: _buildInputDecoration('FULL NAME', Icons.person_outline)),
                    const SizedBox(height: 16),
                    
                    TextField(
                      controller: phoneController, 
                      keyboardType: TextInputType.number, 
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2), 
                      decoration: _buildInputDecoration('PHONE NUMBER', Icons.phone, isPhone: true)
                    ),
                    
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(flex: 2, child: TextField(controller: passwordController, style: const TextStyle(color: Colors.white), decoration: _buildInputDecoration('PASSWORD', Icons.lock))),
                        const SizedBox(width: 12),
                        Expanded(flex: 1, child: TextField(controller: pinController, keyboardType: TextInputType.number, maxLength: 4, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2), decoration: _buildInputDecoration('ID', Icons.badge).copyWith(counterText: ""))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole, dropdownColor: const Color(0xFF0F172A),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      decoration: _buildInputDecoration('SYSTEM ROLE', Icons.work), items: _getAvailableRoles(),
                      onChanged: (val) => setSheetState(() => selectedRole = val!),
                    ),
                    const SizedBox(height: 24),

                    if (errorText != null)
                      Container(
                        padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.redAccent)),
                        child: Text(errorText!, style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),

                    ElevatedButton(
                      onPressed: isSubmitting ? null : () async {
                        if (nameController.text.isEmpty || phoneController.text.length != 8 || passwordController.text.isEmpty) {
                          setSheetState(() => errorText = 'Please fill out all fields and ensure phone is 8 digits.');
                          return;
                        }
                        if (pinController.text.length < 4) {
                          setSheetState(() => errorText = 'Staff ID must be exactly 4 digits.');
                          return;
                        }

                        setSheetState(() { isSubmitting = true; errorText = null; });
                        try {
                          await ApiService.createStaffMember(
                            pin: pinController.text.trim(), 
                            name: nameController.text.trim(), 
                            phone: '+2519${phoneController.text.trim()}', 
                            password: passwordController.text.trim(), 
                            role: selectedRole
                          );
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          setSheetState(() => errorText = e.toString().replaceAll('Exception: ', ''));
                        } finally {
                          setSheetState(() => isSubmitting = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      child: isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('SAVE USER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
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

  void _showEditStaffSheet(Map<String, dynamic> staffMember) {
    final dbPhone = staffMember['phone_number']?.toString() ?? '';
    final displayPhone = dbPhone.startsWith('+2519') ? dbPhone.replaceFirst('+2519', '') : dbPhone;

    final nameController = TextEditingController(text: staffMember['name']?.toString() ?? '');
    final phoneController = TextEditingController(text: displayPhone);
    final passwordController = TextEditingController(text: staffMember['password']?.toString() ?? '');
    
    String selectedRole = staffMember['role'];
    if (selectedRole == 'cashier' && ApiService.currentBusinessHasCashier != true) selectedRole = 'waiter'; 
    bool isSubmitting = false;
    String? errorText;

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
                    Text('MANAGE STAFF: ${staffMember['staff_number']}', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12)),
                    const SizedBox(height: 24),
                    TextField(controller: nameController, style: const TextStyle(color: Colors.white), decoration: _buildInputDecoration('FULL NAME', Icons.person_outline)),
                    const SizedBox(height: 16),
                    
                    TextField(
                      controller: phoneController, 
                      keyboardType: TextInputType.number, 
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2), 
                      decoration: _buildInputDecoration('PHONE NUMBER', Icons.phone, isPhone: true)
                    ),
                    
                    const SizedBox(height: 16),
                    TextField(controller: passwordController, style: const TextStyle(color: Colors.white), decoration: _buildInputDecoration('PASSWORD', Icons.lock)),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole, dropdownColor: const Color(0xFF0F172A),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      decoration: _buildInputDecoration('SYSTEM ROLE', Icons.work), items: _getAvailableRoles(), 
                      onChanged: (val) => setSheetState(() => selectedRole = val!),
                    ),
                    const SizedBox(height: 24),

                    if (errorText != null)
                      Container(
                        padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.redAccent)),
                        child: Text(errorText!, style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),

                    ElevatedButton(
                      onPressed: isSubmitting ? null : () async {
                        if (nameController.text.isEmpty || phoneController.text.length != 8 || passwordController.text.isEmpty) {
                          setSheetState(() => errorText = 'All fields are required and phone must be 8 digits.');
                          return;
                        }
                        setSheetState(() { isSubmitting = true; errorText = null; });
                        try {
                          await ApiService.updateStaffProfile(
                            staffMember['staff_number'].toString(), 
                            nameController.text.trim(),
                            '+2519${phoneController.text.trim()}', 
                            passwordController.text.trim(), 
                            selectedRole
                          );
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          setSheetState(() => errorText = e.toString().replaceAll('Exception: ', ''));
                        } finally {
                          setSheetState(() => isSubmitting = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      child: isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('UPDATE STAFF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
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

  InputDecoration _buildInputDecoration(String label, IconData icon, {bool isPhone = false}) {
    return InputDecoration(
      labelText: label, labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
      prefixIcon: isPhone 
        ? Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: const Color(0xFF6366F1)),
                const SizedBox(width: 12),
                const Text('+2519', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1)),
                const SizedBox(width: 8),
                Container(width: 2, height: 24, color: Colors.white10),
                const SizedBox(width: 12),
              ],
            ),
          )
        : Icon(icon, color: const Color(0xFF6366F1)), 
      filled: true, fillColor: const Color(0xFF020617),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    );
  }

  // PHASE 3: THE STAFF ROSTER TAB WIDGET
  Widget _buildStaffRosterTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _staffStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No staff members found.', style: TextStyle(color: Colors.white30)));
        }

        // Filter out Admins to ensure only single admin view applies
        final staffList = snapshot.data!.where((s) => s['role'] != 'admin').toList();

        if (staffList.isEmpty) {
          return const Center(child: Text('No active floor staff.', style: TextStyle(color: Colors.white30)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: staffList.length,
          itemBuilder: (context, index) {
            final staff = staffList[index];
            final isActive = staff['is_active'] as bool? ?? true;
            final roleName = staff['role']?.toString().toUpperCase() ?? 'UNKNOWN';
            final roleColor = roleName == 'CASHIER' ? const Color(0xFFF59E0B) : const Color(0xFF10B981);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: roleColor.withValues(alpha: 0.1),
                    child: Icon(roleName == 'CASHIER' ? Icons.point_of_sale : Icons.restaurant_menu, color: roleColor, size: 18),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(staff['name'] ?? 'Unknown', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text('ID: ${staff['staff_number']}  •  $roleName', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Color(0xFF64748B), size: 20),
                    onPressed: () => _showEditStaffSheet(staff),
                  ),
                  Switch.adaptive(
                    value: isActive,
                    activeTrackColor: const Color(0xFF10B981),
                    onChanged: (val) async {
                      await ApiService.toggleStaffStatus(staff['staff_number'], val);
                    },
                  )
                ],
              ),
            ).animate().fadeIn(delay: (20 * index).ms).slideX(begin: 0.1, end: 0, delay: (20 * index).ms);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // PHASE 3: WRAP IN TAB CONTROLLER
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF020617),
        appBar: AppBar(
          backgroundColor: const Color(0xFF020617), elevation: 0,
          title: const Text('LOCAL ADMIN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 2)).animate().fadeIn(),
          leading: IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () {
              ApiService.currentBusinessId = null; ApiService.currentStaffNumber = null;
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DualLoginScreen()));
            }
          ),
          actions: [
            IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _refreshData),
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
          // THE NEW TOP TAB BAR
          bottom: const TabBar(
            indicatorColor: Color(0xFF6366F1),
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 11),
            unselectedLabelColor: Color(0xFF64748B),
            labelColor: Colors.white,
            tabs: [
              Tab(text: 'DASHBOARD'),
              Tab(text: 'STAFF ROSTER'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // TAB 1: FINANCIALS AND LEDGER
            CustomScrollView(
              slivers: [
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
                
                const SliverToBoxAdapter(child: SizedBox(height: 40))
              ],
            ),
            
            // TAB 2: STAFF ROSTER
            _buildStaffRosterTab(),
          ],
        ),
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