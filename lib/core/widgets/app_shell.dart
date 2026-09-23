import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:verify_me/core/theme/app_icons.dart';
import 'package:provider/provider.dart';

import '../../localization_service.dart';
import '../config/app_variant.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/theme_controller.dart';

/// Responsive ambient background used throughout the product.
class AppBackdrop extends StatelessWidget {
  const AppBackdrop({
    super.key,
    required this.child,
    this.maxWidth = 1180,
    this.entry = false,
  });

  final Widget child;
  final double maxWidth;
  final bool entry;

  @override
  Widget build(BuildContext context) {
    if (AppVariant.usesIPhoneUi) {
      return _IPhoneAppBackdrop(maxWidth: maxWidth, child: child);
    }
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final background = dark ? AppColors.bg : AppColors.lightBg;
    return LayoutBuilder(
      builder: (context, constraints) => ColoredBox(
        color: background,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: dark
                      ? const [
                          Color(0xFF08090B),
                          Color(0xFF0B0C11),
                          Color(0xFF07080A),
                        ]
                      : const [
                          Color(0xFFFFF4F7),
                          Color(0xFFF7E9FF),
                          Color(0xFFE9FBF8),
                        ],
                  stops: const [0, .52, 1],
                ),
              ),
            ),
            const Positioned(
              top: -190,
              left: -150,
              child: _AmbientOrb(size: 480, color: AppColors.violet),
            ),
            Positioned(
              top: entry ? 80 : 30,
              right: -190,
              child: _AmbientOrb(
                size: entry ? 520 : 430,
                color: AppColors.aqua,
              ),
            ),
            Positioned(
              bottom: -280,
              left: constraints.maxWidth * .24,
              child: _AmbientOrb(
                size: 560,
                color: dark ? AppColors.violet : const Color(0xFFC69BFF),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _ChekmiPatternPainter(dark: dark),
                  ),
                ),
              ),
            ),
            if (entry && constraints.maxWidth >= 980)
              Positioned.fill(child: _EntryBackdropDecor(dark: dark)),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: entry ? const Alignment(0, -.18) : Alignment.center,
                  radius: entry ? .78 : 1.15,
                  colors: [
                    Colors.transparent,
                    background.withValues(alpha: dark ? .14 : .08),
                  ],
                ),
              ),
            ),
            BackdropGroup(
              child: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: child,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A calmer, edge-to-edge canvas for the iPhone presentation. The desktop
/// experience keeps the expressive CHEKMI pattern, while the phone uses broad
/// tonal depth so content—not decoration—sets the hierarchy.
class _IPhoneAppBackdrop extends StatelessWidget {
  const _IPhoneAppBackdrop({required this.child, required this.maxWidth});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: dark ? const Color(0xFF090A0F) : const Color(0xFFF5F6FA),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: dark
                    ? const [Color(0xFF10121A), Color(0xFF090A0F)]
                    : const [Color(0xFFFAFAFD), Color(0xFFF2F3F8)],
              ),
            ),
          ),
          Positioned(
            top: -240,
            right: -190,
            child: IgnorePointer(
              child: Container(
                width: 430,
                height: 430,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: dark ? .12 : .09),
                      AppColors.primary.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Large-screen entry decoration: abstract payment objects sit behind the
/// authentication card, giving the page depth without relying on a stock image.
class _EntryBackdropDecor extends StatelessWidget {
  const _EntryBackdropDecor({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned(
        left: 54,
        top: 170,
        child: Transform.rotate(
          angle: -.08,
          child: _FloatingGlassTile(
            dark: dark,
            icon: AppIcons.receipt,
            accent: AppColors.success,
          ),
        ),
      ),
      Positioned(
        right: 48,
        top: 275,
        child: Transform.rotate(
          angle: .075,
          child: _FloatingGlassTile(
            dark: dark,
            icon: AppIcons.table,
            accent: AppColors.brandOrange,
            compact: true,
          ),
        ),
      ),
    ],
  );
}

class _FloatingGlassTile extends StatelessWidget {
  const _FloatingGlassTile({
    required this.dark,
    required this.icon,
    required this.accent,
    this.compact = false,
  });

  final bool dark;
  final IconData icon;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: dark ? .82 : .88,
    child: Container(
      width: compact ? 116 : 148,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: (dark ? AppColors.surfaceContainer : Colors.white).withValues(
          alpha: dark ? .34 : .40,
        ),
        border: Border.all(
          color: (dark ? Colors.white : AppColors.lightInk).withValues(
            alpha: dark ? .25 : .58,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .24 : .09),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: dark ? .08 : .72),
            blurRadius: 10,
            offset: const Offset(-5, -6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DecorativeBar(color: accent, widthFactor: .88),
                const SizedBox(height: 7),
                _DecorativeBar(color: accent, widthFactor: .58),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _DecorativeBar extends StatelessWidget {
  const _DecorativeBar({required this.color, required this.widthFactor});

  final Color color;
  final double widthFactor;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    widthFactor: widthFactor,
    child: Container(
      height: 7,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .34),
        borderRadius: BorderRadius.circular(99),
      ),
    ),
  );
}

/// A quiet geometric weave that gives CHEKMI a recognizable backdrop without
/// adding image downloads or expensive animated blur layers.
class _ChekmiPatternPainter extends CustomPainter {
  const _ChekmiPatternPainter({required this.dark});

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = (dark ? Colors.white : AppColors.primaryDeep).withValues(
        alpha: dark ? .045 : .055,
      )
      ..style = PaintingStyle.fill;

    const spacing = 34.0;
    for (double y = 17; y < size.height; y += spacing) {
      for (double x = 17; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), .9, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ChekmiPatternPainter oldDelegate) =>
      oldDelegate.dark != dark;
}

class _AmbientOrb extends StatelessWidget {
  const _AmbientOrb({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final alpha = Theme.of(context).brightness == Brightness.dark ? .16 : .28;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

/// Adaptive frosted surface used by cards, menus, sheets, and trial content.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin,
    this.borderRadius = 24,
    this.blur = 22,
    this.opacity,
    this.accent,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blur;
  final double? opacity;
  final Color? accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(borderRadius);
    final tint = dark ? AppColors.surfaceContainer : AppColors.lightSurface;
    final border = accent ?? (dark ? Colors.white : AppColors.lightInk);
    final optimizedForIPhone = AppVariant.usesIPhoneUi;
    final iphoneSurface = dark
        ? const Color(0xFF161821)
        : const Color(0xFFFFFFFF);
    final panel = Material(
      color: optimizedForIPhone
          ? iphoneSurface.withValues(alpha: .96)
          : tint.withValues(alpha: opacity ?? (dark ? .46 : .44)),
      child: InkWell(
        onTap: onTap,
        splashColor: (accent ?? theme.colorScheme.primary).withValues(
          alpha: .08,
        ),
        highlightColor: Colors.transparent,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: border.withValues(
                alpha: optimizedForIPhone
                    ? (accent == null ? (dark ? .07 : .055) : .22)
                    : accent == null
                    ? (dark ? .12 : .42)
                    : (dark ? .40 : .42),
              ),
            ),
            gradient: optimizedForIPhone
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: dark ? .055 : .54),
                      tint.withValues(alpha: dark ? .18 : .14),
                      (accent ?? theme.colorScheme.primary).withValues(
                        alpha: dark ? .055 : .06,
                      ),
                    ],
                    stops: const [0, .48, 1],
                  ),
          ),
          child: child,
        ),
      ),
    );
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: optimizedForIPhone
                  ? (dark ? .18 : .055)
                  : (dark ? .42 : .09),
            ),
            blurRadius: optimizedForIPhone ? 16 : (dark ? 34 : 24),
            offset: Offset(0, optimizedForIPhone ? 6 : 18),
          ),
          if (accent != null)
            BoxShadow(
              color: accent!.withValues(alpha: dark ? .18 : .10),
              blurRadius: 34,
              spreadRadius: -4,
              offset: const Offset(0, 12),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: optimizedForIPhone
            ? panel
            : BackdropFilter.grouped(
                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: panel,
              ),
      ),
    );
  }
}

