import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_motion.dart';
import '../core/widgets/app_shell.dart';

class IPhoneTabItem {
  const IPhoneTabItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

/// Switches dashboard sections without disposing inactive iPhone tabs.
/// Material layouts can retain their animated TabBarView behavior.
class DashboardTabView extends StatelessWidget {
  const DashboardTabView({
    super.key,
    required this.children,
    required this.preserveState,
    this.physics,
  });

  final List<Widget> children;
  final bool preserveState;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    if (!preserveState) {
      return TabBarView(physics: physics, children: children);
    }
    return _PersistentIndexedTabView(children: children);
  }
}

class _PersistentIndexedTabView extends StatefulWidget {
  const _PersistentIndexedTabView({required this.children});

  final List<Widget> children;

  @override
  State<_PersistentIndexedTabView> createState() =>
      _PersistentIndexedTabViewState();
}

class _PersistentIndexedTabViewState extends State<_PersistentIndexedTabView> {
  TabController? _controller;
  int _index = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextController = DefaultTabController.of(context);
    if (identical(nextController, _controller)) return;
    _controller?.removeListener(_handleTabChange);
    _controller = nextController..addListener(_handleTabChange);
    _index = nextController.index;
  }

  void _handleTabChange() {
    final nextIndex = _controller?.index ?? 0;
    if (!mounted || nextIndex == _index) return;
    setState(() => _index = nextIndex);
  }

  @override
  void dispose() {
    _controller?.removeListener(_handleTabChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return IndexedStack(index: _index, children: widget.children);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var index = 0; index < widget.children.length; index++)
          _PersistentTabPage(
            active: index == _index,
            offset: index < _index
                ? const Offset(-.025, 0)
                : const Offset(.025, 0),
            child: widget.children[index],
          ),
      ],
    );
  }
}

class _PersistentTabPage extends StatelessWidget {
  const _PersistentTabPage({
    required this.active,
    required this.offset,
    required this.child,
  });

  final bool active;
  final Offset offset;
  final Widget child;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !active,
    child: ExcludeSemantics(
      excluding: !active,
      child: AnimatedOpacity(
        opacity: active ? 1 : 0,
        duration: AppMotion.base,
        curve: AppMotion.easeOutCustom,
        child: AnimatedSlide(
          offset: active ? Offset.zero : offset,
          duration: AppMotion.base,
          curve: AppMotion.easeOutCustom,
          child: TickerMode(enabled: active, child: child),
        ),
      ),
    ),
  );
}

/// A stable iOS tab bar for dashboards that already use a DefaultTabController.
///
/// Keeping the controller above the scaffold preserves every tab's scroll and
/// stream state while moving primary navigation to the conventional iPhone
/// location at the bottom of the screen.
class IPhoneBottomTabBar extends StatelessWidget {
  const IPhoneBottomTabBar({super.key, required this.items});

  final List<IPhoneTabItem> items;

  @override
  Widget build(BuildContext context) {
    final controller = DefaultTabController.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Container(
          height: 70,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHigh.withValues(
              alpha: dark ? .96 : .98,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: dark ? .38 : .45),
              width: .6,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? .32 : .10),
                blurRadius: 24,
                spreadRadius: -6,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final selected = controller.index == index;
              return Expanded(
                child: Semantics(
                  selected: selected,
                  button: true,
                  label: item.label,
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(44, 58),
                    onPressed: () {
                      if (controller.index == index) return;
                      HapticFeedback.selectionClick();
                      controller.animateTo(index);
                    },
                    child: AnimatedContainer(
                      duration: AppMotion.base,
                      curve: AppMotion.easeOutCustom,
                      height: 58,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary.withValues(
                                alpha: dark ? .20 : .12,
                              )
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(19),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedScale(
                            scale: selected ? 1.06 : .94,
                            duration: AppMotion.base,
                            curve: Curves.easeOutBack,
                            child: Icon(
                              item.icon,
                              size: selected ? 22 : 21,
                              color: selected
                                  ? AppColors.primary
                                  : colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 3),
                          AnimatedDefaultTextStyle(
                            duration: AppMotion.base,
                            curve: AppMotion.easeOutCustom,
                            style: (Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: selected
                                      ? AppColors.primary
                                      : colors.onSurfaceVariant,
                                  fontSize: 11,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  letterSpacing: -.1,
                                ))!,
                            child: Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class IPhoneDashboardNavigationBar extends StatelessWidget
    implements PreferredSizeWidget {
  const IPhoneDashboardNavigationBar({
    super.key,
    required this.title,
    required this.onSignOut,
    required this.onRefresh,
    this.onHelp,
  });

  final Widget title;
  final Future<void> Function() onSignOut;
  final VoidCallback? onHelp;
  final VoidCallback onRefresh;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 64,
      leadingWidth: 54,
      titleSpacing: 2,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: theme.colorScheme.surface.withValues(
        alpha: dark ? .98 : .97,
      ),
      leading: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: CupertinoButton(
          key: const Key('iphone-dashboard-sign-out'),
          padding: EdgeInsets.zero,
          minimumSize: const Size.square(44),
          onPressed: onSignOut,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: CupertinoColors.systemRed
                  .resolveFrom(context)
                  .withValues(alpha: dark ? .15 : .10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              AppIcons.logout,
              size: 18,
              color: CupertinoColors.systemRed,
            ),
          ),
        ),
      ),
      title: DefaultTextStyle(
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -.45,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        child: title,
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 5),
          child: IPhoneHeaderControls(onHelp: onHelp, onRefresh: onRefresh),
        ),
      ],
    );
  }
}

/// Keeps essential preferences and data refresh visible with 44-point touch
/// targets while their quieter 30-point visuals fit the iPhone navigation bar.
class IPhoneHeaderControls extends StatelessWidget {
  const IPhoneHeaderControls({super.key, this.onHelp, this.onRefresh});

  final VoidCallback? onHelp;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const GlassLanguageToggleButton(
          key: Key('iphone-language-toggle'),
          iPhoneStyle: true,
        ),
        const GlassThemeToggleButton(
          key: Key('iphone-theme-toggle'),
          iPhoneStyle: true,
        ),
        if (onRefresh != null) _IPhoneRefreshButton(onRefresh: onRefresh!),
        if (onHelp != null)
          CupertinoButton(
            key: const Key('iphone-dashboard-help'),
            padding: EdgeInsets.zero,
            minimumSize: const Size.square(44),
            onPressed: onHelp,
            child: const _IPhoneHeaderIconSurface(icon: AppIcons.support),
          ),
      ],
    ),
  );
}

class _IPhoneRefreshButton extends StatefulWidget {
  const _IPhoneRefreshButton({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  State<_IPhoneRefreshButton> createState() => _IPhoneRefreshButtonState();
}

class _IPhoneRefreshButtonState extends State<_IPhoneRefreshButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _refresh() {
    if (_controller.isAnimating) return;
    widget.onRefresh();
    if (!(MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
      _controller.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) => CupertinoButton(
    key: const Key('iphone-dashboard-refresh'),
    padding: EdgeInsets.zero,
    minimumSize: const Size.square(44),
    onPressed: _refresh,
    child: RotationTransition(
      turns: CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
      child: const _IPhoneHeaderIconSurface(icon: AppIcons.refresh),
    ),
  );
}

class _IPhoneHeaderIconSurface extends StatelessWidget {
  const _IPhoneHeaderIconSurface({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 34,
    height: 34,
    decoration: BoxDecoration(
      color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(icon, size: 17, color: AppColors.primary),
  );
}
