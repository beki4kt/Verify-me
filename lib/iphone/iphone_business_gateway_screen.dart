import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, SliverAppBar, Theme;
import 'package:flutter/services.dart';

import '../api_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_motion.dart';
import '../core/widgets/app_shell.dart';
import '../core/widgets/payment_brand.dart';
import '../offline_storage.dart';
import '../pricing_screen.dart';
import '../staff_login_screen.dart';
import '../super_admin_login_screen.dart';
import '../trial_mode_screen.dart';

/// iPhone-first provisioning experience.
///
/// Business logic remains shared with the other CHEKMI presentations; only
/// hierarchy, navigation, controls, spacing, and motion follow iOS conventions.
class IPhoneBusinessGatewayScreen extends StatefulWidget {
  const IPhoneBusinessGatewayScreen({super.key});

  @override
  State<IPhoneBusinessGatewayScreen> createState() =>
      _IPhoneBusinessGatewayScreenState();
}

class _IPhoneBusinessGatewayScreenState
    extends State<IPhoneBusinessGatewayScreen> {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocus = FocusNode();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  Future<void> _connectWorkspace() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      _codeFocus.requestFocus();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    FocusScope.of(context).unfocus();

    try {
      final business = await ApiService.verifyBusinessCode(code);
      if (business == null) {
        if (mounted) setState(() => _errorMessage = 'Workspace not found.');
        return;
      }

      await DeviceStorage.lockDeviceToBusiness(
        business['business_id'],
        business['name'],
        business['business_code'],
      );
      await HapticFeedback.mediumImpact();

      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        CupertinoPageRoute<void>(builder: (_) => const StaffLoginScreen()),
      );
    } catch (error) {
      await HapticFeedback.vibrate();
      if (mounted) {
        setState(
          () => _errorMessage = error.toString().replaceAll('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _open(Widget screen) =>
      Navigator.of(context)
          .push(CupertinoPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final background = Theme.of(context).scaffoldBackgroundColor;
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final surface = Theme.of(context).colorScheme.surface;

    return CupertinoPageScaffold(
      backgroundColor: background,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverAppBar(
            pinned: true,
            toolbarHeight: 64,
            backgroundColor: surface.withValues(alpha: .97),
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            leadingWidth: 56,
            titleSpacing: 0,
            leading: Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Center(
                child: BrandMark(
                  size: 38,
                  onTap: () => _open(const SuperAdminLoginScreen()),
                ),
              ),
            ),
            title: Text(
              'Chekmi',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -.6),
            ),
            actions: const [
              GlassLanguageToggleButton(iPhoneStyle: true),
              GlassThemeToggleButton(iPhoneStyle: true),
              SizedBox(width: 6),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 48),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 540),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FadeSlideIn(child: _HeroCard(dark: dark)),
                      const SizedBox(height: 30),
                      FadeSlideIn(
                        index: 1,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            'Your workspace',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      FadeSlideIn(
                        index: 1,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            'Enter the restaurant code for this iPhone.',
                            style: CupertinoTheme.of(context)
                                .textTheme
                                .textStyle
                                .copyWith(
                                  color: secondary,
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      FadeSlideIn(
                        index: 2,
                        child: _WorkspaceCard(
                          controller: _codeController,
                          focusNode: _codeFocus,
                          isLoading: _isLoading,
                          errorMessage: _errorMessage,
                          onConnect: _connectWorkspace,
                        ),
                      ),
                      const SizedBox(height: 32),
                      FadeSlideIn(index: 3, child: const _ProviderStrip()),
                      const SizedBox(height: 32),
                      FadeSlideIn(
                        index: 4,
                        child: _IPhoneSection(
                          children: [
                            _ActionRow(
                              icon: CupertinoIcons.play_circle_fill,
                              color: AppColors.primary,
                              title: 'Try the live demo',
                              subtitle: 'Explore Chekmi without connecting',
                              onTap: () => _open(const TrialModeScreen()),
                            ),
                            _ActionRow(
                              icon: CupertinoIcons.layers_alt_fill,
                              color: const Color(0xFF06B6D4),
                              title: 'Plans',
                              subtitle: 'Compare Basic and Pro',
                              onTap: () => _open(const PricingScreen()),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      FadeSlideIn(
                        index: 5,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.lock_shield_fill,
                              size: 13,
                              color: secondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Secure restaurant access',
                              style: CupertinoTheme.of(context)
                                  .textTheme
                                  .textStyle
                                  .copyWith(color: secondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Container(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 25),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF211638), Color(0xFF101A25)]
              : const [Color(0xFFF1EAFE), Color(0xFFE8F8FA)],
        ),
        border: Border.all(
          color: dark
              ? CupertinoColors.white.withValues(alpha: .07)
              : CupertinoColors.white.withValues(alpha: .90),
        ),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(alpha: dark ? .22 : .07),
            blurRadius: 28,
            spreadRadius: -10,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: dark ? .22 : .14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              CupertinoIcons.check_mark_circled_solid,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Every payment.\nVerified.',
            style: CupertinoTheme.of(context).textTheme.navLargeTitleTextStyle
                .copyWith(
                  fontSize: 36,
                  height: 1.02,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.1,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Fast, clear payment confirmation for restaurant teams.',
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
              fontSize: 15,
              height: 1.45,
            ),
          ),
        ],
      ),
    ),
  );
}

class _WorkspaceCard extends StatelessWidget {
  const _WorkspaceCard({
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.errorMessage,
    required this.onConnect,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final fill = CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
      context,
    );
    final field = CupertinoColors.tertiarySystemFill.resolveFrom(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: CupertinoColors.separator
              .resolveFrom(context)
              .withValues(alpha: .34),
          width: .5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CupertinoTextField(
            key: const Key('iphone-workspace-code'),
            controller: controller,
            focusNode: focusNode,
            enabled: !isLoading,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => onConnect(),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9-]')),
              LengthLimitingTextInputFormatter(32),
            ],
            placeholder: 'Restaurant code',
            prefix: const Padding(
              padding: EdgeInsets.only(left: 13),
              child: Icon(CupertinoIcons.building_2_fill, size: 19),
            ),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 17),
            decoration: BoxDecoration(
              color: field,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 10),
            Semantics(
              liveRegion: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    CupertinoIcons.exclamationmark_circle_fill,
                    color: CupertinoColors.systemRed,
                    size: 17,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      errorMessage!,
                      style: CupertinoTheme.of(context).textTheme.textStyle
                          .copyWith(
                            color: CupertinoColors.systemRed.resolveFrom(
                              context,
                            ),
                            fontSize: 13,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 54,
            child: CupertinoButton.filled(
              key: const Key('iphone-connect-workspace'),
              borderRadius: BorderRadius.circular(16),
              onPressed: isLoading ? null : onConnect,
              child: isLoading
                  ? const CupertinoActivityIndicator(
                      color: CupertinoColors.white,
                    )
                  : const Text('Connect Workspace'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderStrip extends StatelessWidget {
  const _ProviderStrip();

  static const providers = [
    'Telebirr',
    'CBE',
    'CBE Birr',
    'Dashen Bank',
    'Bank of Abyssinia',
    'M-Pesa',
  ];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          'Works with',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final provider in providers)
            PaymentLogo(provider: provider, size: 42, padding: 7),
        ],
      ),
    ],
  );
}

class _IPhoneSection extends StatelessWidget {
  const _IPhoneSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var index = 0; index < children.length; index++) ...[
        children[index],
        if (index != children.length - 1) const SizedBox(height: 12),
      ],
    ],
  );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
          context,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: CupertinoTheme.of(context).textTheme.textStyle
                      .copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: CupertinoTheme.of(context).textTheme.textStyle
                      .copyWith(
                        color: CupertinoColors.secondaryLabel.resolveFrom(
                          context,
                        ),
                        fontSize: 13,
                      ),
                ),
              ],
            ),
          ),
          const Icon(
            CupertinoIcons.chevron_forward,
            color: CupertinoColors.tertiaryLabel,
            size: 17,
          ),
        ],
      ),
    ),
  );
}
