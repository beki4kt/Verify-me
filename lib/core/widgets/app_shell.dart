import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../localization_service.dart';
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
                          Color(0xFF07101D),
                          Color(0xFF0B1830),
                          Color(0xFF07111F),
                        ]
                      : const [
                          Color(0xFFF7F5F2),
                          Color(0xFFEEF1FA),
                          Color(0xFFF4F2F7),
                        ],
                  stops: const [0, .52, 1],
                ),
              ),
            ),
            const Positioned(
              top: -170,
              left: -120,
              child: _AmbientOrb(size: 430, color: AppColors.primary),
            ),
            Positioned(
              top: entry ? 120 : 40,
              right: -170,
              child: _AmbientOrb(
                size: entry ? 500 : 420,
                color: dark ? AppColors.brandOrange : const Color(0xFFFFB982),
              ),
            ),
            Positioned(
              bottom: -240,
              left: constraints.maxWidth * .18,
              child: _AmbientOrb(
                size: 520,
                color: dark ? AppColors.success : const Color(0xFF8AE5C7),
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
                    background.withValues(alpha: dark ? .34 : .18),
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
            icon: Icons.receipt_long_rounded,
            label: 'PAYMENT VERIFIED',
            value: '1,280.00 ETB',
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
            icon: Icons.table_restaurant_rounded,
            label: 'TABLE 12',
            value: 'Ready to settle',
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
    required this.label,
    required this.value,
    required this.accent,
    this.compact = false,
  });

  final bool dark;
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: dark ? .70 : .80,
    child: Container(
      width: compact ? 210 : 248,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: (dark ? AppColors.surfaceContainer : Colors.white).withValues(
          alpha: dark ? .72 : .64,
        ),
        border: Border.all(
          color: (dark ? Colors.white : AppColors.lightInk).withValues(
            alpha: .12,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .28 : .09),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: dark ? .04 : .78),
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
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.microLabel(color: accent)),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
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
      ..color = (dark ? Colors.white : AppColors.brandBlue).withValues(
        alpha: dark ? .035 : .045,
      )
      ..style = PaintingStyle.fill;

    const spacing = 44.0;
    for (double y = 22; y < size.height; y += spacing) {
      for (double x = 22; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.05, dotPaint);
      }
    }

    final bandPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15;
    final bandY = size.height * .78;
    const diamondSize = 18.0;
    for (double x = -diamondSize; x < size.width + diamondSize; x += 38) {
      final index = ((x + diamondSize) / 38).round();
      bandPaint.color =
          (index.isEven ? AppColors.brandBlue : AppColors.brandOrange)
              .withValues(alpha: dark ? .10 : .11);
      final diamond = Path()
        ..moveTo(x, bandY - diamondSize)
        ..lineTo(x + diamondSize, bandY)
        ..lineTo(x, bandY + diamondSize)
        ..lineTo(x - diamondSize, bandY)
        ..close();
      canvas.drawPath(diamond, bandPaint);
      canvas.drawCircle(Offset(x, bandY), 2, bandPaint);
    }

    final accentPaint = Paint()
      ..color = AppColors.brandOrange.withValues(alpha: dark ? .18 : .15)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width - 38, 32),
      Offset(size.width - 38, 104),
      accentPaint,
    );
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
    final alpha = Theme.of(context).brightness == Brightness.dark ? .28 : .36;
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
    this.blur = 10,
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
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .34 : .10),
            blurRadius: dark ? 28 : 24,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: dark ? .035 : .88),
            blurRadius: 12,
            offset: const Offset(-7, -7),
          ),
          if (accent != null)
            BoxShadow(
              color: accent!.withValues(alpha: dark ? .12 : .10),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter.grouped(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Material(
            color: tint.withValues(alpha: opacity ?? (dark ? .72 : .72)),
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
                      alpha: accent == null
                          ? (dark ? .14 : .10)
                          : (dark ? .40 : .30),
                    ),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: dark ? .10 : .62),
                      tint.withValues(alpha: dark ? .035 : .18),
                      (accent ?? theme.colorScheme.primary).withValues(
                        alpha: dark ? .035 : .022,
                      ),
                    ],
                    stops: const [0, .48, 1],
                  ),
                ),
                child: child,
              ),
            ),
          ),
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
            opacity: dark ? (active ? .84 : .72) : (active ? .88 : .72),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      BrandMark(size: compact ? 34 : 46),
      const SizedBox(width: 12),
      Text(
        'CHEKMI',
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(letterSpacing: 1.1),
      ),
    ],
  );
}

/// Larger centered brand treatment for entry and authentication screens.
class BrandHero extends StatelessWidget {
  const BrandHero({super.key, this.subtitle});

  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      header: true,
      label: subtitle == null ? 'CHEKMI' : 'CHEKMI. $subtitle',
      child: Column(
        children: [
          const BrandMark(size: 82),
          const SizedBox(height: AppSpacing.lg),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'CHEKMI',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                color: colors.onSurface,
                fontSize: 38,
                fontWeight: FontWeight.w900,
                letterSpacing: 4.2,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 3,
                decoration: BoxDecoration(
                  color: AppColors.brandBlue,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 5),
              Container(
                width: 14,
                height: 3,
                decoration: BoxDecoration(
                  color: AppColors.brandOrange,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ],
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

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    return IconButton(
      tooltip: context.tr(theme.isDark ? 'Light mode' : 'Dark mode'),
      onPressed: theme.toggle,
      icon: AnimatedSwitcher(
        duration: AppMotion.fast,
        transitionBuilder: (child, animation) => RotationTransition(
          turns: animation,
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: Icon(
          theme.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          key: ValueKey(theme.isDark),
        ),
      ),
    );
  }
}

class LanguageToggleButton extends StatelessWidget {
  const LanguageToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final localization = context.watch<LocalizationService>();
    return Tooltip(
      message: context.tr('Language'),
      child: TextButton.icon(
        onPressed: localization.toggleLanguage,
        icon: const Icon(Icons.translate_rounded, size: 18),
        label: Text(localization.isAmharic ? 'EN' : 'አማ'),
      ),
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 52});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
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
}
