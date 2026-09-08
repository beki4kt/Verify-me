import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_motion.dart';
import 'app_shell.dart';
import 'state_views.dart';

class StaffLoginExperience extends StatefulWidget {
  const StaffLoginExperience({
    super.key,
    required this.businessName,
    required this.businessCode,
    required this.phone,
    required this.password,
    required this.loading,
    required this.obscure,
    required this.onLogin,
    required this.onTogglePassword,
    required this.onChangeBusiness,
    required this.onDemo,
    required this.onOwner,
    required this.prefix,
    required this.onPrefix,
    this.error,
    this.quickAccess,
  });
  final String businessName, businessCode, prefix;
  final TextEditingController phone, password;
  final bool loading, obscure;
  final VoidCallback onLogin,
      onTogglePassword,
      onChangeBusiness,
      onDemo,
      onOwner;
  final ValueChanged<String> onPrefix;
  final String? error;
  final Widget? quickAccess;
  @override
  State<StaffLoginExperience> createState() => _StaffLoginExperienceState();
}

class _StaffLoginExperienceState extends State<StaffLoginExperience> {
  final _phoneFocus = FocusNode();
  final _passwordFocus = FocusNode();
  @override
  void initState() {
    super.initState();
    _phoneFocus.addListener(_updateFocus);
    _passwordFocus.addListener(_updateFocus);
  }

  void _updateFocus() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackdrop(
        maxWidth: 1080,
        entry: true,
        child: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      key: const Key('iphone-change-workspace'),
                      tooltip: 'Change workspace',
                      onPressed: widget.loading
                          ? null
                          : widget.onChangeBusiness,
                      icon: const Icon(AppIcons.back),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: BrandLockup(
                            compact: true,
                            onLogoTap: widget.onOwner,
                          ),
                        ),
                      ),
                    ),
                    const GlassLanguageToggleButton(),
                    const GlassThemeToggleButton(),
                  ],
                ),
                const SizedBox(height: 28),
                LayoutBuilder(
                  builder: (context, bounds) {
                    final welcome = FadeSlideIn(
                      duration: const Duration(milliseconds: 600),
                      child: _welcome(theme),
                    );
                    final form = FadeSlideIn(
                      delay: const Duration(milliseconds: 140),
                      beginY: .06,
                      child: _form(theme),
                    );
                    if (bounds.maxWidth >= 780) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: welcome),
                          const SizedBox(width: 36),
                          Expanded(child: form),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [welcome, const SizedBox(height: 24), form],
                    );
                  },
                ),
                const SizedBox(height: 24),
                FadeSlideIn(
                  index: 8,
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    children: [
                      TextButton.icon(
                        onPressed: widget.loading
                            ? null
                            : widget.onChangeBusiness,
                        icon: const Icon(AppIcons.business, size: 17),
                        label: const Text('Change workspace'),
                      ),
                      TextButton.icon(
                        onPressed: widget.loading ? null : widget.onDemo,
                        icon: const Icon(AppIcons.scanReceipt, size: 17),
                        label: const Text('Try demo scanner'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _welcome(ThemeData theme) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const HeroPillBadge(
        label: 'WORKSPACE CONNECTED',
        icon: AppIcons.cloudReady,
      ),
      const SizedBox(height: 18),
      Text(
        'Your team.\nReady for business.',
        style: theme.textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w800,
          height: 1.08,
          letterSpacing: -1,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'Sign in to verify payments, follow activity, and keep your business moving.',
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 20),
      HoverSurface(
        accent: AppColors.aqua,
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.aqua.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(AppIcons.storefront, color: AppColors.aqua),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.businessName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    widget.businessCode.isEmpty
                        ? 'Connected business'
                        : 'Workspace ${widget.businessCode}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(AppIcons.verified, color: AppColors.success, size: 22),
          ],
        ),
      ),
      const SizedBox(height: 18),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _capability('Payment staff', AppIcons.scanReceipt),
          _capability('Cashier', AppIcons.pointOfSale),
          _capability('Administrator', AppIcons.administration),
        ],
      ),
      const SizedBox(height: 10),
      Text(
        'Your account opens the tools assigned to your role.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );

  Widget _capability(String label, IconData icon) => HoverSurface(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15),
        const SizedBox(width: 7),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    ),
  );

  Widget _form(ThemeData theme) => AutofillGroup(
    child: AnimatedContainer(
      duration: MediaQuery.of(context).disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color:
              (_phoneFocus.hasFocus || _passwordFocus.hasFocus
                      ? AppColors.primary
                      : theme.colorScheme.outlineVariant)
                  .withValues(alpha: .6),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(
              alpha: _phoneFocus.hasFocus || _passwordFocus.hasFocus
                  ? .13
                  : .04,
            ),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Welcome back',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Use the phone number and password registered by your business administrator.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (widget.quickAccess != null) ...[
            const SizedBox(height: 16),
            widget.quickAccess!,
          ],
          const SizedBox(height: 22),
          Text('Phone number', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: PopupMenuButton<String>(
                  key: const Key('login-phone-prefix'),
                  tooltip: 'Phone prefix',
                  enabled: !widget.loading,
                  onSelected: widget.onPrefix,
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: '9', child: Text('+2519')),
                    PopupMenuItem(value: '7', child: Text('+2517')),
                  ],
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '+251${widget.prefix}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        const RotatedBox(
                          quarterTurns: 1,
                          child: Icon(AppIcons.chevronRight, size: 18),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: const Key('iphone-staff-phone'),
                  controller: widget.phone,
                  focusNode: _phoneFocus,
                  enabled: !widget.loading,
                  keyboardType: TextInputType.phone,
                  maxLength: 8,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  autofillHints: const [AutofillHints.telephoneNumberNational],
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _passwordFocus.requestFocus(),
                  decoration: const InputDecoration(
                    hintText: '12 345 678',
                    counterText: '',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Enter the remaining 8 digits.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 18),
          Text('Password', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          TextField(
            key: const Key('iphone-staff-password'),
            controller: widget.password,
            focusNode: _passwordFocus,
            enabled: !widget.loading,
            obscureText: widget.obscure,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (!widget.loading) widget.onLogin();
            },
            decoration: InputDecoration(
              hintText: 'Your password',
              prefixIcon: const Icon(AppIcons.lock, size: 19),
              suffixIcon: IconButton(
                tooltip: widget.obscure ? 'Show password' : 'Hide password',
                onPressed: widget.onTogglePassword,
                icon: Icon(
                  widget.obscure ? AppIcons.visible : AppIcons.hidden,
                  size: 20,
                ),
              ),
            ),
          ),
          if (MediaQuery.of(context).disableAnimations)
            _errorContent()
          else
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              child: _errorContent(),
            ),
          const SizedBox(height: 22),
          SizedBox(
            height: 56,
            child: FilledButton(
              key: const Key('iphone-staff-sign-in'),
              onPressed: widget.loading ? null : widget.onLogin,
              child: AnimatedSwitcher(
                duration: MediaQuery.of(context).disableAnimations
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                child: widget.loading
                    ? const SizedBox.square(
                        key: ValueKey('busy'),
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Row(
                        key: ValueKey('ready'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Sign in'),
                          SizedBox(width: 12),
                          Icon(AppIcons.forward, size: 18),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Need access or a password reset? Contact your business administrator.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, height: 1.5),
          ),
        ],
      ),
    ),
  );
  Widget _errorContent() => widget.error == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 14),
          child: ErrorBanner(message: widget.error!),
        );
}
