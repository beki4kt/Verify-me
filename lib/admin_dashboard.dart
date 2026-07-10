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
  
  String _selectedTimeRange = 'Today'; // Time filter state

  @override
  void initState() {
    super.initState();
    _ticketsStream = ApiService.streamTodayTickets();
    _staffStream = ApiService.streamStaffRoster();
  }

  // --- THE UX GATE: Dynamic Roles ---
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
    if (bank.toLowerCase().contains('abyssinia')) return const Color(0xFFEAB308);
    if (bank.toLowerCase().contains('m-pesa')) return const Color(0xFF22C55E);
    return const Color(0xFF64748B);
  }

  // --- STAFF PROVISIONING (Bulletproof) ---
  void _showAddStaffSheet() {
    final _pinController = TextEditingController();
    final _nameController = TextEditingController();
    final _phoneController = TextEditingController();
    final _passwordController = TextEditingController();
    String _selectedRole = 'waiter';
    bool _isSubmitting = false;

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
                      decoration: _buildInputDecoration('SYSTEM ROLE', Icons.work),
                      items: _getAvailableRoles(),
                      onChanged: (val) => setSheetState(() => _selectedRole = val!),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : () async {
                        if (_nameController.text.isEmpty || _pinController.text.length < 4 || _phoneController.text.isEmpty || _passwordController.text.isEmpty) return;
                        setSheetState(() => _isSubmitting = true);
                        try {
                          await ApiService.createStaffMember(
                            pin: _pinController.text.trim(), name: _nameController.text.trim(),
                            phone: _phoneController.text.trim(), password: _passwordController.text.trim(), role: _selectedRole,
                          );
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

  void _showEditStaffSheet(Map<String, dynamic> staffMember) {
    final _nameController = TextEditingController(text: staffMember['name']?.toString() ?? '');
    final _phoneController = TextEditingController(text: staffMember['phone_number']?.toString() ?? '');
    final _passwordController = TextEditingController(text: staffMember['password']?.toString() ?? '');
    String _selectedRole = staffMember['role'];
    
    if (_selectedRole == 'cashier' && ApiService.currentBusinessHasCashier != true) _selectedRole = 'waiter'; 
    bool _isSubmitting = false;

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
                    TextField(controller: _nameController, style: const TextStyle(color: Colors.white), decoration: _buildInputDecoration('FULL NAME', Icons.person_outline)),
                    const SizedBox(height: 16),
                    TextField(controller: _phoneController, keyboardType: TextInputType.phone, style: const TextStyle(color: Colors.white), decoration: _buildInputDecoration('PHONE NUMBER', Icons.phone)),
                    const SizedBox(height: 16),
                    TextField(controller: _passwordController, style: const TextStyle(color: Colors.white), decoration: _buildInputDecoration('PASSWORD', Icons.lock)),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedRole, dropdownColor: const Color(0xFF0F172A),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      decoration: _buildInputDecoration('SYSTEM ROLE', Icons.work),
                      items: _getAvailableRoles(), 
                      onChanged: (val) => setSheetState(() => _selectedRole = val!),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : () async {
                        if (_nameController.text.isEmpty || _phoneController.text.isEmpty || _passwordController.text.isEmpty) return;
                        setSheetState(() => _isSubmitting = true);
                        try {
                          await ApiService.updateStaffProfile(
                            staffMember['staff_number'].toString(), _nameController.text.trim(),
                            _phoneController.text.trim(), _passwordController.text.trim(), _selectedRole
                          );
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
                        } finally {
                          setSheetState(() => _isSubmitting = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('UPDATE STAFF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
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
        actions: [IconButton(icon: const Icon(Icons.person_add_alt_1, color: Color(0xFF6366F1)), onPressed: _showAddStaffSheet)],
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
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
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

          // FINANCIAL ANALYTICS & BANK BREAKDOWN
          SliverToBoxAdapter(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _ticketsStream,
              builder: (context, snapshot) {
                double totalRevenue = 0;
                int pendingCount = 0;
                Map<String, double> bankTotals = {}; // Tracks deposits per bank

                if (snapshot.hasData) {
                  for (var ticket in snapshot.data!) {
                    // Note: This operates on the live stream. In the future, we will fetch historical data when Weekly/Monthly is tapped.
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
                      
                      // THE BANK SETTLEMENT BREAKDOWN
                      const Text('BANK DEPOSIT BREAKDOWN', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.5)),
                      const SizedBox(height: 16),
                      if (bankTotals.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(24)),
                          child: const Center(child: Text('No verified transactions yet.', style: TextStyle(color: Color(0xFF64748B)))),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(24)),
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

          // SaaS Usage UI
          SliverToBoxAdapter(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _staffStream,
              builder: (context, snapshot) {
                int activeStaffCount = snapshot.hasData ? snapshot.data!.length : 0;
                int maxLimit = ApiService.currentBusinessMaxStaff ?? 5;
                double capacity = activeStaffCount / maxLimit;
                
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('LICENSE USAGE', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.5)),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(20)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Staff Seats Provisioned', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                Text('$activeStaffCount / $maxLimit', style: TextStyle(color: capacity >= 1.0 ? Colors.redAccent : const Color(0xFF10B981), fontWeight: FontWeight.w900)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            LinearProgressIndicator(
                              value: capacity.clamp(0.0, 1.0), backgroundColor: const Color(0xFF020617),
                              color: capacity >= 1.0 ? Colors.redAccent : const Color(0xFF10B981),
                              minHeight: 8, borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms);
              },
            ),
          ),

          // Team Directory
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text('TEAM DIRECTORY (TAP TO EDIT)', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.5)),
            ),
          ),

          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _staffStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator(color: Color(0xFF6366F1)))));
              if (!snapshot.hasData || snapshot.data!.isEmpty) return const SliverToBoxAdapter(child: Center(child: Text('No staff members registered.', style: TextStyle(color: Colors.white30))));

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final member = snapshot.data![index];
                    final pin = member['staff_number'].toString();
                    final name = member['name'].toString();
                    final role = member['role'].toString().toUpperCase();
                    final phone = member['phone_number']?.toString() ?? 'No Phone';
                    final isActive = member['is_active'] as bool? ?? true;

                    return GestureDetector(
                      onTap: () => _showEditStaffSheet(member),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: isActive ? const Color(0xFF6366F1).withValues(alpha: 0.1) : Colors.black12,
                              child: Icon(Icons.person, color: isActive ? const Color(0xFF6366F1) : Colors.white24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: TextStyle(color: isActive ? Colors.white : Colors.white38, fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(color: const Color(0xFF020617), borderRadius: BorderRadius.circular(8)),
                                        child: Text(role, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(phone, style: const TextStyle(color: Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: isActive, activeTrackColor: const Color(0xFF10B981),
                              onChanged: (val) async => await ApiService.toggleStaffStatus(pin, isActive),
                            )
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: (50 * index).ms).slideX(begin: 0.1, end: 0, delay: (50 * index).ms);
                  },
                  childCount: snapshot.data!.length,
                ),
              );
            },
          )
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