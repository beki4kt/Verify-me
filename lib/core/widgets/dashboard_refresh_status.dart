import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show ValueListenable;

import '../theme/app_colors.dart';

@immutable
class DashboardRefreshState {
  const DashboardRefreshState({this.lastUpdated, this.isRefreshing = false});

  final DateTime? lastUpdated;
  final bool isRefreshing;

  DashboardRefreshState copyWith({DateTime? lastUpdated, bool? isRefreshing}) =>
      DashboardRefreshState(
        lastUpdated: lastUpdated ?? this.lastUpdated,
        isRefreshing: isRefreshing ?? this.isRefreshing,
      );
}

String dashboardRefreshLabel(DashboardRefreshState state, {DateTime? now}) {
  if (state.isRefreshing) return 'Refreshing payments…';
  if (state.lastUpdated == null) return 'Waiting for live data';
  final elapsed = (now ?? DateTime.now()).difference(state.lastUpdated!);
  if (elapsed.inSeconds < 2) return 'Updated just now';
  if (elapsed.inSeconds < 60) return 'Updated ${elapsed.inSeconds}s ago';
  if (elapsed.inMinutes < 60) return 'Updated ${elapsed.inMinutes}m ago';
  return 'Updated ${elapsed.inHours}h ago';
}

class DashboardRefreshStatus extends StatefulWidget {
  const DashboardRefreshStatus({
    super.key,
    required this.listenable,
    required this.onRefresh,
  });

  final ValueListenable<DashboardRefreshState> listenable;
  final VoidCallback onRefresh;

  @override
  State<DashboardRefreshStatus> createState() => _DashboardRefreshStatusState();
}

class _DashboardRefreshStatusState extends State<DashboardRefreshStatus> {
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DashboardRefreshState>(
      valueListenable: widget.listenable,
      builder: (context, state, _) => Material(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: .6),
        child: InkWell(
          onTap: state.isRefreshing ? null : widget.onRefresh,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 16,
                  child: state.isRefreshing
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : const Icon(
                          Icons.cloud_done_outlined,
                          size: 16,
                          color: AppColors.success,
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dashboardRefreshLabel(state),
                    key: const Key('dashboard-refresh-label'),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  Icons.refresh,
                  size: 17,
                  color: state.isRefreshing
                      ? Theme.of(context).colorScheme.onSurface
                            .withValues(alpha: .3)
                      : AppColors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
