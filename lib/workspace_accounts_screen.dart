import 'package:flutter/material.dart';

import 'api_service.dart';
import 'core/config/app_variant.dart';

class WorkspaceAccountsScreen extends StatefulWidget {
  const WorkspaceAccountsScreen({super.key});
  @override
  State<WorkspaceAccountsScreen> createState() =>
      _WorkspaceAccountsScreenState();
}

class _WorkspaceAccountsScreenState extends State<WorkspaceAccountsScreen> {
  late final Future<Map<String, dynamic>> _business =
      ApiService.getCurrentBusiness();
  final _account = TextEditingController();
  final Map<String, dynamic> _accounts = {};
  String? _selected;
  bool _initialized = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _account.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = _account.text.trim();
    if (_selected == null || value.isEmpty) {
      setState(() => _error = 'Enter the receiving account number.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      _accounts['${_selected}_number'] = value;
      await ApiService.updateBankAccounts(_accounts);
      ApiService.refreshDashboardData();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Receiving account saved.')));
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
    appBar: AppBar(title: const Text('Receiving accounts')),
    body: SafeArea(
      child: FutureBuilder<Map<String, dynamic>>(
        future: _business,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) {
              return Center(
                child: Text('Could not load accounts: ${snapshot.error}'),
              );
            }
            return const Center(child: CircularProgressIndicator());
          }
          if (!_initialized) {
            _initialized = true;
            final raw = snapshot.data?['bank_accounts'];
            if (raw is Map) _accounts.addAll(Map<String, dynamic>.from(raw));
            _selected = AppVariant.enabledPaymentProviders.first.id;
            _account.text = _accounts['${_selected}_number']?.toString() ?? '';
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Text(
                'Where payments should arrive',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'The verifier compares each receipt with the account you configure here.',
              ),
              const SizedBox(height: 26),
              DropdownButtonFormField<String>(
                initialValue: _selected,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Payment provider',
                ),
                items: AppVariant.enabledPaymentProviders
                    .map(
                      (provider) => DropdownMenuItem(
                        value: provider.id,
                        child: Text(provider.label),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) => setState(() {
                        _selected = value;
                        _account.text =
                            _accounts['${value}_number']?.toString() ?? '';
                      }),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _account,
                enabled: !_saving,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Receiving account number',
                ),
                onChanged: (value) {
                  if (_selected != null) {
                    _accounts['${_selected}_number'] = value.trim();
                  }
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 26),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save receiving account'),
              ),
            ],
          );
        },
      ),
    ),
  );
}
