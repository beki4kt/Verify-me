import 'package:flutter/material.dart';

import 'api_service.dart';
import 'core/config/payment_context.dart';

class WorkspaceMembersScreen extends StatefulWidget {
  const WorkspaceMembersScreen({super.key});
  @override
  State<WorkspaceMembersScreen> createState() => _WorkspaceMembersScreenState();
}

class _WorkspaceMembersScreenState extends State<WorkspaceMembersScreen> {
  late Future<List<Map<String, dynamic>>> _members =
      ApiService.listWorkspaceMembers();
  String? _saving;
  String? _error;
  static const _permissions = <String, String>{
    'verify_payment': 'Verify payments',
    'review_payment': 'Review and complete payments',
    'view_ledger': 'View workspace ledger',
    'manage_receiving_accounts': 'Manage receiving accounts',
    'manage_members': 'Manage members',
    'manage_workspace': 'Change payment settings',
    'manage_tips': 'Allocate tips',
  };

  Future<void> _addMember() async {
    final number = TextEditingController();
    final name = TextEditingController();
    final phone = TextEditingController();
    final password = TextEditingController();
    var preset = 'waiter';
    var saving = false;
    String? errorText;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Add a member'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: number,
                  decoration: const InputDecoration(labelText: 'Member code'),
                ),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone (+251…)'),
                ),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Temporary password',
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: preset,
                  decoration: const InputDecoration(
                    labelText: 'Starting permissions',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'waiter',
                      child: Text('Payment staff'),
                    ),
                    DropdownMenuItem(
                      value: 'cashier',
                      child: Text('Reviewer / cashier'),
                    ),
                  ],
                  onChanged: saving
                      ? null
                      : (value) =>
                            setDialogState(() => preset = value ?? preset),
                ),
                if (errorText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      errorText!,
                      style: TextStyle(
                        color: Theme.of(dialogContext).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (name.text.trim().isEmpty ||
                          number.text.trim().isEmpty ||
                          !RegExp(r'^\+251[79]\d{8}$')
                              .hasMatch(phone.text.trim()) ||
                          password.text.length < 8) {
                        setDialogState(
                          () => errorText = 'Enter a name, member code, valid +251 phone, and 8-character password.',
                        );
                        return;
                      }
                      setDialogState(() {
                        saving = true;
                        errorText = null;
                      });
                      try {
                        await ApiService.createStaffMember(
                          pin: number.text.trim(),
                          name: name.text.trim(),
                          phone: phone.text.trim(),
                          password: password.text,
                          role: preset,
                        );
                        if (!dialogContext.mounted || !mounted) return;
                        Navigator.pop(dialogContext);
                        setState(
                          () => _members = ApiService.listWorkspaceMembers(),
                        );
                      } catch (error) {
                        if (dialogContext.mounted) {
                          setDialogState(() {
                            saving = false;
                            errorText = error.toString().replaceFirst(
                              'Exception: ',
                              '',
                            );
                          });
                        }
                      }
                    },
              child: saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add member'),
            ),
          ],
        ),
      ),
    );
    number.dispose();
    name.dispose();
    phone.dispose();
    password.dispose();
  }

  Future<void> _set(String number, String capability, bool allowed) async {
    setState(() {
      _saving = '$number:$capability';
      _error = null;
    });
    try {
      await ApiService.setMemberCapability(
        staffNumber: number,
        capability: capability,
        allowed: allowed,
      );
      if (mounted) {
        setState(() => _members = ApiService.listWorkspaceMembers());
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  Future<void> _resetPassword(Map<String, dynamic> member) async {
    final controller = TextEditingController();
    final changed = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset member password'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'New password',
            helperText: 'At least 8 characters',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Reset password'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (changed == null || !mounted) return;
    if (changed.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }
    try {
      await ApiService.updateStaffProfile(
        member['staff_number'].toString(),
        member['name'].toString(),
        member['phone_number'].toString(),
        changed,
        member['role'].toString(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset. Existing sessions were signed out.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Members'),
      actions: [
        IconButton(
          onPressed: _addMember,
          tooltip: 'Add member',
          icon: const Icon(Icons.person_add_alt_1_outlined),
        ),
      ],
    ),
    body: SafeArea(
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _members,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) {
              return Center(
                child: Text('Could not load members: ${snapshot.error}'),
              );
            }
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Text(
                'Who can do what',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Changes take effect on the server. A member’s role is a starting preset.',
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              for (final member in snapshot.data!) ...[
                Card(
                  child: ExpansionTile(
                    title: Text(
                      member['name']?.toString() ??
                          member['staff_number'].toString(),
                    ),
                    subtitle: Text(
                      '${PaymentContext.roleLabel(member['role'])} · ${member['staff_number']}',
                    ),
                    children: [
                      if (member['role'] != 'admin' &&
                          member['is_active'] == true &&
                          member['staff_number'] !=
                              ApiService.currentStaffNumber)
                        ListTile(
                          leading: const Icon(Icons.key_outlined),
                          title: const Text('Reset password'),
                          onTap: () => _resetPassword(member),
                        ),
                      for (final permission in _permissions.entries)
                        SwitchListTile.adaptive(
                          title: Text(permission.value),
                          value:
                              (member['capabilities']
                                  as Map?)?[permission.key] ==
                              true,
                          onChanged:
                              member['role'] == 'admin' ||
                                  member['is_active'] != true ||
                                  member['staff_number'] ==
                                      ApiService.currentStaffNumber ||
                                  _saving != null
                              ? null
                              : (value) => _set(
                                  member['staff_number'].toString(),
                                  permission.key,
                                  value,
                                ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    ),
  );
}
