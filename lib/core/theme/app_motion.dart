import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// The Verify-me motion language.
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

  static const Duration fast = Duration(milliseconds: 200);
  static const Duration base = Duration(milliseconds: 400);
  static const Duration slow = Duration(milliseconds: 600);

  static const Curve easeOutCustom = Curves.easeOut;
  static const Curve easeOutBack = Curves.easeOutBack;

  /// Stagger delay for the [index]-th item in a list.
  static Duration stagger(int index, {int perItemMs = 20}) =>
      Duration(milliseconds: perItemMs * index);
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
  const SuccessPop({super.key, required this.child, this.delay = Duration.zero});
  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) => child
      .animate()
      .fadeIn(delay: delay)
      .scaleXY(
        begin: 0.8,
        end: 1.0,
        duration: AppMotion.base,
        curve: AppMotion.easeOutBack,
      );
}
