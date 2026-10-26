import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:verify_me/core/theme/app_icons.dart';

import '../theme/app_motion.dart';

/// A quiet, branded loading state: three violet dots pulse in sequence.
/// Theme-aware (unlike a raw Material spinner) and calm enough for a
/// financial product.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _PulsingDots(),
          if (message != null) ...[
            const SizedBox(height: 18),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: .2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PulsingDots extends StatelessWidget {
  const _PulsingDots();

  static const _durations = [1050, 1050, 1050];

  @override
  Widget build(BuildContext context) {
    if ((MediaQuery.maybeDisableAnimationsOf(context) ?? false) ||
        !AppMotion.loopingAnimationsAllowed) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (_) => _dot(context)),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < 3; index++)
          _dot(context)
              .animate(onPlay: (controller) => controller.repeat())
              .scaleXY(
                begin: .72,
                end: 1.08,
                duration: _durations[index].ms,
                delay: (index * 160).ms,
                curve: Curves.easeInOut,
              ),
      ],
    );
  }

  Widget _dot(BuildContext context) => Container(
    width: 13,
    height: 13,
    margin: const EdgeInsets.symmetric(horizontal: 5),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary,
      shape: BoxShape.circle,
    ),
  );
}

/// Standardized empty state: a breathing icon disc, message, and an optional
/// action so the state is always a doorway, not a dead end.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.message,
    this.icon = AppIcons.inbox,
    this.title,
    this.actionLabel,
    this.onAction,
  });
  final String message;
  final IconData icon;
  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final disabled = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    Widget disc = Container(
      width: 84,
      height: 84,
      decoration: ShapeDecoration(
        color: scheme.primary.withValues(alpha: .09),
        shape: const CircleBorder(),
      ),
      child: Icon(icon, color: scheme.primary, size: 34),
    );
    if (!disabled && AppMotion.loopingAnimationsAllowed) {
      disc = disc
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .scaleXY(
            begin: .96,
            end: 1.04,
            duration: 2100.ms,
            curve: Curves.easeInOut,
          );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            disc,
            if (title != null) ...[
              const SizedBox(height: 18),
              Text(
                title!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Full-page calm, actionable failure state with a retry action.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    this.title = 'Something went wrong',
    this.onRetry,
    this.retryLabel = 'Try again',
  });
  final String message;
  final String title;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: ShapeDecoration(
                color: scheme.error.withValues(alpha: .09),
                shape: const CircleBorder(),
              ),
              child: Icon(AppIcons.warning, color: scheme.error, size: 34),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(AppIcons.refresh, size: 18),
                label: Text(retryLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Offline state, visually consistent with [ErrorView] but clearly
/// non-destructive: the data simply is not reachable right now.
class OfflineView extends StatelessWidget {
  const OfflineView({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: ShapeDecoration(
                color: scheme.onSurfaceVariant.withValues(alpha: .08),
                shape: const CircleBorder(),
              ),
              child: Icon(
                AppIcons.offline,
                color: scheme.onSurfaceVariant,
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'You’re offline',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(AppIcons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Inline error banner used inside sheets and forms. Shakes once on appear so
/// the failure is noticed without alarm, and stays visible (no auto-dismiss)
/// so the user can act on it.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final banner = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: ShapeDecoration(
        color: scheme.error.withValues(alpha: .08),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(AppIcons.error, color: scheme.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.error,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return banner;
    return banner.animate().fadeIn(duration: AppMotion.fast).shake();
  }
}