/// A subtle interactive surface for cards and rows on touch and pointer devices.
class HoverSurface extends StatefulWidget {
  const HoverSurface({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.accent,
    this.selected = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? accent;
  final bool selected;

  @override
  State<HoverSurface> createState() => _HoverSurfaceState();
}

class _HoverSurfaceState extends State<HoverSurface> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final active = _hovered || widget.selected;
    final accent = widget.accent ?? AppColors.primary;
    return MouseRegion(
      cursor: widget.onTap == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Listener(
        onPointerDown: widget.onTap == null
            ? null
            : (_) => setState(() => _pressed = true),
        onPointerUp: widget.onTap == null
            ? null
            : (_) => setState(() => _pressed = false),
        onPointerCancel: widget.onTap == null
            ? null
            : (_) => setState(() => _pressed = false),
        child: MotorScale(
          scale: _pressed
              ? .982
              : (_hovered && widget.onTap != null ? 1.008 : 1),
          child: GlassPanel(
            onTap: widget.onTap,
            padding: widget.padding,
            accent: active ? accent : null,
            opacity: dark ? (active ? .52 : .38) : (active ? .58 : .42),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.compact = false, this.onLogoTap});
  final bool compact;
  final VoidCallback? onLogoTap;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      BrandMark(size: compact ? 34 : 46, onTap: onLogoTap),
      const SizedBox(width: 12),
      Text(
        'CHEKMI',
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(letterSpacing: 1.1),
      ),
    ],
  );
}

/// A centered, floating navigation island shared by public-facing screens.
class FloatingNavIsland extends StatelessWidget {
  const FloatingNavIsland({
    super.key,
    required this.leading,
    this.navigation = const [],
    this.trailing = const [],
  });

