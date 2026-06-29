import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'cashier_dashboard.dart';
import 'waiter_dashboard.dart';
import 'localization_service.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  Widget _buildRoleCard(BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.5), width: 2),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.1), blurRadius: 20, spreadRadius: 2),
          ]
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                    child: Text(loc.translate('app_title'), style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold, letterSpacing: 2)),
                  ),
                  // Language Toggle Button
                  GestureDetector(
                    onTap: () => loc.toggleLanguage(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF64748B)),
                        borderRadius: BorderRadius.circular(20)
                      ),
                      child: Text(
                        loc.isAmharic ? 'EN' : 'አማ',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 24),
              Text(loc.translate('select_workspace'), style: const TextStyle(color: Colors.white, fontSize: 40, height: 1.1, fontWeight: FontWeight.w900, letterSpacing: 1)),
              const SizedBox(height: 48),
              
              _buildRoleCard(
                context,
                title: loc.translate('waiter'),
                subtitle: loc.translate('waiter_sub'),
                icon: CupertinoIcons.camera_viewfinder,
                color: const Color(0xFF6366F1), 
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WaiterDashboard())),
              ),
              
              _buildRoleCard(
                context,
                title: loc.translate('cashier'),
                subtitle: loc.translate('cashier_sub'),
                icon: CupertinoIcons.desktopcomputer,
                color: const Color(0xFF10B981), 
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CashierDashboard())),
              ),
              
              _buildRoleCard(
                context,
                title: loc.translate('admin'),
                subtitle: loc.translate('admin_sub'),
                icon: CupertinoIcons.lock_shield,
                color: const Color(0xFFF59E0B), 
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Admin Web Portal is handled by Henok.')));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}