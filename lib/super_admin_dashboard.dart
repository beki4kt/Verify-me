import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_service.dart';
import 'business_gateway_screen.dart';
import 'offline_storage.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  late Stream<List<Map<String, dynamic>>> _businessStream;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  // REFRESH ENGINE FOR TENANT LIST
  void _refreshData() {
    setState(() {
      _businessStream = Supabase.instance.client
          .from('businesses')
          .stream(primaryKey: ['business_id'])
          .order('created_at', ascending: false);
    });
  }

  void _showCreateTenantSheet() {
    final nameController = TextEditingController();
    final codeController = TextEditingController(); // NEW: Business Code Controller
    final addressController = TextEditingController();
    final adminPinController = TextEditingController();
    final adminNameController = TextEditingController();
    final adminPhoneController = TextEditingController();
    final adminPasswordController = TextEditingController();
    
    String selectedTier = 'starter';
    int staffLimit = 5;
    bool hasCashier = false;
    bool isSubmitting = false;
    String? errorMessage; 

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
                    const Text('PROVISION NEW TENANT', style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12)),
                    const SizedBox(height: 24),
                    
                    TextField(controller: nameController, style: const TextStyle(color: Colors.white), decoration: _buildInputDecoration('RESTAURANT NAME', Icons.business)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: codeController, 
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2), 
                      decoration: _buildInputDecoration('UNIQUE TENANT CODE (e.g. FIESTA)', Icons.vpn_key)
                    ),
                    const SizedBox(height: 16),
                    TextField(controller: addressController, style: const TextStyle(color: Colors.white), decoration: _buildInputDecoration('LOCATION', Icons.location_on)),
                    const SizedBox(height: 24),
                    
                    const Text('SAAS TIER', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 10)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedTier, dropdownColor: const Color(0xFF0F172A), style: const TextStyle(color: Colors.white),
                      decoration: _buildInputDecoration('', Icons.layers),
                      items: const [
                        DropdownMenuItem(value: 'starter', child: Text('Starter (1,500 ETB) - No Cashier')),
                        DropdownMenuItem(value: 'pro', child: Text('Pro (4,000 ETB) - Unlimited')),
                      ],
                      onChanged: (val) {
                        setSheetState(() {
                          selectedTier = val!;
                          if (selectedTier == 'starter') { staffLimit = 5; hasCashier = false; }
                          else { staffLimit = 50; hasCashier = true; }
                        });
                      },
                    ),
                    const SizedBox(height: 24),

                    const Text('ROOT ADMIN ACCOUNT', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 10)),
                    const SizedBox(height: 8),
                    TextField(controller: adminNameController, style: const TextStyle(color: Colors.white), decoration: _buildInputDecoration('ADMIN NAME', Icons.person)),
                    const SizedBox(height: 12),
                    TextField(controller: adminPhoneController, keyboardType: TextInputType.phone, style: const TextStyle(color: Colors.white), decoration: _buildInputDecoration('ADMIN PHONE', Icons.phone)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(flex: 2, child: TextField(controller: adminPasswordController, style: const TextStyle(color: Colors.white), decoration: _buildInputDecoration('PASSWORD', Icons.lock))),
                        const SizedBox(width: 12),
                        Expanded(flex: 1, child: TextField(controller: adminPinController, keyboardType: TextInputType.number, maxLength: 4, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2), decoration: _buildInputDecoration('ID', Icons.badge).copyWith(counterText: ""))),
                      ],
                    ),
                    const SizedBox(height: 24),

                    if (errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.redAccent)),
                        child: Text(errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),

                    ElevatedButton(
                      onPressed: isSubmitting ? null : () async {
                        if (nameController.text.isEmpty || codeController.text.isEmpty || adminPinController.text.length < 4 || adminPasswordController.text.isEmpty) {
                          setSheetState(() => errorMessage = 'Please fill all fields, add a code, and use a 4-digit ID.');
                          return;
                        }
                        
                        setSheetState(() { isSubmitting = true; errorMessage = null; });
                        try {
                          // Clean architecture: Delegating to the Service Layer
                          await ApiService.provisionNewBusiness(
                            businessName: nameController.text.trim(),
                            businessCode: codeController.text.trim().toUpperCase(),
                            packageTier: selectedTier,
                            maxStaff: staffLimit,
                            hasCashier: hasCashier,
                            adminName: adminNameController.text.trim(),
                            adminPhone: adminPhoneController.text.trim(),
                            adminPassword: adminPasswordController.text.trim(),
                            adminPin: adminPinController.text.trim(),
                          );

                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          setSheetState(() => errorMessage = e.toString().replaceAll('Exception: ', ''));
                        } finally {
                          setSheetState(() => isSubmitting = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      child: isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('DEPLOY TENANT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
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

  Future<void> _handleLogout() async {
    ApiService.currentBusinessId = null;
    ApiService.currentStaffNumber = null;
    ApiService.currentUserRole = null;
    await DeviceStorage.clearDeviceLock(); // Clear any god-mode locks
    
    if (mounted) {
      Navigator.pushReplacement(context, CupertinoPageRoute(builder: (_) => const BusinessGatewayScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        title: const Text('GOD MODE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 2)).animate().fadeIn(),
        leading: IconButton(
          icon: const Icon(Icons.logout, color: Colors.redAccent),
          onPressed: _handleLogout,
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _refreshData),
          IconButton(icon: const Icon(Icons.add_business, color: Color(0xFF6366F1)), onPressed: _showCreateTenantSheet),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _businessStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('No tenants deployed.', style: TextStyle(color: Colors.white54)));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final biz = snapshot.data![index];
              final isActive = biz['is_active'] as bool? ?? true;
              final isPro = biz['subscription_tier'] == 'pro';
              final bizCode = biz['business_code'] ?? 'PENDING';

              return Container(
                margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(24), border: Border.all(color: isPro ? const Color(0xFFF59E0B).withValues(alpha: 0.3) : Colors.white10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(biz['name'].toString().toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1))),
                        Switch.adaptive(
                          value: isActive, activeTrackColor: const Color(0xFF10B981),
                          onChanged: (val) async {
                            await Supabase.instance.client.from('businesses').update({'is_active': val}).eq('business_id', biz['business_id']);
                          },
                        )
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // NEW: Display the Business Code for the Admin to see
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: const Color(0xFF020617), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF334155))),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.key, color: Color(0xFF6366F1), size: 14),
                          const SizedBox(width: 8),
                          Text('CODE: $bizCode', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 12)),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    Text('Location: ${biz['address']}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: isPro ? const Color(0xFFF59E0B).withValues(alpha: 0.1) : const Color(0xFF6366F1).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: Text(isPro ? 'PRO TIER' : 'STARTER', style: TextStyle(color: isPro ? const Color(0xFFF59E0B) : const Color(0xFF6366F1), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                        ),
                        const SizedBox(width: 12),
                        Text('Max Seats: ${biz['max_staff_limit']}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    )
                  ],
                ),
              ).animate().fadeIn(delay: (50 * index).ms).slideY(begin: 0.1, end: 0, delay: (50 * index).ms);
            },
          );
        },
      ),
    );
  }
}