  final Widget leading;
  final List<Widget> navigation;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .42 : .10),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: AppColors.primary.withValues(alpha: dark ? .08 : .05),
            blurRadius: 28,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter.grouped(
          filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: (dark ? AppColors.surfaceLow : Colors.white).withValues(
                alpha: dark ? .78 : .70,
              ),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: (dark ? Colors.white : AppColors.lightInk).withValues(
                  alpha: dark ? .12 : .12,
                ),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final showNavigation =
                    constraints.maxWidth >= 720 && navigation.isNotEmpty;
                return Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: leading,
                    ),
                    if (showNavigation)
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: navigation,
                        ),
                      )
                    else
                      const Spacer(),
                    ...trailing,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Violet-to-cyan text used sparingly for product-level declarations.
class GradientText extends StatelessWidget {
  const GradientText(
    this.text, {
    super.key,
    required this.style,
    this.textAlign = TextAlign.start,
    this.gradient = const LinearGradient(
      colors: [Color(0xFFF8FAFC), AppColors.primarySoft, AppColors.aqua],
    ),
  });

  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.srcIn,
    shaderCallback: (bounds) => gradient.createShader(bounds),
    child: Text(
      text,
      textAlign: textAlign,
      style: style?.copyWith(color: Colors.white),
    ),
  );
}

/// Compact product announcement shown directly above a hero headline.
class HeroPillBadge extends StatelessWidget {
  const HeroPillBadge({
    super.key,
    required this.label,
    this.icon = AppIcons.sparkle,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: AppColors.primarySoft.withValues(alpha: .24)),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: .12),
          blurRadius: 22,
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.primarySoft),
        const SizedBox(width: 7),
        Text(
          label,
          style: AppTypography.microLabel(color: AppColors.primarySoft)
              .copyWith(letterSpacing: 1),
        ),
      ],
    ),
  );
}

/// High-contrast shadow blast for the most important action on a screen.
class PrimaryGlow extends StatelessWidget {
  const PrimaryGlow({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(AppSpacing.radius),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: .42),
          blurRadius: 30,
          spreadRadius: -5,
          offset: const Offset(0, 15),
        ),
        BoxShadow(
          color: AppColors.aqua.withValues(alpha: .18),
          blurRadius: 34,
          spreadRadius: -10,
          offset: const Offset(8, 12),
        ),
      ],
    ),
    child: child,
  );
}

