import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/widgets/entry_components.dart';

/// Presentation only. Authentication and role routing stay in StaffLoginScreen.
class StaffSignInView extends StatelessWidget {
  const StaffSignInView({
    super.key,
    required this.businessName,
    required this.businessCode,
    required this.phone,
    required this.password,
    required this.loading,
    required this.obscure,
    required this.prefix,
    required this.onPrefix,
    required this.error,
    required this.onLogin,
    required this.onTogglePassword,
    required this.onChangeBusiness,
    this.onOwner,
    this.quickAccess,
  });

  final String businessName;
  final String businessCode;
  final TextEditingController phone;
  final TextEditingController password;
  final bool loading;
  final bool obscure;
  final String prefix;
  final ValueChanged<String> onPrefix;
  final String? error;
  final VoidCallback onLogin;
  final VoidCallback onTogglePassword;
  final VoidCallback onChangeBusiness;
  final VoidCallback? onOwner;
  final Widget? quickAccess;

  @override
  Widget build(BuildContext context) => ChekmiEntryTheme(
    child: Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(23, 18, 23, 30),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: EntryBackButton(onPressed: onChangeBusiness),
                ),
                const SizedBox(height: 34),
                const EntryBrandMark(size: 54),
                const SizedBox(height: 17),
                const Text(
                  'Welcome back',
                  style: TextStyle(
                    fontSize: 31,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.1,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  businessName,
                  style: const TextStyle(color: EntryColors.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (businessCode.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    businessCode,
                    style: const TextStyle(
                      color: EntryColors.muted,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                ],
                const SizedBox(height: 30),
                const Text(
                  'Phone number',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    SizedBox(
                      width: 138,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: prefix,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 15,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: '9', child: Text('+251 9')),
                          DropdownMenuItem(value: '7', child: Text('+251 7')),
                        ],
                        onChanged: loading
                            ? null
                            : (value) {
                                if (value != null) onPrefix(value);
                              },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        key: const Key('iphone-staff-phone'),
                        controller: phone,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        maxLength: 8,
                        decoration: const InputDecoration(
                          hintText: '8 digits',
                          counterText: '',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Password',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 9),
                TextField(
                  key: const Key('iphone-staff-password'),
                  controller: password,
                  obscureText: obscure,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => loading ? null : onLogin(),
                  decoration: InputDecoration(
                    hintText: 'Password',
                    suffixIcon: IconButton(
                      tooltip: obscure ? 'Show password' : 'Hide password',
                      onPressed: onTogglePassword,
                      icon: Icon(
                        obscure ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                      ),
                    ),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 15),
                  Text(
                    error!,
                    style: const TextStyle(color: EntryColors.error),
                  ),
                ],
                const SizedBox(height: 26),
                EntryActionButton(
                  key: const Key('iphone-staff-sign-in'),
                  label: 'Sign In',
                  loading: loading,
                  onPressed: onLogin,
                ),
                if (onOwner != null) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: onOwner,
                      style: TextButton.styleFrom(
                        foregroundColor: EntryColors.muted,
                        minimumSize: const Size(180, 44),
                      ),
                      child: const Text('Business owner sign in'),
                    ),
                  ),
                ],
                if (quickAccess != null) ...[
                  const SizedBox(height: 23),
                  const Text(
                    'Demo accounts',
                    style: TextStyle(color: EntryColors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  quickAccess!,
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
