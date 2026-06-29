import 'package:flutter/material.dart';
import 'api_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _pinController = TextEditingController();
  final _nameController = TextEditingController();
  String _selectedRole = 'waiter';

  void _showAddStaffSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 24, right: 24, top: 32
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('PROVISION NEW STAFF', style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12)),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration('FULL NAME', Icons.person_outline),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    style: const TextStyle(color: Colors.white, letterSpacing: 8, fontSize: 20, fontWeight: FontWeight.bold),
                    decoration: _buildInputDecoration('4-DIGIT LOGIN PIN', Icons.lock_outline).copyWith(counterText: ""),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    dropdownColor: const Color(0xFF0F172A),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    decoration: _buildInputDecoration('SYSTEM ROLE', Icons.badge_outlined),
                    items: const [
                      DropdownMenuItem(value: 'waiter', child: Text('Waiter')),
                      DropdownMenuItem(value: 'cashier', child: Text('Cashier')),
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    ],
                    onChanged: (val) => setSheetState(() => _selectedRole = val!),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () async {
                      if (_nameController.text.isEmpty || _pinController.text.length < 4) return;
                      try {
                        await ApiService.createStaffMember(
                          pin: _pinController.text.trim(),
                          name: _nameController.text.trim(),
                          role: _selectedRole,
                        );
                        _nameController.clear();
                        _pinController.clear();
                        if (mounted) Navigator.pop(context);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('SAVE USER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
      prefixIcon: Icon(icon, color: const Color(0xFF6366F1)),
      filled: true,
      fillColor: const Color(0xFF020617),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('MASTER OPERATIONS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 2)),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1, color: Color(0xFF6366F1)),
            onPressed: _showAddStaffSheet,
          )
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Section 1: Live Analytics Stream
          SliverToBoxAdapter(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: ApiService.streamTodayTickets(),
              builder: (context, snapshot) {
                double totalRevenue = 0;
                double totalTips = 0;
                int pendingCount = 0;

                if (snapshot.hasData) {
                  for (var ticket in snapshot.data!) {
                    if (ticket['status'] == 'settled') {
                      totalRevenue += (ticket['bill_amount'] ?? 0).toDouble();
                      totalTips += (ticket['tip_amount'] ?? 0).toDouble();
                    } else {
                      pendingCount++;
                    }
                  }
                }

                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('REAL-TIME METRICS (TODAY)', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.5)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildMetricCard('REVENUE', '${totalRevenue.toStringAsFixed(0)} ETB', const Color(0xFF10B981))),
                          const SizedBox(width: 12),
                          Expanded(child: _buildMetricCard('TIPS LOGGED', '${totalTips.toStringAsFixed(0)} ETB', const Color(0xFF6366F1))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildMetricCard('OPEN TABLES CURRENTLY IN SYSTEM', '$pendingCount ACTIVE BILLS', const Color(0xFFF59E0B), isFullWidth: true),
                    ],
                  ),
                );
              },
            ),
          ),

          // Section 2: Live Staff Management Stream
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text('TEAM DIRECTORY & SECURITY CONTROL', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.5)),
            ),
          ),

          StreamBuilder<List<Map<String, dynamic>>>(
            stream: ApiService.streamStaffRoster(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator(color: Color(0xFF6366F1)))));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const SliverToBoxAdapter(child: Center(child: Text('No staff members registered.', style: TextStyle(color: Colors.white30))));
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final member = snapshot.data![index];
                    final pin = member['staff_number'].toString();
                    final name = member['name'].toString();
                    final role = member['role'].toString().toUpperCase();
                    final isActive = member['is_active'] as bool? ?? true;

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: isActive ? const Color(0xFF6366F1).withOpacity(0.1) : Colors.black12,
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
                                    Text('PIN: $pin', style: const TextStyle(color: Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: isActive,
                            activeColor: const Color(0xFF10B981),
                            onChanged: (val) async {
                              await ApiService.toggleStaffStatus(pin, isActive);
                            },
                          )
                        ],
                      ),
                    );
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

  Widget _buildMetricCard(String title, String val, Color accents, {bool isFullWidth = false}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        border: Border(left: BorderSide(color: accents, width: 4)),
      ),
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