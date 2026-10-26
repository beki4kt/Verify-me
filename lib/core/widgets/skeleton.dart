import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';

/// A single shimmer skeleton block. Used while lists/streams load instead of
/// a centered spinner — far more premium for a financial UI.
class Skeleton extends StatelessWidget {
  const Skeleton({
    super.key,
    this.width = double.infinity,
    this.height = 14,
    this.shape = AppShapes.cardSm,
  });

  final double width;
  final double height;
  final ShapeBorder shape;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerHighest.withValues(alpha: .7);
    final highlight = scheme.brightness == Brightness.dark
        ? const Color(0x22FFFFFF)
        : Colors.white.withValues(alpha: .75);
    final block = Container(
      width: width,
      height: height,
      decoration: ShapeDecoration(color: base, shape: shape),
    );
    if (!AppMotion.loopingAnimationsAllowed) return block;
    return block
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1200.ms, color: highlight);
  }
}

/// A placeholder row shaped like a ticket ledger entry, used by list builders
/// while the stream is still loading.
class TicketSkeletonRow extends StatelessWidget {
  const TicketSkeletonRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Skeleton(width: 44, height: 44, shape: AppShapes.pill),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Skeleton(width: 120, height: 16),
                SizedBox(height: 8),
                Skeleton(width: 200, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
