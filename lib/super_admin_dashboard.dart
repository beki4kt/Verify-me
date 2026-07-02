import 'package:flutter/material.dart';
import 'api_service.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {

  void _showProvisioningSheet() {
    final bName = TextEditingController();
    final bTier = TextEditingController(text: 'pro');
    final bMaxStaff = TextEditingController(text: '10');
    
    final aName = TextEditingController();
    final aPhone = TextEditingController();
    final aPassword = TextEditingController();
    final aPin = TextEditingController();

    bool isSubmitting = false;

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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('PROVISION NEW RESTAURANT', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12)),
                    const SizedBox(height: 16),
                    
                    // Business Details
                    TextField(controller: bName, style: const TextStyle(color: Colors.white), decoration: _inputDeco('BUSINESS NAME')),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: bTier, style: const TextStyle(color: Colors.white), decoration: _inputDeco('TIER (starter/pro)'))),
                        const SizedBox(width: 12),
                        Expanded(child: TextField(controller: bMaxStaff, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: _inputDeco('STAFF LIMIT'))),
                      ],
                    ),
                    const Divider(color: Colors.white24, height: 48),
                    
                    // Admin Details
                    const Text('MASTER ADMIN CREDENTIALS', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12)),
                    const SizedBox(height: 16),
                    TextField(controller: aName, style: const TextStyle(color: Colors.white), decoration: _inputDeco('ADMIN FULL NAME')),
                    const SizedBox(height: 12),
                    TextField(controller: aPhone, keyboardType: TextInputType.phone, style: const TextStyle(color: Colors.white), decoration: _inputDeco('PHONE NUMBER (+251...)')),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(flex: 2, child: TextField(controller: aPassword, style: const TextStyle(color: Colors.white), decoration: _inputDeco('PASSWORD'))),
                        const SizedBox(width: 12),
                        Expanded(flex: 1, child: TextField(controller: aPin, keyboardType: TextInputType.number, maxLength: 4, style: const TextStyle(color: Colors.white), decoration: _inputDeco('4-DIGIT PIN').copyWith(counterText: ""))),
                      ],
                    ),
                    const SizedBox(height: 32),
                    
                    ElevatedButton(
                      onPressed: isSubmitting ? null : () async {
                        if (bName.text.isEmpty || aPhone.text.isEmpty || aPassword.text.isEmpty || aPin.text.isEmpty) return;
                        setSheetState(() => isSubmitting = true);
                        try {
                          await ApiService.provisionNewBusiness(
                            businessName: bName.text.trim(),
                            packageTier: bTier.text.trim(),
                            maxStaff: int.tryParse(bMaxStaff.text.trim()) ?? 5,
                            adminName: aName.text.trim(),
                            adminPhone: aPhone.text.trim(),
                            adminPassword: aPassword.text.trim(),
                            adminPin: aPin.text.trim(),
                          );
                          if (mounted) Navigator.pop(context);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                        } finally {
                          setSheetState(() => isSubmitting = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: isSubmitting 
                          ? const CircularProgressIndicator(color: Colors.black)
                          : const Text('CREATE TENANT', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
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

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
      filled: true,
      fillColor: const Color(0xFF020617),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('GOD MODE: SYSTEM CONTROL', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 2)),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: _showProvisioningSheet,
                    icon: const Icon(Icons.add_business, color: Colors.black),
                    label: const Text('PROVISION NEW RESTAURANT', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text('CLIENT DIRECTORY & KILL SWITCHES', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                ],
              ),
            ),
          ),
          
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: ApiService.streamAllBusinesses(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const SliverToBoxAdapter(child: Center(child: Text('No active tenants.', style: TextStyle(color: Colors.white30))));
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final business = snapshot.data![index];
                    final bId = business['business_id'].toString();
                    final bName = business['name'].toString();
                    final isActive = business['is_active'] as bool? ?? true;
                    final tier = business['package_tier'].toString().toUpperCase();

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        children: [
                          Icon(Icons.business, color: isActive ? const Color(0xFF3B82F6) : Colors.white24, size: 32),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(bName, style: TextStyle(color: isActive ? Colors.white : Colors.white38, fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 4),
                                Text('TIER: $tier | LIMIT: ${business['max_staff_limit']}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: isActive,
                            activeTrackColor: const Color(0xFF3B82F6),
                            onChanged: (val) async {
                              await ApiService.toggleBusinessStatus(bId, isActive);
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
}