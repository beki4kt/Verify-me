import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dual_login_screen.dart';

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
    final _nameController = TextEditingController();
    final _addressController = TextEditingController();
    final _adminPinController = TextEditingController();
    final _adminNameController = TextEditingController();
    final _adminPhoneController = TextEditingController();
    final _adminPasswordController = TextEditingController();
    
    String _selectedTier = 'starter';
    int _staffLimit = 5;
    bool _hasCashier = false;
    bool _isSubmitting = false;
    String? _errorMessage; // NEW: Holds visible errors

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
                    
                    TextField(controller: _nameController, style: const TextStyle(color: Colors.white), decoration: _buildInputDecoration('RESTAURANT NAME', Icons.business)),
                    const SizedBox(height: 16),
                    TextField(controller: _addressController, style: const TextStyle(color: Colors.white), decoration: _buildInputDecoration('LOCATION', Icons.location_on)),
                    const SizedBox(height: 24),
                    
                    const Text('SAAS TIER', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 10)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedTier, dropdownColor: const Color(0xFF0F172A), style: const TextStyle(color: Colors.white),
                      decoration: _buildInputDecoration('', Icons.layers),
                      items: const [
                        DropdownMenuItem(value: 'starter', child: Text('Starter (1,500 ETB) - No Cashier')),
                        DropdownMenuItem(value: 'pro', child: Text('Pro (4,000 ETB) - Unlimited')),
                      ],
                      onChanged: (val) {
                        setSheetState(() {
                          _selectedTier = val!;
                          if (_selectedTier == 'starter') { _staffLimit = 5; _hasCashier = false; }
                          else { _staffLimit = 50; _hasCashier = true; }
                        });
                      },
                    ),
                    const SizedBox(height: 24),

                    const Text('ROOT ADMIN ACCOUNT', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 10)),
                    const SizedBox(height: 8),
                    TextField(controller: _adminNameController, style: const TextStyle(color: Colors.white), decoration: _buildInputDecoration('ADMIN NAME', Icons.person)),
                    const SizedBox(height: 12),
                    TextField(controller: _adminPhoneController, keyboardType: TextInputType.phone, style: const TextStyle(color: Colors.white), decoration: _buildInputDecoration('ADMIN PHONE', Icons.phone)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(flex: 2, child: TextField(controller: _adminPasswordController, style: const TextStyle(color: Colors.white), decoration: _buildInputDecoration('PASSWORD', Icons.lock))),
                        const SizedBox(width: 12),
                        Expanded(flex: 1, child: TextField(controller: _adminPinController, keyboardType: TextInputType.number, maxLength: 4, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), decoration: _buildInputDecoration('ID', Icons.badge).copyWith(counterText: ""))),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // NEW: VISIBLE ERROR BANNER
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.redAccent)),
                        child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),

                    ElevatedButton(
                      onPressed: _isSubmitting ? null : () async {
                        if (_nameController.text.isEmpty || _adminPinController.text.length < 4 || _adminPasswordController.text.isEmpty) {
                          setSheetState(() => _errorMessage = 'Please fill all fields and use a 4-digit ID.');
                          return;
                        }
                        
                        setSheetState(() { _isSubmitting = true; _errorMessage = null; });
                        try {
                          // 1. Create Business
                          final bizResponse = await Supabase.instance.client.from('businesses').insert({
                            'name': _nameController.text.trim(),
                            'address': _addressController.text.trim(),
                            'subscription_tier': _selectedTier,
                            'max_staff_limit': _staffLimit,
                            'has_cashier_module': _hasCashier,
                            'is_active': true,
                          }).select('business_id').single();

                          // 2. Create Root Admin
                          await Supabase.instance.client.from('staff').insert({
                            'staff_number': _adminPinController.text.trim(),
                            'business_id': bizResponse['business_id'],
                            'name': _adminNameController.text.trim(),
                            'phone_number': _adminPhoneController.text.trim(),
                            'password': _adminPasswordController.text.trim(),
                            'role': 'admin',
                            'is_active': true,
                          });

                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          setSheetState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
                        } finally {
                          setSheetState(() => _isSubmitting = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('DEPLOY TENANT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
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
        title: const Text('GOD MODE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 2)).animate().fadeIn(),
        leading: IconButton(
          icon: const Icon(Icons.logout, color: Colors.redAccent),
          onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DualLoginScreen())),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _refreshData), // REFRESH BUTTON
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
                    const SizedBox(height: 8),
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