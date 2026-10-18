import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'api_service.dart';
import 'admin_dashboard.dart';
import 'cashier_dashboard.dart';
import 'core/config/payment_context.dart';
import 'core/models/workspace_profile.dart';
import 'core/theme/app_colors.dart';
import 'core/widgets/app_shell.dart';
import 'staff_login_screen.dart';
import 'launch_experience.dart';
import 'waiter_dashboard.dart';
import 'workspace_settings_screen.dart';
import 'workspace_members_screen.dart';
import 'workspace_accounts_screen.dart';
import 'localization_service.dart';

/// One action surface composed from server-authorized capabilities. Presets
/// change copy and defaults; they do not select independent app trees.
class WorkspaceHomeScreen extends StatefulWidget {
  const WorkspaceHomeScreen({super.key, required this.profile});

  final WorkspaceProfile profile;

  @override
  State<WorkspaceHomeScreen> createState() => _WorkspaceHomeScreenState();
}

class _WorkspaceHomeScreenState extends State<WorkspaceHomeScreen> {
  WorkspaceProfile get profile =>
      ApiService.currentWorkspaceProfile ?? widget.profile;

  Future<void> _open(BuildContext context, Widget screen) async {
    await Navigator.of(context)
        .push(CupertinoPageRoute<void>(builder: (_) => screen));
    if (!mounted || !context.mounted) return;
    if (ApiService.currentWorkspaceProfile?.isRestaurant == true &&
        !widget.profile.isRestaurant) {
      final destination = switch (ApiService.currentUserRole) {
        'admin' => const AdminDashboard(),
        'cashier' => const CashierDashboard(),
        _ => const WaiterDashboard(),
      };
      await Navigator.of(
        context,
      ).pushReplacement(CupertinoPageRoute<void>(builder: (_) => destination));
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canVerify = profile.can('verify_payment');
    final canReview = profile.requiresReview && profile.can('review_payment');
    final canViewLedger = profile.can('view_ledger');
    final canManage =
        profile.can('manage_workspace') ||
        profile.can('manage_receiving_accounts');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chekmi'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(CupertinoIcons.square_arrow_right),
            onPressed: () async {
              final owner = ApiService.hasOwnerAuth;
              if (owner) {
                await ApiService.signOutOwner();
              } else {
                await ApiService.logoutStaff();
              }
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                CupertinoPageRoute<void>(
                  builder: (_) =>
                      owner ? const WelcomeScreen() : const StaffLoginScreen(),
                ),
                (_) => false,
              );
            },
          ),
        ],
      ),
      body: AppBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
            children: [
              Text(
                context.tr('Your workspace'),
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: AppColors.primary),
              ),
              const SizedBox(height: 8),
              Text(
                'Payments, clearly handled.',
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                canVerify
                    ? profile.requiresReview
                          ? 'Verify a receipt, then review it with your team.'
                          : 'Verify a receipt and keep a clear record of what happened.'
                    : canReview
                    ? 'Review payments waiting for your decision.'
                    : 'Manage the payment tools your team uses.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 26),
              if (canVerify)
                _HomeAction(
                  icon: CupertinoIcons.viewfinder,
                  title: 'Verify Payment',
                  subtitle: 'Scan a receipt or enter its reference',
                  emphasized: true,
                  onTap: () => _open(
                    context,
                    WaiterDashboard(workspaceProfile: profile, initialTab: 1),
                  ),
                ),
              if (canReview) ...[
                const SizedBox(height: 12),
                _HomeAction(
                  icon: CupertinoIcons.check_mark_circled,
                  title: 'Review Payments',
                  subtitle: 'Complete payments waiting for a decision',
                  onTap: () => _open(
                    context,
                    CashierDashboard(workspaceProfile: profile),
                  ),
                ),
              ],
              if (canViewLedger) ...[
                const SizedBox(height: 12),
                _HomeAction(
                  icon: CupertinoIcons.doc_text,
                  title: 'Activity & ledger',
                  subtitle: 'See verified and completed payments',
                  onTap: () => _open(
                    context,
                    CashierDashboard(workspaceProfile: profile, readOnly: true),
                  ),
                ),
              ] else if (canVerify) ...[
                const SizedBox(height: 12),
                _HomeAction(
                  icon: CupertinoIcons.clock,
                  title: 'Activity',
                  subtitle: 'Your recent verifications',
                  onTap: () => _open(
                    context,
                    WaiterDashboard(workspaceProfile: profile),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              StreamBuilder<Map<String, dynamic>>(
                stream: ApiService.streamCurrentBusiness(),
                builder: (context, snapshot) {
                  final accounts = snapshot.data?['bank_accounts'];
                  final configured = accounts is Map
                      ? accounts.entries
                            .where(
                              (entry) =>
                                  entry.value?.toString().trim().isNotEmpty ==
                                  true,
                            )
                            .toList()
                      : const [];
                  return Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('Receiving account'),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          configured.isEmpty
                              ? 'Ask the workspace owner to add an account before verifying.'
                              : configured
                                    .map(
                                      (entry) =>
                                          '${entry.key.toString().replaceAll('_number', '')}: ${entry.value}',
                                    )
                                    .join('  ·  '),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  );
                },
              ),
              if (canManage) ...[
                const SizedBox(height: 18),
                _HomeAction(
                  icon: CupertinoIcons.slider_horizontal_3,
                  title: profile.can('manage_workspace')
                      ? 'Settings'
                      : 'Receiving accounts',
                  subtitle: profile.can('manage_workspace')
                      ? 'How this workspace handles payments'
                      : 'Manage payment destinations',
                  onTap: () => _open(
                    context,
                    profile.can('manage_workspace')
                        ? WorkspaceSettingsScreen(profile: profile)
                        : const WorkspaceAccountsScreen(),
                  ),
                ),
              ],
              if (profile.can('manage_members')) ...[
                const SizedBox(height: 12),
                _HomeAction(
                  icon: CupertinoIcons.person_2,
                  title: 'Members',
                  subtitle: 'See and manage payment permissions',
                  onTap: () => _open(context, const WorkspaceMembersScreen()),
                ),
              ],
              if (profile.defaultReferenceKind != 'none') ...[
                const SizedBox(height: 20),
                Text(
                  'Default reference: ${PaymentContextKind.fromStorage(profile.defaultReferenceKind).label}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeAction extends StatelessWidget {
  const _HomeAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.emphasized = false,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: '${context.tr(title)}. ${context.tr(subtitle)}',
      child: Material(
        color: emphasized ? AppColors.primary : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: emphasized ? Colors.white : AppColors.primary,
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr(title),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: emphasized ? Colors.white : null,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: emphasized ? Colors.white70 : null,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  CupertinoIcons.chevron_forward,
                  size: 16,
                  color: emphasized ? Colors.white70 : scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
