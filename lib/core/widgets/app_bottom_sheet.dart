import 'package:flutter/material.dart';
import 'package:verify_me/core/theme/app_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Standardized modal bottom sheet shell (rounded top, padded body via [AppSheetBody]).
/// Colors/shape come from [AppTheme]'s `BottomSheetThemeData`, so we don't pass
/// deprecated `backgroundColor`/`shape` here.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool dismissible = true,
  bool enableDrag = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    isDismissible: dismissible,
    enableDrag: enableDrag,
    builder: builder,
  );
}

/// The standard padded body of an app sheet. Wraps children in a scroll view and
/// handles the keyboard inset automatically.
class AppSheetBody extends StatelessWidget {
  const AppSheetBody({
    super.key,
    required this.children,
    this.topPadding = AppSpacing.xxxl,
    this.bottomPadding = AppSpacing.xl,
  });

  final List<Widget> children;
  final double topPadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + bottomPadding,
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: topPadding,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

/// Standard sheet header: colored title on the left, optional close button on the right.
class AppSheetHeader extends StatelessWidget {
  const AppSheetHeader({
    super.key,
    required this.title,
    this.color = AppColors.primary,
    this.onClose,
  });

  final String title;
  final Color color;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            fontSize: 12,
          ),
        ),
        if (onClose != null)
          IconButton(
            icon: const Icon(AppIcons.close, color: Color(0x88FFFFFF)),
            onPressed: onClose,
          ),
      ],
    );
  }
}
