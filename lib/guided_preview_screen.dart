import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'core/theme/app_colors.dart';
import 'trial_mode_screen.dart';

/// Offline-safe product walkthrough. Its sample is deliberately illustrative;
/// only the separately labelled live demo can check a real receipt.
class GuidedPreviewScreen extends StatelessWidget {
  const GuidedPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Explore Chekmi')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        children: [
          Text(
            'A clear answer for every payment.',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 9),
          const Text(
            'This guided preview uses sample data. It does not contact a bank or save a payment.',
          ),
          const SizedBox(height: 26),
          _PreviewStep(
            number: '01',
            icon: CupertinoIcons.viewfinder,
            title: 'Scan or enter a receipt',
            detail: 'Choose the provider, add the bank reference, and enter the amount due.',
          ),
          _PreviewStep(
            number: '02',
            icon: CupertinoIcons.person_crop_circle_badge_checkmark,
            title: 'Confirm the destination',
            detail: 'Chekmi checks the payment against your configured receiving account.',
          ),
          _PreviewStep(
            number: '03',
            icon: CupertinoIcons.checkmark_shield,
            title: 'See the result',
            detail: 'Bank verification and your business completion are shown separately.',
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SAMPLE RESULT',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.primary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Payment verified',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  const Text('ETB 250.00 · Telebirr · Order ORD-208'),
                  const SizedBox(height: 10),
                  const Text(
                    'Marked complete automatically',
                    style: TextStyle(color: AppColors.success),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              CupertinoPageRoute<void>(builder: (_) => const TrialModeScreen()),
            ),
            icon: const Icon(CupertinoIcons.arrow_up_right_square),
            label: const Text('Try a live demo receipt check'),
          ),
          const SizedBox(height: 8),
          Text(
            'Live checks require the demo service to be available.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}

class _PreviewStep extends StatelessWidget {
  const _PreviewStep({
    required this.number,
    required this.icon,
    required this.title,
    required this.detail,
  });
  final String number;
  final IconData icon;
  final String title;
  final String detail;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$number  $title',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 5),
                  Text(detail, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