/// Larger centered brand treatment for entry and authentication screens.
class BrandHero extends StatelessWidget {
  const BrandHero({super.key, this.subtitle, this.onLogoTap});

  final String? subtitle;
  final VoidCallback? onLogoTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: subtitle == null ? 'CHEKMI' : 'CHEKMI. $subtitle',
      child: Column(
        children: [
          BrandMark(size: 82, onTap: onLogoTap),
          const SizedBox(height: AppSpacing.lg),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: GradientText(
              'CHEKMI',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontSize: 38,
                fontWeight: FontWeight.w900,
                letterSpacing: 4.2,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: 52,
            height: 3,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.aqua],
              ),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

class GlassThemeToggleButton extends StatelessWidget {
  const GlassThemeToggleButton({super.key, this.iPhoneStyle});

  final bool? iPhoneStyle;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    final tooltip = context.tr(theme.isDark ? 'Light mode' : 'Dark mode');
    return Semantics(
      button: true,
      toggled: theme.isDark,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: _AnimatedThemeOrb(
          isDark: theme.isDark,
          onTap: theme.toggle,
          compact: iPhoneStyle ?? AppVariant.usesIPhoneUi,
        ),
      ),
    );
  }
}

class _AnimatedThemeOrb extends StatefulWidget {
  const _AnimatedThemeOrb({
    required this.isDark,
    required this.onTap,
    required this.compact,
  });

  final bool isDark;
  final VoidCallback onTap;
  final bool compact;

  @override
  State<_AnimatedThemeOrb> createState() => _AnimatedThemeOrbState();
}

