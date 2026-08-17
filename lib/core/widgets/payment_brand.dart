import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Canonical payment-provider identity used anywhere a provider is shown.
class PaymentBrandData {
  const PaymentBrandData({
    required this.name,
    required this.asset,
    required this.color,
  });

  final String name;
  final String asset;
  final Color color;

  static PaymentBrandData resolve(String provider) {
    final key = provider.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (key.contains('telebirr')) {
      return const PaymentBrandData(
        name: 'Telebirr',
        asset: 'assets/payment_logos/telebirr.png',
        color: AppColors.telebirr,
      );
    }
    if (key.contains('cbebirr')) {
      return const PaymentBrandData(
        name: 'CBE Birr',
        asset: 'assets/payment_logos/cbe_birr.png',
        color: Color(0xFF7C3AED),
      );
    }
    if (key == 'cbe' || key.contains('commercialbankofethiopia')) {
      return const PaymentBrandData(
        name: 'CBE',
        asset: 'assets/payment_logos/cbe.png',
        color: Color(0xFFA855F7),
      );
    }
    if (key.contains('dashen')) {
      return const PaymentBrandData(
        name: 'Dashen',
        asset: 'assets/payment_logos/dashen.png',
        color: Color(0xFFF59E0B),
      );
    }
    if (key.contains('abyssinia')) {
      return const PaymentBrandData(
        name: 'Abyssinia',
        asset: 'assets/payment_logos/abyssinia.png',
        color: Color(0xFFEF4444),
      );
    }
    if (key.contains('mpesa') || key.contains('safaricom')) {
      return const PaymentBrandData(
        name: 'M-Pesa',
        asset: 'assets/payment_logos/mpesa.png',
        color: Color(0xFF22C55E),
      );
    }
    return PaymentBrandData(
      name: provider.trim().isEmpty ? 'Payment' : provider,
      asset: '',
      color: AppColors.primary,
    );
  }
}

class PaymentLogo extends StatelessWidget {
  const PaymentLogo({
    super.key,
    required this.provider,
    this.size = 32,
    this.padding = 5,
  });

  final String provider;
  final double size;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final brand = PaymentBrandData.resolve(provider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      image: true,
      label: '${brand.name} logo',
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: dark ? .92 : .82),
          borderRadius: BorderRadius.circular(size * .3),
          border: Border.all(
            color: brand.color.withValues(alpha: dark ? .34 : .2),
          ),
          boxShadow: [
            BoxShadow(
              color: brand.color.withValues(alpha: .12),
              blurRadius: 9,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: brand.asset.isEmpty
            ? Icon(
                Icons.account_balance_wallet_rounded,
                color: brand.color,
                size: size * .52,
              )
            : Image.asset(
                brand.asset,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, _, _) => Icon(
                  Icons.account_balance_wallet_rounded,
                  color: brand.color,
                  size: size * .52,
                ),
              ),
      ),
    );
  }
}

class PaymentBrand extends StatelessWidget {
  const PaymentBrand({
    super.key,
    required this.provider,
    this.logoSize = 30,
    this.style,
    this.compactName = false,
  });

  final String provider;
  final double logoSize;
  final TextStyle? style;
  final bool compactName;

  @override
  Widget build(BuildContext context) {
    final brand = PaymentBrandData.resolve(provider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PaymentLogo(provider: provider, size: logoSize),
        const SizedBox(width: 9),
        Flexible(
          child: Text(
            compactName ? brand.name : provider,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                style ??
                Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
