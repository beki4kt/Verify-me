import 'package:flutter/material.dart';

import 'api_service.dart';
import 'core/config/payment_context.dart';
import 'core/models/workspace_profile.dart';
import 'core/theme/app_colors.dart';
import 'workspace_accounts_screen.dart';
import 'localization_service.dart';

class WorkspaceSettingsScreen extends StatefulWidget {
  const WorkspaceSettingsScreen({super.key, required this.profile});
  final WorkspaceProfile profile;

  @override
  State<WorkspaceSettingsScreen> createState() =>
      _WorkspaceSettingsScreenState();
}

class _WorkspaceSettingsScreenState extends State<WorkspaceSettingsScreen> {
  late String _useCase = widget.profile.useCase;
  late String _reference = widget.profile.defaultReferenceKind;
  late String _review = widget.profile.reviewPolicy;
  late bool _tips = widget.profile.tipsEnabled;
  late String _overpaymentPolicy = widget.profile.overpaymentPolicy;
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ApiService.updateWorkspaceProfile(
        useCase: _useCase,
        defaultReferenceKind: _reference,
        reviewPolicy: _review,
        tipsEnabled: _tips,
        overpaymentPolicy: _overpaymentPolicy,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workspace settings saved.')),
      );
      Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Payment settings'))),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text(
            context.tr('How this workspace handles payments'),
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose the flow your team needs. You can change it later.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 28),
          DropdownButtonFormField<String>(
            initialValue: _useCase,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Workspace preset'),
            items: const [
              DropdownMenuItem(value: 'general', child: Text('General')),
              DropdownMenuItem(value: 'personal', child: Text('Personal')),
              DropdownMenuItem(value: 'shop', child: Text('Shop')),
              DropdownMenuItem(value: 'restaurant', child: Text('Restaurant')),
              DropdownMenuItem(
                value: 'service',
                child: Text('Service provider'),
              ),
            ],
            onChanged: _saving
                ? null
                : (value) => setState(() {
                    _useCase = value ?? _useCase;
                    if (_useCase != 'restaurant') {
                      _overpaymentPolicy = 'unresolved';
                    }
                    _reference = switch (_useCase) {
                      'restaurant' => 'table',
                      'service' => 'invoice',
                      'shop' => 'order',
                      _ => 'none',
                    };
                  }),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            key: ValueKey(_reference),
            initialValue: _reference,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: context.tr('Default payment reference'),
            ),
            items: PaymentContextKind.values
                .where((kind) => kind != PaymentContextKind.other)
                .map(
                  (kind) => DropdownMenuItem(
                    value: kind.name,
                    child: Text(context.tr(kind.label)),
                  ),
                )
                .toList(),
            onChanged: _saving
                ? null
                : (value) => setState(() => _reference = value ?? _reference),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            initialValue: _review,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: context.tr('After payment verification'),
            ),
            items: [
              DropdownMenuItem(
                value: 'automatic',
                child: Text(context.tr('Mark complete automatically')),
              ),
              DropdownMenuItem(
                value: 'review_required',
                child: Text(context.tr('Require a team review')),
              ),
            ],
            onChanged: _saving
                ? null
                : (value) => setState(() => _review = value ?? _review),
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Allow tip features'),
            subtitle: Text(
              _overpaymentPolicy == 'legacy_tip'
                  ? 'This workspace still uses its existing tip flow.'
                  : 'Excess payments stay unresolved until explicitly allocated.',
            ),
            value: _tips,
            onChanged: _saving
                ? null
                : (value) => setState(() {
                    _tips = value;
                    if (!value) _overpaymentPolicy = 'unresolved';
                  }),
          ),
          if (_overpaymentPolicy == 'legacy_tip') ...[
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Use explicit tip allocation'),
              subtitle: const Text(
                'Existing tips stay unchanged. Future excess payments will remain unresolved until allocated.',
              ),
              value: false,
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value) {
                        setState(() => _overpaymentPolicy = 'unresolved');
                      }
                    },
            ),
          ],
          const SizedBox(height: 12),
          Text(
            _review == 'automatic'
                ? 'After the bank confirms a payment, Chekmi records it and marks the sale complete.'
                : 'After the bank confirms a payment, it waits for an authorized reviewer.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (widget.profile.can('manage_receiving_accounts')) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const WorkspaceAccountsScreen(),
                ),
              ),
              icon: const Icon(Icons.account_balance_wallet_outlined),
              label: const Text('Receiving accounts'),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 18),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.tr('Save payment settings')),
          ),
        ],
      ),
    ),
  );
}
