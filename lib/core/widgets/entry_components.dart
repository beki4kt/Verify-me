import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// The approved Chekmi entry language is scoped to launch and onboarding.
/// Operational screens retain their existing theme during the rollout.
abstract final class EntryColors {
  static const background = Color(0xFF0B1020);
  static const surface = Color(0xFF171D35);
  static const selected = Color(0xFF203A61);
  static const line = Color(0xFF34415F);
  static const blue = Color(0xFF2F8CFF);
  static const blueDeep = Color(0xFF2168C5);
  static const orange = Color(0xFFFF8A00);
  static const text = Color(0xFFF4F7FF);
  static const muted = Color(0xFFA3B0CA);
  static const error = Color(0xFFFF9B8A);
}

class ChekmiEntryTheme extends StatelessWidget {
  const ChekmiEntryTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.dark(useMaterial3: true);
    return Theme(
      data: base.copyWith(
        scaffoldBackgroundColor: EntryColors.background,
        colorScheme: const ColorScheme.dark(
          primary: EntryColors.blue,
          onPrimary: EntryColors.text,
          surface: EntryColors.surface,
          onSurface: EntryColors.text,
          onSurfaceVariant: EntryColors.muted,
          outline: EntryColors.line,
          error: EntryColors.error,
        ),
        textTheme: base.textTheme.apply(
          bodyColor: EntryColors.text,
          displayColor: EntryColors.text,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: EntryColors.surface,
          labelStyle: const TextStyle(color: EntryColors.muted),
          hintStyle: const TextStyle(color: EntryColors.muted),
          prefixIconColor: EntryColors.muted,
          suffixIconColor: EntryColors.muted,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: EntryColors.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: EntryColors.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: EntryColors.blue, width: 1.5),
          ),
        ),
      ),
      child: child,
    );
  }
}

class EntryBrandMark extends StatelessWidget {
  const EntryBrandMark({super.key, this.size = 68, this.wordmark = false});

  final double size;
  final bool wordmark;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Image.asset(
        'assets/branding/chekmi_mark_256.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        semanticLabel: 'Chekmi',
      ),
      if (wordmark) ...[
        const SizedBox(height: 9),
        const Text(
          'Chekmi',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.1,
          ),
        ),
      ],
    ],
  );
}

class EntryActionButton extends StatelessWidget {
  const EntryActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.outlined = false,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool outlined;
  final bool loading;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 51,
    child: OutlinedButton(
      onPressed: loading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: outlined ? EntryColors.surface : EntryColors.blueDeep,
        foregroundColor: EntryColors.text,
        side: BorderSide(
          color: outlined ? EntryColors.line : EntryColors.blueDeep,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (icon != null && !loading)
            Align(alignment: Alignment.centerLeft, child: Icon(icon, size: 19)),
          loading
              ? const SizedBox.square(
                  dimension: 19,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ],
      ),
    ),
  );
}

class EntryBackButton extends StatelessWidget {
  const EntryBackButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 44,
    child: IconButton.outlined(
      onPressed: onPressed,
      tooltip: 'Back',
      style: IconButton.styleFrom(
        foregroundColor: EntryColors.text,
        backgroundColor: EntryColors.surface,
        side: const BorderSide(color: EntryColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
      icon: const Icon(CupertinoIcons.chevron_back, size: 18),
    ),
  );
}

class EntryStepProgress extends StatelessWidget {
  const EntryStepProgress({super.key, required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text(
        '${step.toString().padLeft(2, '0')} / ${total.toString().padLeft(2, '0')}',
        style: const TextStyle(
          color: EntryColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 15),
      Row(
        children: List.generate(
          total,
          (index) => Expanded(
            child: Container(
              height: 3,
              margin: EdgeInsets.only(right: index == total - 1 ? 0 : 5),
              decoration: BoxDecoration(
                color: index < step ? EntryColors.blue : EntryColors.line,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
