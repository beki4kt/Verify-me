import 'package:flutter/material.dart';

import 'business_gateway_screen.dart';
import 'core/theme/app_spacing.dart';
import 'core/widgets/app_shell.dart';

/// The former in-app platform console relied on a public tenant table and a
/// plaintext super-admin password. It stays closed until a separately hosted,
/// MFA-protected operator console is deployed.
class SuperAdminDashboard extends StatelessWidget {
  const SuperAdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackdrop(
        maxWidth: 620,
        child: Center(
          child: GlassPanel(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.admin_panel_settings_outlined,
                  size: 52,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Operator console unavailable',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Platform administration has been removed from the public app. Use the protected operator console with MFA.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton.icon(
                  onPressed: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BusinessGatewayScreen(),
                    ),
                    (_) => false,
                  ),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Return to workspace login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
