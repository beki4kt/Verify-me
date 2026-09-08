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
  bool _formHovered = false;
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
                const SizedBox(height: 24),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 540),
                    child: FadeSlideIn(
                      beginY: .05,
                      duration: const Duration(milliseconds: 420),
                      child: _form(theme),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                FadeSlideIn(
                  index: 8,
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    children: [
                      Tooltip(
                        message: 'Change workspace',
                        child: TextButton.icon(
                          onPressed: widget.loading
                              ? null
                              : widget.onChangeBusiness,
                          icon: const Icon(AppIcons.business, size: 17),
                          label: const Text('Workspace'),
                        ),
                      ),
                      Tooltip(
                        message: 'Open demo scanner',
                        child: TextButton.icon(
                          onPressed: widget.loading ? null : widget.onDemo,
                          icon: const Icon(AppIcons.scanReceipt, size: 17),
                          label: const Text('Demo'),
                        ),
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

  Widget _form(ThemeData theme) {
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    final active =
        _formHovered || _phoneFocus.hasFocus || _passwordFocus.hasFocus;
    final dark = theme.brightness == Brightness.dark;
    final surface = theme.colorScheme.surface;
    return AutofillGroup(
      child: MouseRegion(
        onEnter: (_) => setState(() => _formHovered = true),
        onExit: (_) => setState(() => _formHovered = false),
        child: MotorScale(
          scale: active ? 1.006 : 1,
          child: AnimatedContainer(
            duration: reducedMotion ? Duration.zero : AppMotion.slow,
            padding: const EdgeInsets.all(1.35),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(33),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: active
                    ? [AppColors.aqua, AppColors.primary, AppColors.primarySoft]
                    : [
                        theme.colorScheme.outlineVariant.withValues(alpha: .7),
                        AppColors.primary.withValues(alpha: dark ? .34 : .2),
                        theme.colorScheme.outlineVariant.withValues(alpha: .48),
                      ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? .48 : .16),
                  blurRadius: active ? 48 : 36,
                  offset: const Offset(0, 22),
                ),
                BoxShadow(
                  color: AppColors.primary.withValues(
                    alpha: active ? (dark ? .25 : .17) : (dark ? .11 : .07),
                  ),
                  blurRadius: active ? 42 : 28,
                  spreadRadius: active ? 1 : 0,
                ),
              ],
            ),
            child: AnimatedContainer(
              duration: reducedMotion ? Duration.zero : AppMotion.slow,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 26),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(31.5),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.alphaBlend(
                      Colors.white.withValues(alpha: dark ? .045 : .5),
                      surface,
                    ),
                    Color.alphaBlend(
                      AppColors.primary.withValues(alpha: dark ? .055 : .025),
                      surface,
                    ),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: dark ? .09 : .72),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        key: const Key('login-business-code'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          color: AppColors.aqua.withValues(
                            alpha: dark ? .1 : .08,
                          ),
                          border: Border.all(
                            color: AppColors.aqua.withValues(
                              alpha: dark ? .46 : .34,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              AppIcons.number,
                              size: 14,
                              color: AppColors.aqua,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              widget.businessCode.isEmpty
                                  ? 'CONNECTED'
                                  : widget.businessCode.toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.aqua,
                                fontWeight: FontWeight.w800,
                                letterSpacing: .8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.success.withValues(alpha: .1),
                          border: Border.all(
                            color: AppColors.success.withValues(alpha: .34),
                          ),
                        ),
                        child: const Icon(
                          AppIcons.verified,
                          color: AppColors.success,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.businessName,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.aqua.withValues(alpha: .55),
                          AppColors.primary.withValues(alpha: .32),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Sign in',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (widget.quickAccess != null) ...[
                    const SizedBox(height: 16),
                    widget.quickAccess!,
                  ],
                  const SizedBox(height: 20),
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
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: dark ? .28 : .42),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color:
                                    (_phoneFocus.hasFocus
                                            ? AppColors.aqua
                                            : theme.colorScheme.outlineVariant)
                                        .withValues(
                                          alpha: _phoneFocus.hasFocus
                                              ? .85
                                              : .72,
                                        ),
                                width: _phoneFocus.hasFocus ? 1.4 : 1,
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
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          autofillHints: const [
                            AutofillHints.telephoneNumberNational,
                          ],
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => _passwordFocus.requestFocus(),
                          decoration: _fieldDecoration(
                            theme,
                            hintText: '12 345 678',
                            icon: AppIcons.phone,
                            focused: _phoneFocus.hasFocus,
                          ).copyWith(counterText: ''),
                        ),
                      ),
                    ],
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
                    decoration:
                        _fieldDecoration(
                          theme,
                          hintText: 'Your password',
                          icon: AppIcons.lock,
                          focused: _passwordFocus.hasFocus,
                        ).copyWith(
                          suffixIcon: IconButton(
                            tooltip: widget.obscure
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: widget.onTogglePassword,
                            icon: Icon(
                              widget.obscure
                                  ? AppIcons.visible
                                  : AppIcons.hidden,
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
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: active ? 5 : 1,
                        shadowColor: AppColors.primary.withValues(alpha: .42),
                      ),
                      child: AnimatedSwitcher(
                        duration: MediaQuery.of(context).disableAnimations
                            ? Duration.zero
                            : const Duration(milliseconds: 180),
                        child: widget.loading
                            ? const SizedBox.square(
                                key: ValueKey('busy'),
                                dimension: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(
    ThemeData theme, {
    required String hintText,
    required IconData icon,
    required bool focused,
  }) {
    final dark = theme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(14);
    return InputDecoration(
      hintText: hintText,
      prefixIcon: Icon(
        icon,
        size: 19,
        color: focused ? AppColors.aqua : theme.colorScheme.onSurfaceVariant,
      ),
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
        alpha: dark ? .28 : .42,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: .72),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColors.aqua, width: 1.4),
      ),
    );
  }

  Widget _errorContent() => widget.error == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 14),
          child: ErrorBanner(message: widget.error!),
        );
}
