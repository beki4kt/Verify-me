import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
    return Container(
          width: width,
          height: height,
          decoration: ShapeDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh
                .withValues(alpha: .7),
            shape: shape,
          ),
        )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1200.ms, color: const Color(0x22FFFFFF));
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
