import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'admin_dashboard.dart';
import 'api_service.dart';
import 'business_registration_screen.dart';
import 'core/theme/app_colors.dart';
import 'core/widgets/app_shell.dart';
import 'guided_preview_screen.dart';
import 'offline_storage.dart';
import 'staff_login_screen.dart';
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
    backgroundColor: AppColors.bg,
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
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 470),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(26, 28, 26, 26),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 54,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const BrandLockup(compact: true),
                        const SizedBox(height: 55),
                        Text(
                          'Every payment.\nVerified with confidence.',
                          style: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                height: 1.12,
                                letterSpacing: -1.5,
                              ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Verify incoming payments and keep your business moving.',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.45,
                              ),
                        ),
                        const SizedBox(height: 34),
                        const _ReceiptIllustration(),
                        const SizedBox(height: 42),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: FilledButton(
                            onPressed: () => Navigator.of(context).push(
                              CupertinoPageRoute<void>(
                                builder: (_) =>
                                    const BusinessRegistrationScreen(),
                              ),
                            ),
                            child: const Text('Get Started'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).push(
                              CupertinoPageRoute<void>(
                                builder: (_) => const WorkspaceConnectScreen(),
                              ),
                            ),
                            child: const Text('Connect to Existing Workspace'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).push(
                              CupertinoPageRoute<void>(
                                builder: (_) => const GuidedPreviewScreen(),
                              ),
                            ),
                            child: const Text('Explore Preview'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ReceiptIllustration extends StatelessWidget {
  const _ReceiptIllustration();
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Illustration of a verified payment',
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                CupertinoIcons.check_mark_circled_solid,
                color: AppColors.success,
                size: 29,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Payment verified',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            height: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: 17),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Amount', style: Theme.of(context).textTheme.bodyMedium),
              Flexible(
                child: Text(
                  '1,250.00 ETB',
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            'Illustrative preview',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}

class WorkspaceConnectScreen extends StatefulWidget {
  const WorkspaceConnectScreen({super.key});
  @override
  State<WorkspaceConnectScreen> createState() => _WorkspaceConnectScreenState();
}

class _WorkspaceConnectScreenState extends State<WorkspaceConnectScreen> {
  final code = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  bool owner = false;
  bool busy = false;
  bool hidden = true;
  String? error;

  @override
  void dispose() {
    code.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (owner) {
        await ApiService.signInOwner(email.text, password.text);
        final registration = await ApiService.getOwnerRegistration();
        if (!mounted) return;
        if (registration == null) {
          Navigator.of(context).pushReplacement(
            CupertinoPageRoute<void>(
              builder: (_) => const BusinessRegistrationScreen(),
            ),
          );
        } else if (registration['is_active'] == true &&
            await ApiService.startOwnerWorkspaceSession()) {
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
        } else {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            CupertinoPageRoute<void>(
              builder: (_) => OwnerActivationScreen(registration: registration),
            ),
          );
        }
      } else {
        final workspace = await ApiService.verifyBusinessCode(code.text);
        if (workspace == null) throw Exception('Workspace code was not found.');
        await DeviceStorage.lockDeviceToBusiness(
          workspace['business_id'].toString(),
          workspace['name'].toString(),
          workspace['business_code'].toString(),
        );
        await HapticFeedback.selectionClick();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          CupertinoPageRoute<void>(builder: (_) => const StaffLoginScreen()),
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

  Future<void> _recover() async {
    if (!email.text.contains('@')) {
      setState(() => error = 'Enter your owner email first.');
      return;
    }
    try {
      await ApiService.sendOwnerRecovery(email.text);
      if (mounted) {
        setState(
          () => error = 'If this email has an owner account, recovery instructions are on their way.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Recovery is unavailable. Check your connection and try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Welcome back')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: ListView(
            padding: const EdgeInsets.all(26),
            children: [
              const BrandMark(size: 52),
              const SizedBox(height: 28),
              Text(
                'Sign in to your workspace',
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                owner
                    ? 'Use the email you registered as the business owner.'
                    : 'Enter the workspace code your business gave you.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 28),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Team member')),
                  ButtonSegment(value: true, label: Text('Business owner')),
                ],
                selected: {owner},
                onSelectionChanged: (value) => setState(() {
                  owner = value.first;
                  error = null;
                }),
              ),
              const SizedBox(height: 28),
              if (owner) ...[
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'Email address'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: password,
                  obscureText: hidden,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'Password',
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
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _recover,
                    child: const Text('Forgot password?'),
                  ),
                ),
              ] else
                TextField(
                  controller: code,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Workspace code',
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
              const SizedBox(height: 22),
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: busy ? null : _submit,
                  child: busy
                      ? const CircularProgressIndicator()
                      : Text(owner ? 'Sign In' : 'Continue'),
                ),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (_) => const BusinessRegistrationScreen(),
                  ),
                ),
                child: const Text('Register your business'),
              ),
            ],
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
              Text(
                registration['is_active'] == true ? 'Your workspace is ready.' : 'Registration received. Your selected plan is awaiting activation. No payment has been charged in the app.',
              ),
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
                child: Text(busy ? 'Checking…' : 'Check activation'),
              ),
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
