import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:motor/motor.dart';

import '../config/runtime_environment.dart';

/// The CHEKMI motion language.
///
/// Standard patterns (use these consistently across screens):
///  • Page entrance        : FadeSlideIn(beginY: 0.1)            → 400ms easeOut
///  • List item entrance   : FadeSlideIn(index: i)              → 400ms, 20ms/item stagger
///  • Card / sheet appear  : FadeSlideIn(beginY: 0.2)            → 400ms easeOut
///  • Success feedback     : SuccessPop                          → scale 0.8→1 bounce
///  • Error feedback       : .shake()                            → 300ms
///  • Active shimmer       : .shimmer(duration: 2000.ms)        → easeInOut
class AppMotion {
  AppMotion._();

  static const Duration instant = Duration(milliseconds: 120);
  static const Duration fast = Duration(milliseconds: 140);
  static const Duration base = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 280);
  static const Duration page = Duration(milliseconds: 340);

  static const Curve easeOutCustom = Curves.easeOutCubic;
  static const Curve easeOutBack = Curves.easeOutBack;

  /// Content swaps (tab bodies, scanner states) use fade-through so the
  /// outgoing surface leaves before the next arrives — clear, never jumpy.
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;

  /// Motor springs used for interactive elements. Spatial movement uses a
  /// restrained expressive spring; quick feedback uses a tighter spring.
  static const Motion spatial = MaterialSpringMotion.expressiveSpatialDefault();
  static const Motion interactive = MaterialSpringMotion.standardSpatialFast();
  static const Motion gentle = CupertinoMotion.smooth(
    duration: Duration(milliseconds: 520),
  );

  /// Stagger delay for the [index]-th item in a list.
  static Duration stagger(int index, {int perItemMs = 20}) =>
      Duration(milliseconds: perItemMs * index);

  /// Whether perpetual animation loops (shimmer, breathing) may run.
  /// Entrance and transition animations are unaffected — only infinite
  /// repeats are gated, so `pumpAndSettle` can settle under `flutter test`.
  static final bool loopingAnimationsAllowed = !runningInFlutterTest;
}

/// Animates scale changes with Motor's physics while respecting the platform's
/// reduced-motion preference. This is intentionally small and reusable so the
/// whole app shares one tactile interaction language.
class MotorScale extends StatelessWidget {
  const MotorScale({
    super.key,
    required this.child,
    required this.scale,
    this.motion = AppMotion.interactive,
  });

  final Widget child;
  final double scale;
  final Motion motion;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations == true) return child;
    return SingleMotionBuilder(
      value: scale,
      motion: motion,
      builder: (context, value, child) => Transform.scale(
        scale: value,
        alignment: Alignment.center,
        child: child,
      ),
      child: child,
    );
  }
}

/// Standard fade + vertical-slide entrance. Use for pages, cards, and list items.
/// Pass [index] to stagger list items (20ms per item by default).
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.beginY = 0.1,
    this.beginX = 0.0,
    this.delay = Duration.zero,
    this.duration = AppMotion.base,
    this.index,
  });

  final Widget child;
  final double beginY;
  final double beginX;
  final Duration delay;
  final Duration duration;
  final int? index; // when set, overrides delay with a stagger

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations == true) return child;
    final d = index != null ? AppMotion.stagger(index!) : delay;
    return child
        .animate()
        .fadeIn(duration: duration, delay: d, curve: AppMotion.easeOutCustom)
        .slide(
          begin: Offset(beginX, beginY),
          end: Offset.zero,
          duration: duration,
          delay: d,
          curve: AppMotion.easeOutCustom,
        );
  }
}

/// Success emphasis: a scale pop used after a verified/settled action.
/// Note: flutter_animate's `scale` takes scale factors (doubles), not Offsets.
class SuccessPop extends StatelessWidget {
  const SuccessPop({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });
  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations == true) return child;
    return child
        .animate()
        .fadeIn(delay: delay)
        .scaleXY(
          begin: 0.8,
          end: 1.0,
          duration: AppMotion.base,
          curve: AppMotion.easeOutBack,
        );
  }
}

/// Tactile press feedback for custom tappable rows and cards.
///
/// Wraps any child in a spring scale-down while pressed (with a light
/// selection haptic), giving non-Button widgets the same physicality as the
/// app's Material buttons. Respects reduced-motion by skipping the scale.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
    this.haptic = true,
    this.pressedScale = .975,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;
  final bool haptic;
  final double pressedScale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _set(bool value) {
    if (!widget.enabled || _pressed == value) return;
    setState(() => _pressed = value);
    if (value && widget.haptic) HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveOnTap = widget.enabled ? widget.onTap : null;
    return MouseRegion(
      cursor: effectiveOnTap == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      child: Listener(
        onPointerDown: effectiveOnTap == null ? null : (_) => _set(true),
        onPointerUp: effectiveOnTap == null ? null : (_) => _set(false),
        onPointerCancel: effectiveOnTap == null ? null : (_) => _set(false),
        child: MotorScale(
          scale: _pressed ? widget.pressedScale : 1,
          child: effectiveOnTap == null
              ? widget.child
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: effectiveOnTap,
                  child: widget.child,
                ),
        ),
      ),
    );
  }
}

/// A fade-through switcher for swapping between related content — scanner
/// states, tab bodies, filter results. The outgoing child fades out slightly
/// scaled down; the incoming one fades in from just below, so the swap reads
/// as one deliberate motion instead of a hard cut.
class FadeThroughSwitcher extends StatelessWidget {
  const FadeThroughSwitcher({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.slideOffset = const Offset(0, .03),
  });

  final Widget child;
  final Duration duration;
  final Offset slideOffset;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations == true) {
      return AnimatedSwitcher(duration: Duration.zero, child: child);
    }
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: AppMotion.emphasized,
      switchOutCurve: AppMotion.emphasized,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: slideOffset,
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.center,
        children: [...previousChildren, ?currentChild],
      ),
      child: child,
    );
  }
}
