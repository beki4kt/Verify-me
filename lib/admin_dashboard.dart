import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'api_service.dart';
import 'staff_login_screen.dart'; // FIXED: Swapped to the active login screen
import 'core/theme/app_colors.dart';
import 'core/theme/app_typography.dart';
import 'core/widgets/app_shell.dart';
import 'core/widgets/metric_card.dart';
import 'core/widgets/state_views.dart';
import 'localization_service.dart';

class _PaymentAccountProvider {
  const _PaymentAccountProvider({
    required this.name,
    required this.description,
    required this.numberLabel,
    required this.numberKey,
    required this.nameKey,
    required this.icon,
    required this.color,
  });

  final String name;
  final String description;
  final String numberLabel;
  final String numberKey;
  final String nameKey;
  final IconData icon;
  final Color color;
}

const _paymentAccountProviders = <_PaymentAccountProvider>[
  _PaymentAccountProvider(
    name: 'Telebirr',
    description: 'Mobile or merchant account that receives Telebirr payments.',
    numberLabel: 'Mobile / merchant number',
    numberKey: 'telebirr_number',
    nameKey: 'telebirr_name',
    icon: Icons.phone_android_rounded,
    color: Color(0xFF0EA5E9),
  ),
  _PaymentAccountProvider(
    name: 'Commercial Bank of Ethiopia',
    description: 'Official CBE account used for restaurant transfers.',
    numberLabel: 'CBE account number',
    numberKey: 'cbe_number',
    nameKey: 'cbe_name',
    icon: Icons.account_balance_rounded,
    color: Color(0xFFA855F7),
  ),
  _PaymentAccountProvider(
    name: 'CBE Birr',
    description: 'Wallet or phone number registered to the restaurant.',
    numberLabel: 'CBE Birr wallet number',
    numberKey: 'cbebirr_number',
    nameKey: 'cbebirr_name',
    icon: Icons.account_balance_wallet_rounded,
    color: Color(0xFF7C3AED),
  ),
  _PaymentAccountProvider(
    name: 'Dashen Bank',
    description: 'Official Dashen account used for incoming payments.',
    numberLabel: 'Dashen account number',
    numberKey: 'dashen_number',
    nameKey: 'dashen_name',
    icon: Icons.account_balance_outlined,
    color: Color(0xFFF59E0B),
  ),
  _PaymentAccountProvider(
    name: 'Bank of Abyssinia',
    description: 'Official Abyssinia account used for incoming payments.',
    numberLabel: 'Abyssinia account number',
    numberKey: 'abyssinia_number',
    nameKey: 'abyssinia_name',
    icon: Icons.account_balance_rounded,
    color: Color(0xFFEF4444),
  ),
  _PaymentAccountProvider(
    name: 'M-Pesa',
    description: 'Restaurant mobile wallet, paybill, or till number.',
    numberLabel: 'M-Pesa number / till',
    numberKey: 'mpesa_number',
    nameKey: 'mpesa_name',
    icon: Icons.wallet_rounded,
    color: Color(0xFF22C55E),
  ),
];

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  late Stream<List<Map<String, dynamic>>> _ticketsStream;
  late Stream<List<Map<String, dynamic>>> _staffStream;
  late Stream<Map<String, dynamic>> _businessStream;

  @override
  void initState() {
    super.initState();
    _setDataStreams();
  }

  void _setDataStreams() {
    _ticketsStream = ApiService.streamTodayTickets();
    _staffStream = ApiService.streamStaffRoster();
    _businessStream = ApiService.streamCurrentBusiness();
  }

  void _refreshData() {
    setState(_setDataStreams);
  }

  List<DropdownMenuItem<String>> _getAvailableRoles() {
    List<DropdownMenuItem<String>> roles = [
      const DropdownMenuItem(value: 'waiter', child: Text('Waiter')),
    ];
    if (ApiService.currentBusinessHasCashier == true) {
      roles.insert(
        0,
        const DropdownMenuItem(value: 'cashier', child: Text('Cashier')),
      );
    }
    return roles;
  }

  Color _getBankColor(String bank) {
    if (bank.toLowerCase().contains('telebirr')) return const Color(0xFF0EA5E9);
    if (bank.toLowerCase().contains('cbe')) return const Color(0xFFA855F7);
    if (bank.toLowerCase().contains('dashen')) return const Color(0xFFF59E0B);
    return const Color(0xFF64748B);
  }

  Future<void> _showBankConfigSheet(
    Map<String, dynamic> currentAccounts,
  ) async {
    final numberControllers = {
      for (final provider in _paymentAccountProviders)
        provider.numberKey: TextEditingController(
          text: currentAccounts[provider.numberKey]?.toString() ?? '',
        ),
    };
    final nameControllers = {
      for (final provider in _paymentAccountProviders)
        provider.nameKey: TextEditingController(
          text: currentAccounts[provider.nameKey]?.toString() ?? '',
        ),
    };
    bool isSubmitting = false;
    String? errorText;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final theme = Theme.of(sheetContext);
            final configuredCount = _paymentAccountProviders.where((provider) {
              return numberControllers[provider.numberKey]!.text
                  .trim()
                  .isNotEmpty;
            }).length;

            return FractionallySizedBox(
              heightFactor: .94,
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: .2),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        24,
                        20,
                        24,
                        MediaQuery.of(sheetContext).viewInsets.bottom + 24,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withValues(
                                        alpha: .12,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(
                                      Icons.account_balance_rounded,
                                      color: AppColors.success,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Payment accounts',
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w900,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Add the official receiving account for every provider your restaurant accepts.',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                                height: 1.4,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withValues(
                                        alpha: .1,
                                      ),
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                    child: Text(
                                      '$configuredCount / ${_paymentAccountProviders.length}',
                                      style: const TextStyle(
                                        color: AppColors.success,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: .08,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: AppColors.primary.withValues(
                                      alpha: .18,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.verified_user_outlined,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Receipt destinations are checked against these values. Leave a provider blank only when the restaurant does not accept it.',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(height: 1.45),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              ..._paymentAccountProviders.map((provider) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: provider.color.withValues(
                                        alpha: .045,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: provider.color.withValues(
                                          alpha: .2,
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 38,
                                              height: 38,
                                              decoration: BoxDecoration(
                                                color: provider.color
                                                    .withValues(alpha: .12),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Icon(
                                                provider.icon,
                                                color: provider.color,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    provider.name,
                                                    style: theme
                                                        .textTheme
                                                        .titleSmall
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w900,
                                                        ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    provider.description,
                                                    style: theme
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color: theme
                                                              .colorScheme
                                                              .onSurfaceVariant,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 14),
                                        LayoutBuilder(
                                          builder: (context, constraints) {
                                            final numberField = TextField(
                                              controller:
                                                  numberControllers[provider
                                                      .numberKey],
                                              keyboardType: TextInputType.text,
                                              textInputAction:
                                                  TextInputAction.next,
                                              inputFormatters: [
                                                FilteringTextInputFormatter.allow(
                                                  RegExp(r'[0-9A-Za-z+\- ]'),
                                                ),
                                                LengthLimitingTextInputFormatter(
                                                  32,
                                                ),
                                              ],
                                              onChanged: (_) =>
                                                  setSheetState(() {}),
                                              decoration: _buildInputDecoration(
                                                provider.numberLabel,
                                                Icons.numbers_rounded,
                                              ),
                                            );
                                            final nameField = TextField(
                                              controller:
                                                  nameControllers[provider
                                                      .nameKey],
                                              textCapitalization:
                                                  TextCapitalization.words,
                                              textInputAction:
                                                  TextInputAction.next,
                                              maxLength: 80,
                                              decoration: _buildInputDecoration(
                                                'Account holder / merchant name',
                                                Icons.storefront_outlined,
                                              ).copyWith(counterText: ''),
                                            );
                                            if (constraints.maxWidth < 560) {
                                              return Column(
                                                children: [
                                                  numberField,
                                                  const SizedBox(height: 12),
                                                  nameField,
                                                ],
                                              );
                                            }
                                            return Row(
                                              children: [
                                                Expanded(child: numberField),
                                                const SizedBox(width: 12),
                                                Expanded(child: nameField),
                                              ],
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                              if (errorText != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: AppColors.danger.withValues(
                                      alpha: .1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.danger),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.error_outline_rounded,
                                        color: AppColors.danger,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          errorText!,
                                          style: const TextStyle(
                                            color: AppColors.danger,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              FilledButton.icon(
                                onPressed: isSubmitting
                                    ? null
                                    : () async {
                                        for (final provider
                                            in _paymentAccountProviders) {
                                          final number =
                                              numberControllers[provider
                                                      .numberKey]!
                                                  .text
                                                  .trim();
                                          final holder =
                                              nameControllers[provider.nameKey]!
                                                  .text
                                                  .trim();
                                          if (number.isEmpty &&
                                              holder.isNotEmpty) {
                                            setSheetState(() {
                                              errorText =
                                                  'Enter the ${provider.name} account number or clear its account-holder name.';
                                            });
                                            return;
                                          }
                                          if (number.isNotEmpty &&
                                              number.length < 5) {
                                            setSheetState(() {
                                              errorText =
                                                  '${provider.name} account number looks too short.';
                                            });
                                            return;
                                          }
                                        }

                                        setSheetState(() {
                                          isSubmitting = true;
                                          errorText = null;
                                        });
                                        try {
                                          final updatedAccounts =
                                              Map<String, dynamic>.from(
                                                currentAccounts,
                                              );
                                          for (final provider
                                              in _paymentAccountProviders) {
                                            final number =
                                                numberControllers[provider
                                                        .numberKey]!
                                                    .text
                                                    .trim();
                                            final holder =
                                                nameControllers[provider
                                                        .nameKey]!
                                                    .text
                                                    .trim();
                                            if (number.isEmpty) {
                                              updatedAccounts.remove(
                                                provider.numberKey,
                                              );
                                              updatedAccounts.remove(
                                                provider.nameKey,
                                              );
                                            } else {
                                              updatedAccounts[provider
                                                      .numberKey] =
                                                  number;
                                              if (holder.isEmpty) {
                                                updatedAccounts.remove(
                                                  provider.nameKey,
                                                );
                                              } else {
                                                updatedAccounts[provider
                                                        .nameKey] =
                                                    holder;
                                              }
                                            }
                                          }
                                          await ApiService.updateBankAccounts(
                                            updatedAccounts,
                                          );
                                          if (!sheetContext.mounted) return;
                                          Navigator.of(sheetContext).pop();
                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Payment accounts updated successfully.',
                                                ),
                                              ),
                                            );
                                          }
                                        } catch (error) {
                                          if (!sheetContext.mounted) return;
                                          setSheetState(() {
                                            isSubmitting = false;
                                            errorText = error
                                                .toString()
                                                .replaceFirst(
                                                  'Exception: ',
                                                  '',
                                                );
                                          });
                                        }
                                      },
                                icon: isSubmitting
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.save_outlined),
                                label: Text(
                                  isSubmitting
                                      ? 'Saving accounts…'
                                      : 'Save payment accounts',
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 18,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    for (final controller in numberControllers.values) {
      controller.dispose();
    }
    for (final controller in nameControllers.values) {
      controller.dispose();
    }
  }

  Future<void> _showChangePasswordSheet() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isSubmitting = false;
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirmation = true;
    String? errorText;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final theme = Theme.of(sheetContext);

            Widget passwordField({
              required TextEditingController controller,
              required String label,
              required String hint,
              required bool obscure,
              required VoidCallback toggleVisibility,
              TextInputAction textInputAction = TextInputAction.next,
            }) {
              return TextField(
                controller: controller,
                obscureText: obscure,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: textInputAction,
                decoration:
                    _buildInputDecoration(
                      label,
                      Icons.lock_outline_rounded,
                    ).copyWith(
                      hintText: hint,
                      suffixIcon: IconButton(
                        tooltip: obscure ? 'Show password' : 'Hide password',
                        onPressed: toggleVisibility,
                        icon: Icon(
                          obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
              );
            }

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                24,
                16,
                24,
                MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: .2,
                            ),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      Container(
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.password_rounded,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Change admin password',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Confirm your identity with the current admin password, then choose a new password for this account.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 24),
                      passwordField(
                        controller: currentPasswordController,
                        label: 'Current admin password',
                        hint: 'Required to confirm this change',
                        obscure: obscureCurrent,
                        toggleVisibility: () => setSheetState(
                          () => obscureCurrent = !obscureCurrent,
                        ),
                      ),
                      const SizedBox(height: 14),
                      passwordField(
                        controller: newPasswordController,
                        label: 'New password',
                        hint: 'At least 8 characters',
                        obscure: obscureNew,
                        toggleVisibility: () =>
                            setSheetState(() => obscureNew = !obscureNew),
                      ),
                      const SizedBox(height: 14),
                      passwordField(
                        controller: confirmPasswordController,
                        label: 'Confirm new password',
                        hint: 'Enter the new password again',
                        obscure: obscureConfirmation,
                        textInputAction: TextInputAction.done,
                        toggleVisibility: () => setSheetState(
                          () => obscureConfirmation = !obscureConfirmation,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: .45),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.shield_outlined, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Use 8 or more characters. Other signed-in devices will be logged out after the change.',
                                style: TextStyle(fontSize: 12, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (errorText != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.danger),
                          ),
                          child: Text(
                            errorText!,
                            style: const TextStyle(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final currentPassword =
                                    currentPasswordController.text;
                                final newPassword = newPasswordController.text;
                                final confirmation =
                                    confirmPasswordController.text;
                                if (currentPassword.isEmpty) {
                                  setSheetState(() {
                                    errorText =
                                        'Enter your current admin password.';
                                  });
                                  return;
                                }
                                if (newPassword.length < 8) {
                                  setSheetState(() {
                                    errorText =
                                        'The new password must be at least 8 characters.';
                                  });
                                  return;
                                }
                                if (newPassword != confirmation) {
                                  setSheetState(() {
                                    errorText =
                                        'The new passwords do not match.';
                                  });
                                  return;
                                }
                                if (newPassword == currentPassword) {
                                  setSheetState(() {
                                    errorText =
                                        'Choose a new password different from the current password.';
                                  });
                                  return;
                                }

                                setSheetState(() {
                                  isSubmitting = true;
                                  errorText = null;
                                });
                                try {
                                  await ApiService.changeCurrentAdminPassword(
                                    currentPassword: currentPassword,
                                    newPassword: newPassword,
                                  );
                                  if (!sheetContext.mounted) return;
                                  Navigator.of(sheetContext).pop();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Admin password changed successfully.',
                                        ),
                                      ),
                                    );
                                  }
                                } catch (error) {
                                  if (!sheetContext.mounted) return;
                                  setSheetState(() {
                                    isSubmitting = false;
                                    final message = error
                                        .toString()
                                        .replaceFirst('Exception: ', '');
                                    errorText = message.contains('P0001')
                                        ? 'The current admin password is incorrect.'
                                        : message;
                                  });
                                }
                              },
                        icon: isSubmitting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.lock_reset_rounded),
                        label: Text(
                          isSubmitting
                              ? 'Updating password…'
                              : 'Update password',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
  }

  void _showAddStaffSheet() {
    final pinController = TextEditingController();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedRole = 'waiter';
    bool isSubmitting = false;
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(
        context,
      ).colorScheme.surface.withValues(alpha: .94),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 24,
                right: 24,
                top: 32,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'PROVISION NEW STAFF',
                      style: TextStyle(
                        color: Color(0xFF6366F1),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: nameController,
                      style: Theme.of(context).textTheme.bodyLarge,
                      decoration: _buildInputDecoration(
                        'FULL NAME',
                        Icons.person_outline,
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(8),
                      ],
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                      decoration: _buildInputDecoration(
                        'PHONE NUMBER',
                        Icons.phone,
                        isPhone: true,
                      ),
                    ),

                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: passwordController,
                            style: Theme.of(context).textTheme.bodyLarge,
                            decoration: _buildInputDecoration(
                              'PASSWORD',
                              Icons.lock,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: pinController,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                            decoration: _buildInputDecoration(
                              'ID',
                              Icons.badge,
                            ).copyWith(counterText: ""),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      dropdownColor: Theme.of(context).colorScheme.surface,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: _buildInputDecoration(
                        'SYSTEM ROLE',
                        Icons.work,
                      ),
                      items: _getAvailableRoles(),
                      onChanged: (val) =>
                          setSheetState(() => selectedRole = val!),
                    ),
                    const SizedBox(height: 24),

                    if (errorText != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.redAccent),
                        ),
                        child: Text(
                          errorText!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                    ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              if (nameController.text.isEmpty ||
                                  phoneController.text.length != 8 ||
                                  passwordController.text.isEmpty) {
                                setSheetState(
                                  () => errorText =
                                      'Please fill out all fields and ensure phone is 8 digits.',
                                );
                                return;
                              }
                              if (pinController.text.length < 4) {
                                setSheetState(
                                  () => errorText =
                                      'Staff ID must be exactly 4 digits.',
                                );
                                return;
                              }

                              setSheetState(() {
                                isSubmitting = true;
                                errorText = null;
                              });
                              try {
                                await ApiService.createStaffMember(
                                  pin: pinController.text.trim(),
                                  name: nameController.text.trim(),
                                  phone: '+2519${phoneController.text.trim()}',
                                  password: passwordController.text.trim(),
                                  role: selectedRole,
                                );
                                if (context.mounted) Navigator.pop(context);
                              } catch (e) {
                                setSheetState(
                                  () => errorText = e.toString().replaceAll(
                                    'Exception: ',
                                    '',
                                  ),
                                );
                              } finally {
                                setSheetState(() => isSubmitting = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'SAVE USER',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditStaffSheet(Map<String, dynamic> staffMember) {
    final dbPhone = staffMember['phone_number']?.toString() ?? '';
    final displayPhone = dbPhone.startsWith('+2519')
        ? dbPhone.replaceFirst('+2519', '')
        : dbPhone;

    final nameController = TextEditingController(
      text: staffMember['name']?.toString() ?? '',
    );
    final phoneController = TextEditingController(text: displayPhone);
    final passwordController = TextEditingController(
      text: staffMember['password']?.toString() ?? '',
    );

    String selectedRole = staffMember['role'];
    if (selectedRole == 'cashier' &&
        ApiService.currentBusinessHasCashier != true) {
      selectedRole = 'waiter';
    }
    bool isSubmitting = false;
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(
        context,
      ).colorScheme.surface.withValues(alpha: .94),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 24,
                right: 24,
                top: 32,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'MANAGE STAFF: ${staffMember['staff_number']}',
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: nameController,
                      style: Theme.of(context).textTheme.bodyLarge,
                      decoration: _buildInputDecoration(
                        'FULL NAME',
                        Icons.person_outline,
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(8),
                      ],
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                      decoration: _buildInputDecoration(
                        'PHONE NUMBER',
                        Icons.phone,
                        isPhone: true,
                      ),
                    ),

                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      style: Theme.of(context).textTheme.bodyLarge,
                      decoration: _buildInputDecoration('PASSWORD', Icons.lock),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      dropdownColor: Theme.of(context).colorScheme.surface,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: _buildInputDecoration(
                        'SYSTEM ROLE',
                        Icons.work,
                      ),
                      items: _getAvailableRoles(),
                      onChanged: (val) =>
                          setSheetState(() => selectedRole = val!),
                    ),
                    const SizedBox(height: 24),

                    if (errorText != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.redAccent),
                        ),
                        child: Text(
                          errorText!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                    ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              if (nameController.text.isEmpty ||
                                  phoneController.text.length != 8 ||
                                  passwordController.text.isEmpty) {
                                setSheetState(
                                  () => errorText =
                                      'All fields are required and phone must be 8 digits.',
                                );
                                return;
                              }
                              setSheetState(() {
                                isSubmitting = true;
                                errorText = null;
                              });
                              try {
                                await ApiService.updateStaffProfile(
                                  staffMember['staff_number'].toString(),
                                  nameController.text.trim(),
                                  '+2519${phoneController.text.trim()}',
                                  passwordController.text.trim(),
                                  selectedRole,
                                );
                                if (context.mounted) Navigator.pop(context);
                              } catch (e) {
                                setSheetState(
                                  () => errorText = e.toString().replaceAll(
                                    'Exception: ',
                                    '',
                                  ),
                                );
                              } finally {
                                setSheetState(() => isSubmitting = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'UPDATE STAFF',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _buildInputDecoration(
    String label,
    IconData icon, {
    bool isPhone = false,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: isPhone
          ? Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Text(
                    '+2519',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 2,
                    height: 24,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            )
          : Icon(icon),
    );
  }

  // PHASE 3: THE STAFF ROSTER TAB WIDGET
  Widget _buildStaffRosterTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _staffStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorBanner(message: _friendlyStreamError(snapshot.error));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF6366F1)),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              'No staff members found.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }

        // Filter out Admins to ensure only single admin view applies
        final staffList = snapshot.data!
            .where((s) => s['role'] != 'admin')
            .toList();

        if (staffList.isEmpty) {
          return Center(
            child: Text(
              'No active floor staff.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: staffList.length,
          itemBuilder: (context, index) {
            final staff = staffList[index];
            final isActive = staff['is_active'] as bool? ?? true;
            final roleName =
                staff['role']?.toString().toUpperCase() ?? 'UNKNOWN';
            final roleColor = roleName == 'CASHIER'
                ? const Color(0xFFF59E0B)
                : const Color(0xFF10B981);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surface.withValues(alpha: .68),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: roleColor.withValues(alpha: 0.1),
                    child: Icon(
                      roleName == 'CASHIER'
                          ? Icons.point_of_sale
                          : Icons.restaurant_menu,
                      color: roleColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          staff['name'] ?? 'Unknown',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: ${staff['staff_number']}  •  $roleName',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.edit,
                      color: Color(0xFF64748B),
                      size: 20,
                    ),
                    onPressed: () => _showEditStaffSheet(staff),
                  ),
                  Switch.adaptive(
                    value: isActive,
                    activeTrackColor: const Color(0xFF10B981),
                    onChanged: (val) async {
                      await ApiService.toggleStaffStatus(
                        staff['staff_number'],
                        val,
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr('Restaurant overview')),
          titleTextStyle: AppTypography.appBarTitle(),
          leading: IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
            onPressed: () {
              ApiService.logoutStaff();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const StaffLoginScreen()),
              );
            },
          ),
          actions: [
            const LanguageToggleButton(),
            const ThemeToggleButton(),
            IconButton(
              tooltip: 'Change admin password',
              icon: const Icon(Icons.password_rounded),
              onPressed: _showChangePasswordSheet,
            ),
            IconButton(
              tooltip: 'Refresh data',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _refreshData,
            ),
            StreamBuilder<Map<String, dynamic>>(
              stream: _businessStream,
              builder: (context, snapshot) {
                final rawAccounts = snapshot.data?['bank_accounts'];
                final accounts = rawAccounts is Map
                    ? Map<String, dynamic>.from(rawAccounts)
                    : <String, dynamic>{};
                final configuredCount = _paymentAccountProviders.where((
                  provider,
                ) {
                  return accounts[provider.numberKey]
                          ?.toString()
                          .trim()
                          .isNotEmpty ==
                      true;
                }).length;
                return IconButton(
                  tooltip:
                      'Payment accounts ($configuredCount/${_paymentAccountProviders.length})',
                  icon: Icon(
                    Icons.account_balance_outlined,
                    color: configuredCount == 0
                        ? AppColors.danger
                        : configuredCount == _paymentAccountProviders.length
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                  onPressed: () => _showBankConfigSheet(accounts),
                );
              },
            ),
            IconButton(
              tooltip: 'Add staff member',
              icon: const Icon(Icons.person_add_alt_1_rounded),
              onPressed: _showAddStaffSheet,
            ),
          ],
          bottom: TabBar(
            dividerHeight: 0,
            tabs: [
              Tab(
                icon: const Icon(Icons.insights_outlined, size: 18),
                text: context.tr('Overview'),
              ),
              Tab(
                icon: const Icon(Icons.groups_outlined, size: 18),
                text: context.tr('Team'),
              ),
            ],
          ),
        ),
        body: AppBackdrop(
          child: TabBarView(
            children: [
              // TAB 1: FINANCIALS AND LEDGER
              CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _ticketsStream,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: ErrorBanner(
                              message: _friendlyStreamError(snapshot.error),
                            ),
                          );
                        }
                        double totalRevenue = 0;
                        int pendingCount = 0;
                        Map<String, double> bankTotals = {};

                        if (snapshot.hasData) {
                          for (var ticket in snapshot.data!) {
                            if (ticket['status'] == 'settled') {
                              double amount = (ticket['bill_amount'] ?? 0)
                                  .toDouble();
                              totalRevenue += amount;
                              String bankName = ticket['bank'] ?? 'Unknown';
                              bankTotals[bankName] =
                                  (bankTotals[bankName] ?? 0) + amount;
                            } else if (ticket['status'] == 'pending') {
                              pendingCount++;
                            }
                          }
                        }

                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildMetricCard(
                                      context.tr('TOTAL REVENUE'),
                                      '${totalRevenue.toStringAsFixed(0)} ETB',
                                      const Color(0xFF10B981),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildMetricCard(
                                      context.tr('ACTIVE BILLS'),
                                      '$pendingCount',
                                      const Color(0xFFF59E0B),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Text(
                                context.tr('BANK DEPOSIT BREAKDOWN'),
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (bankTotals.isEmpty)
                                GlassPanel(
                                  padding: const EdgeInsets.all(24),
                                  child: Center(
                                    child: Text(
                                      context.tr(
                                        'No verified transactions yet.',
                                      ),
                                      style: const TextStyle(
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                )
                              else
                                GlassPanel(
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        children: bankTotals.entries.map((
                                          entry,
                                        ) {
                                          Color bColor = _getBankColor(
                                            entry.key,
                                          );
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 16.0,
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 12,
                                                  height: 12,
                                                  decoration: BoxDecoration(
                                                    color: bColor,
                                                    shape: BoxShape.circle,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: bColor
                                                            .withValues(
                                                              alpha: 0.5,
                                                            ),
                                                        blurRadius: 6,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                Text(
                                                  entry.key,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 14,
                                                      ),
                                                ),
                                                const Spacer(),
                                                Text(
                                                  '${entry.value.toStringAsFixed(0)} ETB',
                                                  style: TextStyle(
                                                    color: bColor,
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    )
                                    .animate()
                                    .fadeIn(delay: 300.ms)
                                    .slideY(begin: 0.1, end: 0),
                            ],
                          ),
                        ).animate().fadeIn(duration: 400.ms);
                      },
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Text(
                        context.tr('MASTER TRANSACTION LEDGER'),
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),

                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _ticketsStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: ErrorBanner(
                              message: _friendlyStreamError(snapshot.error),
                            ),
                          ),
                        );
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: CircularProgressIndicator(
                                color: Color(0xFF6366F1),
                              ),
                            ),
                          ),
                        );
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Text(
                                context.tr('Ledger is clear.'),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ),
                        );
                      }

                      return SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final ticket = snapshot.data![index];
                          final isSettled = ticket['status'] == 'settled';
                          final isRejected = ticket['status'] == 'rejected';
                          final bankColor = _getBankColor(ticket['bank'] ?? '');
                          final statusColor = isSettled
                              ? const Color(0xFF10B981)
                              : (isRejected
                                    ? Colors.redAccent
                                    : const Color(0xFFF59E0B));

                          return GlassPanel(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            padding: const EdgeInsets.all(16),
                            borderRadius: 16,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.receipt_long,
                                          color: statusColor,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${ticket['bill_amount']} ETB',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Text(
                                          ticket['bank'] ?? 'N/A',
                                          style: TextStyle(
                                            color: bankColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'REF: ${ticket['transaction_ref'] ?? ticket['ticket_id'].toString().substring(0, 8)}',
                                          style: const TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Waiter ID: ${ticket['waiter_id']} | Status: ${ticket['status'].toString().toUpperCase()}',
                                      style: const TextStyle(
                                        color: Color(0xFF475569),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }, childCount: snapshot.data!.length),
                      );
                    },
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),

              // TAB 2: STAFF ROSTER
              _buildStaffRosterTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String val, Color accents) {
    return MetricCard(title: title, value: val, accent: accents);
  }

  String _friendlyStreamError(Object? error) {
    final message =
        error?.toString().replaceFirst('Exception: ', '') ??
        'Unable to load dashboard data.';
    return 'Dashboard data could not be loaded. $message';
  }
}
