import 'package:flutter/material.dart';
import 'package:verify_me/core/theme/app_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'api_service.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_spacing.dart';
import 'core/theme/app_typography.dart';
import 'core/widgets/app_shell.dart';
import 'core/widgets/state_views.dart';

enum _HelpSection { support, policies, account }

class SupportPrivacyScreen extends StatefulWidget {
  const SupportPrivacyScreen({
    super.key,
    this.allowAccountDeletion = false,
    this.loadCases,
  });

  final bool allowAccountDeletion;
  final Future<List<Map<String, dynamic>>> Function()? loadCases;

  @override
  State<SupportPrivacyScreen> createState() => _SupportPrivacyScreenState();
}

class _SupportPrivacyScreenState extends State<SupportPrivacyScreen> {
  static const _legalVersion = '2026-08-12';

  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _deletionReasonController = TextEditingController();
  _HelpSection _section = _HelpSection.support;
  String _category = 'technical';
  String _priority = 'normal';
  bool _sendingSupport = false;
  bool _sendingDeletion = false;
  bool _deletionConfirmed = false;
  final Set<String> _acceptedPolicies = {};
  late Future<List<Map<String, dynamic>>> _cases;

  @override
  void initState() {
    super.initState();
    _cases = _loadCases();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    _deletionReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Help & privacy'),
        titleTextStyle: AppTypography.appBarTitle(),
        actions: const [GlassLanguageToggleButton(), GlassThemeToggleButton()],
      ),
      body: AppBackdrop(
        maxWidth: 920,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xxxl,
              ),
              sliver: SliverList.list(
                children: [
                  _hero(),
                  const SizedBox(height: AppSpacing.lg),
                  _sectionPicker(),
                  const SizedBox(height: AppSpacing.lg),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween(
                          begin: const Offset(.035, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: switch (_section) {
                      _HelpSection.support => _supportSection(),
                      _HelpSection.policies => _policiesSection(),
                      _HelpSection.account => _accountSection(),
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero() => GlassPanel(
    accent: AppColors.aqua,
    child: Row(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.aqua, AppColors.primary],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(AppIcons.support, color: Colors.white, size: 28),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Support, policies, and account control',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Everything you send here is tied to your secure restaurant session and visible to the CHEKMI owner team.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    ),
  ).animate().fadeIn().slideY(begin: .06, end: 0);

  Widget _sectionPicker() => SegmentedButton<_HelpSection>(
    showSelectedIcon: false,
    segments: const [
      ButtonSegment(
        value: _HelpSection.support,
        icon: Icon(AppIcons.messages),
        label: Text('Support'),
      ),
      ButtonSegment(
        value: _HelpSection.policies,
        icon: Icon(AppIcons.policy),
        label: Text('Policies'),
      ),
      ButtonSegment(
        value: _HelpSection.account,
        icon: Icon(AppIcons.manageAccount),
        label: Text('Account'),
      ),
    ],
    selected: {_section},
    onSelectionChanged: (value) => setState(() => _section = value.first),
  ).animate().fadeIn(delay: 100.ms);

  Widget _supportSection() => Column(
    key: const ValueKey('support'),
    children: [
      GlassPanel(
        accent: AppColors.primary,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Open a support case',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 5),
            Text(
              'Payment and security issues should include the provider and reference, but never include a password or receipt image here.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            LayoutBuilder(
              builder: (context, constraints) {
                final category = DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(AppIcons.category),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'technical',
                      child: Text('Technical'),
                    ),
                    DropdownMenuItem(value: 'payment', child: Text('Payment')),
                    DropdownMenuItem(value: 'billing', child: Text('Billing')),
                    DropdownMenuItem(value: 'account', child: Text('Account')),
                    DropdownMenuItem(value: 'privacy', child: Text('Privacy')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) => setState(() => _category = value!),
                );
                final priority = DropdownButtonFormField<String>(
                  initialValue: _priority,
                  decoration: const InputDecoration(
                    labelText: 'Priority',
                    prefixIcon: Icon(AppIcons.flag),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                    DropdownMenuItem(value: 'normal', child: Text('Normal')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                    DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                  ],
                  onChanged: (value) => setState(() => _priority = value!),
                );
                if (constraints.maxWidth < 620) {
                  return Column(
                    children: [
                      category,
                      const SizedBox(height: AppSpacing.md),
                      priority,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: category),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: priority),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('supportSubjectField'),
              controller: _subjectController,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'Subject',
                prefixIcon: Icon(AppIcons.text),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('supportDescriptionField'),
              controller: _descriptionController,
              minLines: 4,
              maxLines: 7,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'What happened?',
                alignLabelWithHint: true,
                prefixIcon: Icon(AppIcons.notes),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              onPressed: _sendingSupport ? null : _submitSupport,
              icon: _sendingSupport
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(AppIcons.send),
              label: const Text('SEND TO CHEKMI SUPPORT'),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      _caseHistory(),
    ],
  );

  Widget _caseHistory() => GlassPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Your recent cases',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: 'Refresh cases',
              onPressed: _refreshCases,
              icon: const Icon(AppIcons.refresh),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _cases,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (snapshot.hasError) {
              return Column(
                children: [
                  const ErrorBanner(
                    message: 'Cases could not be loaded. Try again.',
                  ),
                  TextButton.icon(
                    onPressed: _refreshCases,
                    icon: const Icon(AppIcons.refresh),
                    label: const Text('RETRY'),
                  ),
                ],
              );
            }
            final cases = snapshot.data ?? const [];
            if (cases.isEmpty) {
              return const EmptyView(
                icon: AppIcons.resolvedMessage,
                message: 'No support cases yet. New requests and their status will appear here.',
              );
            }
            return Column(
              children: cases.take(5).map(_supportCaseCard).toList(),
            );
          },
        ),
      ],
    ),
  );

  Widget _supportCaseCard(Map<String, dynamic> item) {
    final status = item['status']?.toString() ?? 'open';
    final color = switch (status) {
      'resolved' || 'closed' => AppColors.success,
      'in_progress' => AppColors.warning,
      _ => AppColors.aqua,
    };
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: color.withValues(alpha: .2)),
      ),
      child: Row(
        children: [
          Icon(AppIcons.messages, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['subject']?.toString() ?? 'Support case',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  '${item['category'] ?? 'other'} · ${status.replaceAll('_', ' ')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }

  Widget _policiesSection() => Column(
    key: const ValueKey('policies'),
    children: [
      _PolicyCard(
        title: 'Privacy notice',
        type: 'privacy',
        version: _legalVersion,
        icon: AppIcons.privacy,
        accent: AppColors.aqua,
        accepted: _acceptedPolicies.contains('privacy'),
        points: const [
          'CHEKMI processes staff identity, restaurant configuration, payment references, verification evidence, and operational audit events.',
          'Access is tenant-scoped. Credentials and backend service keys are never included in support or crash logs.',
          'Receipt evidence is retained for 365 days by default; statutory financial records are retained for up to seven years.',
          'Access, correction, or deletion questions can be submitted through the support form on this screen.',
        ],
        onAccept: () => _acceptPolicy('privacy'),
      ),
      const SizedBox(height: AppSpacing.lg),
      _PolicyCard(
        title: 'Service terms',
        type: 'terms',
        version: _legalVersion,
        icon: AppIcons.legal,
        accent: AppColors.primary,
        accepted: _acceptedPolicies.contains('terms'),
        points: const [
          'CHEKMI assists with payment verification and restaurant workflow; the payment provider remains the source of settlement truth.',
          'Users must protect credentials, use assigned accounts, and report suspicious verification or access activity promptly.',
          'Plans control usage and features. Suspension may occur after expiry, abuse, or a material security risk.',
          'Financial disputes and refunds require documented review and remain subject to provider and applicable legal rules.',
        ],
        onAccept: () => _acceptPolicy('terms'),
      ),
      const SizedBox(height: AppSpacing.lg),
      GlassPanel(
        accent: AppColors.warning,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(AppIcons.info, color: AppColors.warning),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'These in-app summaries support informed consent. The public launch still requires counsel-reviewed full policy documents at the production Privacy and Terms URLs.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _accountSection() => Column(
    key: const ValueKey('account'),
    children: [
      GlassPanel(
        accent: AppColors.danger,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(AppIcons.delete, color: AppColors.danger),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Restaurant account deletion',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        widget.allowAccountDeletion
                            ? 'Requests enter a protected review and statutory-retention workflow.'
                            : 'Only a restaurant administrator can submit this request.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (widget.allowAccountDeletion) ...[
              const SizedBox(height: AppSpacing.lg),
              TextField(
                key: const Key('deletionReasonField'),
                controller: _deletionReasonController,
                minLines: 3,
                maxLines: 5,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Why are you closing the account?',
                  alignLabelWithHint: true,
                ),
              ),
              CheckboxListTile(
                value: _deletionConfirmed,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'I understand access may be suspended and legally required financial records may be retained.',
                ),
                onChanged: (value) =>
                    setState(() => _deletionConfirmed = value ?? false),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: !_deletionConfirmed || _sendingDeletion
                    ? null
                    : _requestDeletion,
                icon: _sendingDeletion
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(AppIcons.delete),
                label: const Text('REQUEST ACCOUNT DELETION'),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      GlassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Before you leave',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            const _AccountNote(
              icon: AppIcons.download,
              title: 'Preserve required reports',
              detail: 'Export business records needed for accounting before requesting closure.',
            ),
            const SizedBox(height: AppSpacing.md),
            const _AccountNote(
              icon: AppIcons.support,
              title: 'Let us help first',
              detail: 'Billing, access, and technical problems can usually be resolved through Support.',
            ),
          ],
        ),
      ),
    ],
  );

  void _refreshCases() {
    setState(() => _cases = _loadCases());
  }

  Future<List<Map<String, dynamic>>> _loadCases() =>
      widget.loadCases?.call() ?? ApiService.listMySupportCases();

  Future<void> _submitSupport() async {
    final subject = _subjectController.text.trim();
    final description = _descriptionController.text.trim();
    if (subject.length < 3 || description.length < 10) {
      _message(
        'Add a clear subject and at least 10 characters of detail.',
        true,
      );
      return;
    }
    setState(() => _sendingSupport = true);
    try {
      await ApiService.openSupportCase(
        category: _category,
        subject: subject,
        description: description,
        priority: _priority,
      );
      _subjectController.clear();
      _descriptionController.clear();
      _refreshCases();
      _message('Support case created. The owner team can now respond.', false);
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''), true);
    } finally {
      if (mounted) setState(() => _sendingSupport = false);
    }
  }

  Future<void> _acceptPolicy(String type) async {
    try {
      await ApiService.acceptLegalDocument(type: type, version: _legalVersion);
      if (!mounted) return;
      setState(() => _acceptedPolicies.add(type));
      _message(
        '${type == 'privacy' ? 'Privacy notice' : 'Service terms'} accepted.',
        false,
      );
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''), true);
    }
  }

  Future<void> _requestDeletion() async {
    final reason = _deletionReasonController.text.trim();
    if (reason.length < 10) {
      _message(
        'Please provide at least 10 characters explaining the request.',
        true,
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Submit deletion request?'),
        content: const Text(
          'This starts an owner review. It does not immediately erase financial records or bypass legal retention requirements.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('SUBMIT REQUEST'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _sendingDeletion = true);
    try {
      await ApiService.requestBusinessDeletion(reason);
      _deletionReasonController.clear();
      setState(() => _deletionConfirmed = false);
      _message('Deletion request submitted for protected owner review.', false);
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''), true);
    } finally {
      if (mounted) setState(() => _sendingDeletion = false);
    }
  }

  void _message(String message, bool error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.danger : AppColors.success,
      ),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  const _PolicyCard({
    required this.title,
    required this.type,
    required this.version,
    required this.icon,
    required this.accent,
    required this.points,
    required this.accepted,
    required this.onAccept,
  });

  final String title;
  final String type;
  final String version;
  final IconData icon;
  final Color accent;
  final List<String> points;
  final bool accepted;
  final Future<void> Function() onAccept;

  @override
  Widget build(BuildContext context) => GlassPanel(
    accent: accent,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, color: accent),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            Text('v$version', style: AppTypography.microLabel(color: accent)),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final point in points) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(point)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        const SizedBox(height: AppSpacing.sm),
        FilledButton.icon(
          onPressed: accepted ? null : onAccept,
          icon: Icon(accepted ? AppIcons.verified : AppIcons.check),
          label: Text(accepted ? 'ACCEPTED' : 'ACCEPT $type'.toUpperCase()),
        ),
      ],
    ),
  );
}

class _AccountNote extends StatelessWidget {
  const _AccountNote({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: AppColors.aqua),
      const SizedBox(width: AppSpacing.md),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            Text(detail, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ],
  );
}