class _AnimatedThemeOrbState extends State<_AnimatedThemeOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _hovered = false;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.slow,
      value: widget.isDark ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(covariant _AnimatedThemeOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDark == widget.isDark) return;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _controller.value = widget.isDark ? 1 : 0;
      return;
    }
    _controller.animateTo(
      widget.isDark ? 1 : 0,
      duration: AppMotion.slow,
      curve: AppMotion.easeOutCustom,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) return _buildCompactControl(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: MotorScale(
          scale: _pressed ? .9 : (_hovered ? 1.06 : 1),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkResponse(
              onTap: widget.onTap,
              radius: 22,
              containedInkWell: true,
              customBorder: const CircleBorder(),
              child: SizedBox.square(
                dimension: 44,
                child: Center(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final progress = _controller.value;
                      final pulse = 1 - .1 * _sinPulse(progress);
                      final glow = Color.lerp(
                        const Color(0xFFFFB21A),
                        const Color(0xFF4169E8),
                        progress,
                      )!;
                      return Transform.scale(
                        scale: pulse,
                        child: Container(
                          width: widget.compact ? 30 : 34,
                          height: widget.compact ? 30 : 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: .72),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: glow.withValues(
                                  alpha: _hovered ? .42 : .27,
                                ),
                                blurRadius: widget.compact
                                    ? 8
                                    : (_hovered ? 22 : 15),
                                offset: Offset(0, widget.compact ? 2 : 7),
                              ),
                              if (!widget.compact)
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: .35),
                                  blurRadius: 7,
                                  offset: const Offset(-3, -3),
                                ),
                            ],
                          ),
                          child: ClipOval(
                            child: CustomPaint(
                              painter: _ThemeOrbPainter(progress: progress),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactControl(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.zero,
    minimumSize: const Size.square(44),
    onPressed: widget.onTap,
    child: AnimatedContainer(
      duration: AppMotion.base,
      curve: AppMotion.easeOutCustom,
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: AnimatedSwitcher(
        duration: AppMotion.base,
        switchInCurve: AppMotion.easeOutCustom,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: RotationTransition(
            turns: Tween<double>(begin: -.08, end: 0).animate(animation),
            child: child,
          ),
        ),
        child: Icon(
          widget.isDark
              ? CupertinoIcons.sun_max_fill
              : CupertinoIcons.moon_fill,
          key: ValueKey(widget.isDark),
          size: 17,
          color: widget.isDark
              ? const Color(0xFFFFB020)
              : const Color(0xFF7057D9),
        ),
      ),
    ),
  );

  double _sinPulse(double value) {
    final normalized = (value * 2 - 1).abs();
    return 1 - normalized;
  }
}

class _ThemeOrbPainter extends CustomPainter {
  const _ThemeOrbPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final baseColor = progress < .58
        ? Color.lerp(
            const Color(0xFFFFB316),
            const Color(0xFFC59C53),
            Curves.easeInOut.transform(
              (progress / .58).clamp(0.0, 1.0).toDouble(),
            ),
          )!
        : Color.lerp(
            const Color(0xFFC59C53),
            const Color(0xFF4169E8),
            Curves.easeOutCubic.transform(
              ((progress - .58) / .42).clamp(0.0, 1.0).toDouble(),
            ),
          )!;
    final deepColor = Color.lerp(
      baseColor,
      progress > .58 ? const Color(0xFF3458D5) : const Color(0xFFF59E0B),
      .34,
    )!;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [baseColor, deepColor],
        ).createShader(Offset.zero & size),
    );

    final rayExit = 1 - _interval(progress, 0, .62);
    final coreExit = 1 - _interval(progress, .12, .58);
    final moonEntry = _interval(progress, .34, .9);
    final glyphPaint = Paint()
      ..color = Colors.white.withValues(alpha: .96)
      ..strokeCap = StrokeCap.round;

    if (rayExit > 0) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(progress * .72);
      glyphPaint
        ..color = Colors.white.withValues(alpha: .96 * rayExit)
        ..strokeWidth = radius * .117;
      for (var index = 0; index < 8; index++) {
        canvas.save();
        canvas.rotate(index * 3.141592653589793 / 4);
        canvas.drawLine(
          Offset(0, -radius * .54 + radius * .13 * (1 - rayExit)),
          Offset(0, -radius * .72 + radius * .22 * (1 - rayExit)),
          glyphPaint,
        );
        canvas.restore();
      }
      canvas.restore();
    }

    if (coreExit > 0) {
      glyphPaint.color = Colors.white.withValues(alpha: .96 * coreExit);
      canvas.drawCircle(center, radius * .30 * coreExit, glyphPaint);
    }

    if (moonEntry > 0) {
      final moonScale = .28 + .72 * Curves.easeOutBack.transform(moonEntry);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(-.42 * (1 - moonEntry));
      canvas.scale(moonScale);
      final outer = Path()
        ..addOval(Rect.fromCircle(center: Offset.zero, radius: radius * .46));
      final cutout = Path()
        ..addOval(
          Rect.fromCircle(
            center: Offset(radius * .23, -radius * .18),
            radius: radius * .41,
          ),
        );
      final crescent = Path.combine(PathOperation.difference, outer, cutout);
      glyphPaint.color = Colors.white.withValues(alpha: .98 * moonEntry);
      canvas.drawPath(crescent, glyphPaint);
      canvas.restore();
    }

    canvas.drawCircle(
      center.translate(-radius * .25, -radius * .3),
      radius * .7,
      Paint()
        ..color = Colors.white.withValues(alpha: .09)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  double _interval(double value, double begin, double end) =>
      ((value - begin) / (end - begin)).clamp(0, 1);

  @override
  bool shouldRepaint(covariant _ThemeOrbPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class GlassLanguageToggleButton extends StatelessWidget {
  const GlassLanguageToggleButton({super.key, this.iPhoneStyle});

  final bool? iPhoneStyle;

  @override
  Widget build(BuildContext context) {
    final localization = context.watch<LocalizationService>();
    final tooltip = context.tr('Language');
    final control = (iPhoneStyle ?? AppVariant.usesIPhoneUi)
        ? _IPhoneLanguageToggle(
            isAmharic: localization.isAmharic,
            onTap: localization.toggleLanguage,
          )
        : _GlassActionPill(
            width: 80,
            accent: const [AppColors.aqua, AppColors.primary],
            onTap: localization.toggleLanguage,
            child: Stack(
              children: [
                AnimatedAlign(
                  duration: AppMotion.slow,
                  curve: AppMotion.easeOutBack,
                  alignment: localization.isAmharic
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    width: 35,
                    height: 32,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      gradient: const LinearGradient(
                        colors: [AppColors.aqua, AppColors.primary],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .62),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.aqua.withValues(alpha: .28),
                          blurRadius: 11,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    _LanguageOption(
                      label: 'EN',
                      selected: !localization.isAmharic,
                    ),
                    _LanguageOption(
                      label: 'አማ',
                      selected: localization.isAmharic,
                    ),
                  ],
                ),
              ],
            ),
          );
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(message: tooltip, child: control),
    );
  }
}

