import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'admin_dashboard.dart';
import 'api_service.dart';
import 'business_registration_screen.dart';
import 'core/config/app_variant.dart';
import 'core/theme/app_colors.dart';
import 'core/widgets/entry_components.dart';
import 'iphone/interactive_preview_screen.dart';
import 'iphone/entry_auth_flow.dart';
import 'owner_historical_receipts_screen.dart';
export 'iphone/entry_auth_flow.dart'
    show WorkspaceConnectScreen, OwnerSignInScreen;
import 'workspace_home_screen.dart';

final GlobalKey<NavigatorState> chekmiNavigatorKey =
    GlobalKey<NavigatorState>();

class OwnerPasswordRecoveryScreen extends StatefulWidget {
  const OwnerPasswordRecoveryScreen({super.key});
  @override
  State<OwnerPasswordRecoveryScreen> createState() =>
      _OwnerPasswordRecoveryScreenState();
}

class _OwnerPasswordRecoveryScreenState
    extends State<OwnerPasswordRecoveryScreen> {
  final password = TextEditingController();
  bool busy = false;
  bool hidden = true;
  String? error;

  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (password.text.length < 10) {
      setState(() => error = 'Use at least 10 characters.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ApiService.updateOwnerPassword(password.text);
      await ApiService.signOutOwner();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        CupertinoPageRoute<void>(
          builder: (_) => const WorkspaceConnectScreen(),
        ),
        (_) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reset password')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: ListView(
            padding: const EdgeInsets.all(26),
            children: [
              Text(
                'Secure your owner account',
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              const Text('Choose a new password, then sign in again.'),
              const SizedBox(height: 24),
              TextField(
                controller: password,
                obscureText: hidden,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: 'New password',
                  suffixIcon: IconButton(
                    tooltip: hidden ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => hidden = !hidden),
                    icon: Icon(
                      hidden
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: busy ? null : _save,
                child: Text(busy ? 'Saving…' : 'Save new password'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class LaunchSplashScreen extends StatefulWidget {
  const LaunchSplashScreen({super.key, required this.destination});
  final Widget destination;
  @override
  State<LaunchSplashScreen> createState() => _LaunchSplashScreenState();
}

class _LaunchSplashScreenState extends State<LaunchSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
    } else {
      _motion.forward().whenComplete(_finish);
    }
  }

  void _finish() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (_, animation, _) => widget.destination,
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: EntryColors.background,
    body: Center(
      child: FadeTransition(
        opacity: CurvedAnimation(parent: _motion, curve: Curves.easeOutCubic),
        child: ScaleTransition(
          scale: Tween<double>(begin: .9, end: 1).animate(
            CurvedAnimation(parent: _motion, curve: Curves.easeOutCubic),
          ),
          child: Image.asset(
            'assets/branding/chekmi_mark_256.png',
            width: 168,
            height: 168,
            fit: BoxFit.contain,
          ),
        ),
      ),
    ),
  );
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) => ChekmiEntryTheme(
    child: Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(23, 26, 23, 25),
                child: SizedBox(
                  height: constraints.maxHeight < 630
                      ? 630
                      : constraints.maxHeight - 51,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const EntryBrandMark(size: 73, wordmark: true),
                      const Spacer(flex: 3),
                      const Text(
                        'Payments,',
                        style: TextStyle(
                          color: EntryColors.text,
                          fontSize: 48,
                          height: 1.02,
                          letterSpacing: -2.8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Text(
                        'verified.',
                        style: TextStyle(
                          color: EntryColors.orange,
                          fontSize: 48,
                          height: 1.02,
                          letterSpacing: -2.8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Container(
                        width: 42,
                        height: 3,
                        decoration: BoxDecoration(
                          color: EntryColors.blue,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const Spacer(flex: 2),
                      EntryActionButton(
                        icon: CupertinoIcons.building_2_fill,
                        label: 'Get Started',
                        onPressed: () => Navigator.of(context).push(
                          CupertinoPageRoute<void>(
                            builder: (_) => const BusinessRegistrationScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 11),
                      EntryActionButton(
                        icon: CupertinoIcons.link,
                        label: 'Connect Workspace',
                        outlined: true,
                        onPressed: () => Navigator.of(context).push(
                          CupertinoPageRoute<void>(
                            builder: (_) => const WorkspaceConnectScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: TextButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            CupertinoPageRoute<void>(
                              builder: (_) => const InteractivePreviewScreen(),
                            ),
                          ),
                          icon: const Icon(CupertinoIcons.eye, size: 17),
                          label: const Text('Explore Preview'),
                          style: TextButton.styleFrom(
                            foregroundColor: EntryColors.muted,
                            minimumSize: const Size(170, 44),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class OwnerActivationScreen extends StatefulWidget {
  const OwnerActivationScreen({super.key, required this.registration});
  final Map<String, dynamic> registration;
  @override
  State<OwnerActivationScreen> createState() => _OwnerActivationScreenState();
}

class _OwnerActivationScreenState extends State<OwnerActivationScreen> {
  late Map<String, dynamic> registration = widget.registration;
  bool busy = false;
  String? error;

  String get statusMessage => switch (registration['subscription_status']) {
    'pending_activation' => 'Registration received. Plan activation is pending. No payment was charged in the app.',
    'overdue' || 'grace_period' =>
      'Your subscription needs attention. Contact support to renew.',
    'cancelled' ||
    'suspended' => 'Workspace access is paused. Contact support.',
    _ =>
      registration['is_active'] == true
          ? 'Workspace access is unavailable. Check its status or contact support.'
          : 'Workspace access is restricted. Contact support.',
  };

  Future<void> _refresh() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final current = await ApiService.getOwnerRegistration();
      if (current == null) throw Exception('Registration was not found.');
      if (!mounted) return;
      setState(() => registration = current);
      if (current['is_active'] == true) {
        if (!await ApiService.startOwnerWorkspaceSession()) {
          throw Exception('Could not open your workspace.');
        }
        if (!mounted) return;
        final profile = ApiService.currentWorkspaceProfile;
        Navigator.of(context).pushAndRemoveUntil(
          CupertinoPageRoute<void>(
            builder: (_) => profile != null && !profile.isRestaurant
                ? WorkspaceHomeScreen(profile: profile)
                : const AdminDashboard(),
          ),
          (_) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Your workspace')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: ListView(
            padding: const EdgeInsets.all(26),
            children: [
              const Icon(
                CupertinoIcons.clock_fill,
                size: 48,
                color: AppColors.primary,
              ),
              const SizedBox(height: 26),
              Text(
                registration['business_name']?.toString() ?? 'Your business',
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(statusMessage),
              const SizedBox(height: 18),
              SelectableText(
                'Workspace code: ${registration['business_code'] ?? '—'}',
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 15),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 30),
              FilledButton(
                onPressed: busy ? null : _refresh,
                child: Text(busy ? 'Checking…' : 'Check status'),
              ),
              if (AppVariant.ownerArchiveAvailable) ...[
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (_) => const OwnerHistoricalReceiptsScreen(),
                    ),
                  ),
                  child: const Text('View past receipts'),
                ),
              ],
              TextButton(
                onPressed: () async {
                  await ApiService.signOutOwner();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    CupertinoPageRoute<void>(
                      builder: (_) => const WelcomeScreen(),
                    ),
                    (_) => false,
                  );
                },
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
