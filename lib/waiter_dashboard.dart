import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart'; // Added flutter_animate
import 'modern_scanner.dart';
import 'localization_service.dart';

class WaiterDashboard extends StatefulWidget {
  const WaiterDashboard({super.key});

  @override
  State<WaiterDashboard> createState() => _WaiterDashboardState();
}

class _WaiterDashboardState extends State<WaiterDashboard> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final List<Map<String, dynamic>> _myScans = [
    {'id': 'TXN-8842', 'amount': '1,250 ETB', 'status': 'cleared'},
    {'id': 'TXN-9931', 'amount': '450 ETB', 'status': 'pending'},
    {'id': 'TXN-7112', 'amount': '900 ETB', 'status': 'rejected'},
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    if (status == 'cleared') return const Color(0xFF10B981);
    if (status == 'pending') return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  void _showBankSelectionSheet(BuildContext context) {
    final List<Map<String, dynamic>> banks = [
      {'name': 'Telebirr', 'endpoint': '/verify-telebirr', 'color': const Color(0xFF0EA5E9)},
      {'name': 'CBE', 'endpoint': '/verify-cbe', 'color': const Color(0xFFA855F7)},
      {'name': 'CBE Birr', 'endpoint': '/verify-cbebirr', 'color': const Color(0xFFF97316)},
      {'name': 'Dashen', 'endpoint': '/verify-dashen', 'color': const Color(0xFFF59E0B)},
      {'name': 'Bank of Abyssinia', 'endpoint': '/verify-abyssinia', 'color': const Color(0xFFEAB308)},
      {'name': 'M-Pesa', 'endpoint': '/verify-mpesa', 'color': const Color(0xFF22C55E)},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('TARGET BANK', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12)),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 2.5,
                ),
                itemCount: banks.length,
                itemBuilder: (context, index) {
                  final bank = banks[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context); 
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ModernScannerScreen(
                            targetBank: bank['name'],
                            targetEndpoint: bank['endpoint'],
                          )
                        )
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: bank['color'].withValues(alpha: 0.5), width: 2),
                      ),
                      child: Center(
                        child: Text(
                          bank['name'],
                          style: TextStyle(color: bank['color'], fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF020617),
        elevation: 0,
        title: Row(
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: _pulseAnimation.value),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF10B981).withValues(alpha: _pulseAnimation.value * 0.5), blurRadius: 8, spreadRadius: 2)
                    ]
                  ),
                );
              },
            ),
            const SizedBox(width: 12),
            Text(loc.translate('waiter_dashboard'), style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 16)),
          ],
        ).animate().fadeIn(duration: 500.ms), // Animated Appbar Title
        leading: IconButton(icon: const Icon(CupertinoIcons.back), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            decoration: const BoxDecoration(
              color: Color(0xFF020617),
              border: Border(bottom: BorderSide(color: Color(0xFF1E293B), width: 2))
            ),
            child: GestureDetector(
              onTap: () => _showBankSelectionSheet(context), 
              child: Container(
                height: MediaQuery.of(context).size.height * 0.35, 
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                    begin: Alignment.topLeft, 
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.4), blurRadius: 30, spreadRadius: 5)]
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(CupertinoIcons.camera_viewfinder, color: Colors.white, size: 80),
                    const SizedBox(height: 24),
                    Text(loc.translate('scan_receipt'), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 2)),
                  ],
                ),
              ),
            ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack).fadeIn(duration: 500.ms), // Animated Big Button
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(loc.translate('my_scans'), style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 14))
                      .animate().fadeIn(delay: 300.ms), // Animated Header
                  const SizedBox(height: 16),
                  
                  if (_myScans.isEmpty)
                    Expanded(child: Center(child: Text(loc.translate('no_scans'), style: const TextStyle(color: Color(0xFF64748B))))),
                    
                  if (_myScans.isNotEmpty)
                    Expanded(
                      child: ListView.builder(
                        itemCount: _myScans.length,
                        itemBuilder: (context, index) {
                          final scan = _myScans[index];
                          final statusColor = _getStatusColor(scan['status']);
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF334155))
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(scan['amount'], style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text('ID: ${scan['id']}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                                  child: Row(
                                    children: [
                                      Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                                      const SizedBox(width: 8),
                                      Text(loc.translate(scan['status']), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                    ],
                                  ),
                                )
                              ],
                            ),
                          ).animate() // Staggered List Animation
                           .fadeIn(delay: (50 * index).ms, duration: 300.ms)
                           .slideY(begin: 0.2, end: 0, delay: (50 * index).ms, curve: Curves.easeOutQuad);
                        },
                      ),
                    )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}