class _IPhoneLanguageToggle extends StatelessWidget {
  const _IPhoneLanguageToggle({required this.isAmharic, required this.onTap});

  final bool isAmharic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.zero,
    minimumSize: const Size.square(44),
    onPressed: onTap,
    child: AnimatedContainer(
      duration: AppMotion.base,
      curve: AppMotion.easeOutCustom,
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: AnimatedSwitcher(
        duration: AppMotion.fast,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: animation, child: child),
        ),
        child: Text(
          isAmharic ? 'አማ' : 'EN',
          key: ValueKey(isAmharic),
          style: TextStyle(
            color: CupertinoColors.label.resolveFrom(context),
            fontSize: isAmharic ? 10 : 11,
            fontWeight: FontWeight.w700,
            letterSpacing: isAmharic ? 0 : .3,
          ),
        ),
      ),
    ),
  );
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Center(
      child: AnimatedDefaultTextStyle(
        duration: AppMotion.base,
        curve: AppMotion.easeOutCustom,
        style:
            AppTypography.microLabel(
              color: selected
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ).copyWith(
              fontSize: 9.5,
              fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
              letterSpacing: .5,
            ),
        child: AnimatedScale(
          duration: AppMotion.base,
          curve: AppMotion.easeOutBack,
          scale: selected ? 1 : .92,
          child: Text(label),
        ),
      ),
    ),
  );
}

class _GlassActionPill extends StatefulWidget {
  const _GlassActionPill({
    required this.width,
    required this.accent,
    required this.onTap,
    required this.child,
  });

  final double width;
  final List<Color> accent;
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_GlassActionPill> createState() => _GlassActionPillState();
}

class _GlassActionPillState extends State<_GlassActionPill> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final glow = widget.accent.first;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: MotorScale(
          scale: _pressed ? .94 : (_hovered ? 1.035 : 1),
          child: Container(
            width: widget.width,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              boxShadow: [
                BoxShadow(
                  color: glow.withValues(
                    alpha: _hovered ? (dark ? .30 : .20) : .12,
                  ),
                  blurRadius: _hovered ? 20 : 12,
                  offset: const Offset(0, 7),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: dark ? .05 : .60),
                  blurRadius: 8,
                  offset: const Offset(-4, -4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onTap,
                  splashColor: glow.withValues(alpha: .12),
                  highlightColor: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: dark ? .24 : .62),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: dark ? .15 : .62),
                          widget.accent.first.withValues(
                            alpha: dark ? .11 : .09,
                          ),
                          widget.accent.last.withValues(
                            alpha: dark ? .16 : .11,
                          ),
                        ],
                      ),
                    ),
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 52, this.onTap});
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .32),
        color: Colors.white.withValues(alpha: .94),
        border: Border.all(color: Colors.white.withValues(alpha: .55)),
        boxShadow: [
          BoxShadow(
            color: AppColors.telebirr.withValues(alpha: .20),
            blurRadius: 18,
          ),
        ],
      ),
      padding: EdgeInsets.all(size * .10),
      child: Image.asset(
        'assets/branding/chekmi_mark_256.png',
        cacheWidth: (size * 2).round(),
        filterQuality: FilterQuality.medium,
      ),
    );
    if (onTap == null) return mark;
    return Semantics(
      button: true,
      label: 'Open protected owner access',
      child: Tooltip(
        message: 'Owner access',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(onTap: onTap, child: mark),
        ),
      ),
    );
  }
}
