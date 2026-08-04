import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import '../theme/app_typography.dart';

/// Shows a brief, premium "verified / settled" moment: a springing checkmark
/// card with a haptic, auto-dismissing after ~1.3s. Asset-free (drawn), so it
/// always works offline. Callers can swap in a Lottie asset later.
class SuccessOverlay {
  SuccessOverlay._();

  static Future<void> show(BuildContext context, {String message = 'Verified'}) {
    HapticFeedback.mediumImpact();
    return showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => _SuccessOverlay(message: message),
    );
  }
}

class _SuccessOverlay extends StatefulWidget {
  const _SuccessOverlay({required this.message});
  final String message;

  @override
  State<_SuccessOverlay> createState() => _SuccessOverlayState();
}

class _SuccessOverlayState extends State<_SuccessOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: 750.ms,
    )..forward();
    Future.delayed(1400.ms, () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(24),
          decoration: const ShapeDecoration(
            color: AppColors.surfaceContainerHigh,
            shape: AppShapes.card,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) {
                  return SizedBox(
                    width: 88,
                    height: 88,
                    child: CustomPaint(painter: _CheckPainter(_ctrl.value)),
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                widget.message,
                style: AppTypography.microLabel(color: AppColors.success).copyWith(
                  fontSize: 12,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(duration: AppMotion.fast)
            .scale(begin: const Offset(0.85, 0.85), end: const Offset(1, 1), curve: AppMotion.easeOutBack),
      ),
    );
  }
}

/// Draws an animated success mark: a completing emerald ring + a check that
/// strokes in once the ring is ~50% done.
class _CheckPainter extends CustomPainter {
  _CheckPainter(this.progress); // 0..1
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 6;

    final ring = Paint()
      ..color = AppColors.success
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      -pi / 2,
      2 * pi * progress.clamp(0.0, 1.0),
      false,
      ring,
    );

    if (progress <= 0.5) return;
    final cp = ((progress - 0.5) / 0.5).clamp(0.0, 1.0);
    final p = Paint()
      ..color = AppColors.success
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final p1 = center + Offset(-r * 0.45, 2);
    final p2 = center + Offset(-r * 0.08, r * 0.38);
    final p3 = center + Offset(r * 0.5, -r * 0.38);

    if (cp <= 0.5) {
      final t = cp / 0.5;
      canvas.drawLine(p1, Offset.lerp(p1, p2, t)!, p);
    } else {
      canvas.drawLine(p1, p2, p);
      final t = (cp - 0.5) / 0.5;
      canvas.drawLine(p2, Offset.lerp(p2, p3, t)!, p);
    }
  }

  @override
  bool shouldRepaint(covariant _CheckPainter old) => old.progress != progress;
}
