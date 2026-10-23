import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../admin_dashboard.dart';
import '../api_service.dart';
import '../business_registration_screen.dart';
import '../core/config/app_variant.dart';
import '../core/widgets/entry_components.dart';
import '../launch_experience.dart' show OwnerActivationScreen;
import '../offline_storage.dart';
import '../staff_login_screen.dart';
import '../workspace_home_screen.dart';

/// A workspace code locates a workspace; the member still signs in separately.
class WorkspaceConnectScreen extends StatefulWidget {
  const WorkspaceConnectScreen({super.key});

  @override
  State<WorkspaceConnectScreen> createState() => _WorkspaceConnectScreenState();
}

class _WorkspaceConnectScreenState extends State<WorkspaceConnectScreen> {
  final code = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (AppVariant.isUiPreview) {
      setState(
        () => error = 'Connect to a staging workspace in the functional build.',
      );
      return;
    }
    final normalized = code.text.trim().toUpperCase();
    if (normalized.isEmpty) {
      setState(() => error = 'Enter your workspace code.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final workspace = await ApiService.verifyBusinessCode(normalized);
      if (workspace == null) throw Exception('Check the code and try again.');
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
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ChekmiEntryTheme(
    child: Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(23, 18, 23, 24),
                child: SizedBox(
                  height: constraints.maxHeight < 550
                      ? 550
                      : constraints.maxHeight - 42,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      EntryBackButton(
                        onPressed: () => Navigator.maybePop(context),
                      ),
                      const SizedBox(height: 34),
                      const EntryBrandMark(size: 55),
                      const SizedBox(height: 18),
                      const Text(
                        'Connect Workspace',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Enter your workspace code.',
                        style: TextStyle(color: EntryColors.muted),
                      ),
                      const SizedBox(height: 34),
                      const Text(
                        'Workspace code',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 9),
                      TextField(
                        controller: code,
                        autofocus: false,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => busy ? null : _continue(),
                        decoration: const InputDecoration(
                          hintText: 'Workspace code',
                          prefixIcon: Icon(CupertinoIcons.building_2_fill),
                        ),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          error!,
                          style: const TextStyle(color: EntryColors.error),
                        ),
                      ],
                      const Spacer(),
                      EntryActionButton(
                        label: 'Continue',
                        loading: busy,
                        onPressed: _continue,
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).push(
                            CupertinoPageRoute<void>(
                              builder: (_) => const OwnerSignInScreen(),
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: EntryColors.muted,
                            minimumSize: const Size(180, 44),
                          ),
                          child: const Text('Business owner sign in'),
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

/// Existing owners keep their Supabase email identity until verified phone
/// sign-in and account migration are available in the deployed Auth project.
class OwnerSignInScreen extends StatefulWidget {
  const OwnerSignInScreen({super.key});

  @override
  State<OwnerSignInScreen> createState() => _OwnerSignInScreenState();
}

class _OwnerSignInScreenState extends State<OwnerSignInScreen> {
  final phone = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  bool hidden = true;
  bool legacyEmail = false;
  String? message;

  @override
  void dispose() {
    phone.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (AppVariant.isUiPreview) {
      setState(() => message = 'Owner sign-in needs the functional build.');
      return;
    }
    if (!legacyEmail) {
      setState(
        () => message = 'Phone sign-in is not configured yet. Existing owners can use email sign-in.',
      );
      return;
    }
    if (!email.text.trim().contains('@') || password.text.isEmpty) {
      setState(() => message = 'Enter your owner email and password.');
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    try {
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
    } catch (e) {
      if (mounted) {
        setState(() => message = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _recover() async {
    if (!legacyEmail) {
      setState(
        () => message = 'Phone recovery is not configured yet. Use email recovery if you have an existing account.',
      );
      return;
    }
    if (AppVariant.isUiPreview) {
      setState(() => message = 'Recovery needs the functional build.');
      return;
    }
    if (!email.text.trim().contains('@')) {
      setState(() => message = 'Enter your owner email first.');
      return;
    }
    try {
      await ApiService.sendOwnerRecovery(email.text);
      if (mounted) {
        setState(() => message = 'Check your email for recovery instructions.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => message = 'Recovery is unavailable. Try again later.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => ChekmiEntryTheme(
    child: Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(23, 18, 23, 24),
                child: SizedBox(
                  height: constraints.maxHeight < 620
                      ? 620
                      : constraints.maxHeight - 42,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      EntryBackButton(
                        onPressed: () => Navigator.maybePop(context),
                      ),
                      const SizedBox(height: 34),
                      const EntryBrandMark(size: 55),
                      const SizedBox(height: 18),
                      const Text(
                        'Welcome back',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Sign in to your business',
                        style: TextStyle(color: EntryColors.muted),
                      ),
                      const SizedBox(height: 34),
                      Text(
                        legacyEmail ? 'Owner email' : 'Phone number',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 9),
                      if (legacyEmail)
                        TextField(
                          controller: email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                            hintText: 'you@business.com',
                          ),
                        )
                      else
                        TextField(
                          controller: phone,
                          keyboardType: TextInputType.phone,
                          autofillHints: const [AutofillHints.telephoneNumber],
                          decoration: const InputDecoration(
                            hintText: '+251 9…',
                            prefixIcon: Icon(CupertinoIcons.phone),
                          ),
                        ),
                      const SizedBox(height: 21),
                      const Text(
                        'Password',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 9),
                      TextField(
                        controller: password,
                        obscureText: hidden,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) => busy ? null : _signIn(),
                        decoration: InputDecoration(
                          hintText: 'Password',
                          suffixIcon: IconButton(
                            tooltip: hidden ? 'Show password' : 'Hide password',
                            onPressed: () => setState(() => hidden = !hidden),
                            icon: Icon(
                              hidden
                                  ? CupertinoIcons.eye
                                  : CupertinoIcons.eye_slash,
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _recover,
                          style: TextButton.styleFrom(
                            foregroundColor: EntryColors.muted,
                          ),
                          child: const Text('Forgot password?'),
                        ),
                      ),
                      if (message != null)
                        Text(
                          message!,
                          style: const TextStyle(color: EntryColors.error),
                        ),
                      const Spacer(),
                      EntryActionButton(
                        label: 'Sign In',
                        loading: busy,
                        onPressed: _signIn,
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: () => setState(() {
                            legacyEmail = !legacyEmail;
                            message = null;
                          }),
                          style: TextButton.styleFrom(
                            foregroundColor: EntryColors.muted,
                          ),
                          child: Text(
                            legacyEmail
                                ? 'Use phone to sign in'
                                : 'Use email to sign in',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).push(
                            CupertinoPageRoute<void>(
                              builder: (_) =>
                                  const BusinessRegistrationScreen(),
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: EntryColors.muted,
                          ),
                          child: const Text('Register your business'),
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
