import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'api_service.dart';
import 'dual_login_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {

  // --- 1. PROVISION NEW STAFF ---
  void _showAddStaffSheet() {
    final _pinController = TextEditingController();
    final _nameController = TextEditingController();
    String _selectedRole = 'waiter';
    bool _isSubmitting = false;

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
                    onPressed: _isSubmitting ? null : () async {
                      if (_nameController.text.isEmpty || _pinController.text.length < 4) return;
                      setSheetState(() => _isSubmitting = true);
                      try {
                        await ApiService.createStaffMember(
                          pin: _pinController.text.trim(),
                          name: _nameController.text.trim(),
                          role: _selectedRole,
                        );
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.redAccent));
                      } finally {
                        setSheetState(() => _isSubmitting = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('SAVE USER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- 2. EDIT EXISTING STAFF ---
  void _showEditStaffSheet(Map<String, dynamic> staffMember) {
    final _nameController = TextEditingController(text: staffMember['name']);
    String _selectedRole = staffMember['role'];
    bool _isSubmitting = false;

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
                  Text('MANAGE STAFF: ${staffMember['staff_number']}', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12)),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration('FULL NAME', Icons.person_outline),
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
                    onPressed: _isSubmitting ? null : () async {
                      if (_nameController.text.isEmpty) return;
                      setSheetState(() => _isSubmitting = true);
                      try {
                        await ApiService.updateStaffProfile(
                          staffMember['staff_number'], 
                          _nameController.text.trim(), 
                          _selectedRole
                        );
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
                      } finally {
                        setSheetState(() => _isSubmitting = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('UPDATE STAFF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
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
        title: const Text('MASTER OPERATIONS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 2)).animate().fadeIn(),
        leading: IconButton(
          icon: const Icon(Icons.logout, color: Colors.redAccent),
          onPressed: () {
            ApiService.currentBusinessId = null;
            ApiService.currentStaffNumber = null;
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DualLoginScreen()));
          }
        ),
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
                ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
              },
            ),
          ),

          // Section 2: SaaS Package & Staff Limits (RESTORED)
          SliverToBoxAdapter(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: ApiService.streamStaffRoster(),
              builder: (context, snapshot) {
                int activeStaffCount = snapshot.hasData ? snapshot.data!.length : 0;
                int maxLimit = ApiService.currentBusinessMaxStaff ?? 5;
                double capacity = activeStaffCount / maxLimit;
                
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('LICENSE USAGE & UPGRADES', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.5)),
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
                              value: capacity.clamp(0.0, 1.0),
                              backgroundColor: const Color(0xFF020617),
                              color: capacity >= 1.0 ? Colors.redAccent : const Color(0xFF10B981),
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 160,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _buildPackageCard('STARTER', '5 Waiters', 'Basic Analytics\nStandard Support', const Color(0xFF64748B), false),
                            _buildPackageCard('PRO', '20 Waiters', 'Advanced Analytics\nPriority Routing', const Color(0xFF6366F1), true),
                            _buildPackageCard('ENTERPRISE', 'Unlimited', 'Dedicated Server\nCustom API Setup', const Color(0xFFF59E0B), false),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms);
              },
            ),
          ),

          // Section 3: Live Staff Management Stream (WITH INTERACTIVITY)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text('TEAM DIRECTORY (TAP TO EDIT)', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.5)),
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

                    return GestureDetector(
                      onTap: () => _showEditStaffSheet(member),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        padding: const EdgeInsets.all(16),
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
                                      Text('PIN: $pin', style: const TextStyle(color: Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: isActive,
                              activeTrackColor: const Color(0xFF10B981),
                              onChanged: (val) async {
                                await ApiService.toggleStaffStatus(pin, isActive);
                              },
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

  Widget _buildPackageCard(String title, String capacity, String perks, Color accent, bool isRecommended) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isRecommended ? accent.withValues(alpha: 0.1) : const Color(0xFF0F172A),
        border: Border.all(color: isRecommended ? accent : Colors.transparent, width: 1.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: accent, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
          const SizedBox(height: 8),
          Text(capacity, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const Spacer(),
          Text(perks, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, height: 1.4)),
          const SizedBox(height: 8),
          if (isRecommended)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(4)),
              child: const Text('RECOMMENDED', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1)),
            )
        ],
      ),
    );
  }
}