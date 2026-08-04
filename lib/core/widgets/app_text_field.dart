import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Standardized text field used across all forms (login, provisioning, sheets).
/// Replaces the 3 duplicated `_buildInputDecoration` implementations.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.icon,
    this.prefixText, // e.g. "+2519" for the phone prefix block
    this.obscure = false,
    this.keyboardType,
    this.inputFormatters,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
    this.style,
    this.textAlign,
    this.onChanged,
    this.enabled = true,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final IconData? icon;
  final String? prefixText;
  final bool obscure;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final TextCapitalization textCapitalization;
  final TextStyle? style;
  final TextAlign? textAlign;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // A plain InputDecoration is merged with Theme.inputDecorationTheme
    // automatically by TextField — so the theme supplies fill/border/labelStyle,
    // and we only override the per-field bits here.
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      textCapitalization: textCapitalization,
      style: style ?? const TextStyle(color: Colors.white),
      textAlign: textAlign ?? TextAlign.start,
      onChanged: onChanged,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: _buildPrefix(),
      ),
    );
  }

  Widget? _buildPrefix() {
    if (icon == null && prefixText == null) return null;

    if (prefixText != null && icon != null) {
      return Padding(
        padding: const EdgeInsets.only(left: AppSpacing.lg, right: AppSpacing.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: AppSpacing.md),
            Text(
              prefixText!,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(width: 2, height: 24, color: AppColors.hairline),
            const SizedBox(width: AppSpacing.md),
          ],
        ),
      );
    }
    if (prefixText != null) {
      return Padding(
        padding: const EdgeInsets.only(left: AppSpacing.lg, right: AppSpacing.sm),
        child: Text(
          prefixText!,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
        ),
      );
    }
    return Icon(icon, color: AppColors.primary);
  }
}
