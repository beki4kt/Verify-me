import 'package:flutter/material.dart';
import 'package:verify_me/core/theme/app_icons.dart';
import 'package:verify_me/core/config/app_variant.dart';

import 'business_gateway_screen.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_spacing.dart';
import 'core/widgets/app_shell.dart';
import 'operator_service.dart';

enum _ConsoleSection {
  overview('Command center', AppIcons.dashboard),
  restaurants('Restaurants', AppIcons.storefront),
  billing('Plans & billing', AppIcons.card),
  support('Support & privacy', AppIcons.support),
  security('Security', AppIcons.shield),
  system('System health', AppIcons.systemHealth);

  const _ConsoleSection(this.label, this.icon);
  final String label;
  final IconData icon;
}

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  _ConsoleSection _section = _ConsoleSection.overview;
  Map<String, dynamic> _snapshot = const {};
  Map<String, dynamic> _system = const {};
  bool _loading = true;
  bool _acting = false;
  String? _error;
  String _restaurantQuery = '';
  String _restaurantFilter = 'all';

  List<Map<String, dynamic>> get _businesses => _maps('businesses');
  List<Map<String, dynamic>> get _support => _maps('support_cases');
  List<Map<String, dynamic>> get _deletions => _maps('deletion_requests');
  List<Map<String, dynamic>> get _invoices => _maps('invoices');
  List<Map<String, dynamic>> get _audit => _maps('operator_audit');
  Map<String, dynamic> get _metrics => _snapshot['metrics'] is Map
      ? Map<String, dynamic>.from(_snapshot['metrics'] as Map)
      : const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Map<String, dynamic>> _maps(String key) {
    final value = _snapshot[key];
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> _load() async {
    if (!OperatorService.isAuthenticated) {
      _leave();
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await OperatorService.fetchOverview();
      if (!mounted) return;
      setState(() {
        _snapshot = response['snapshot'] is Map
            ? Map<String, dynamic>.from(response['snapshot'] as Map)
            : const {};
        _system = response['system'] is Map
            ? Map<String, dynamic>.from(response['system'] as Map)
            : const {};
      });
    } on OperatorApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(String success, Future<void> Function() action) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      await action();
      await _load();
      if (mounted) _toast(success);
    } on OperatorApiException catch (error) {
      if (mounted) _toast(error.message, error: true);
    } catch (_) {
      if (mounted) {
        _toast('The owner action could not be completed.', error: true);
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  void _toast(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.danger : AppColors.success,
      ),
    );
  }

  void _leave() {
    OperatorService.logout();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const BusinessGatewayScreen()),
        (_) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AppBackdrop(
      maxWidth: 1540,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 980;
          return Padding(
            padding: EdgeInsets.all(desktop ? AppSpacing.xl : AppSpacing.md),
            child: Column(
              children: [
                _header(desktop),
                const SizedBox(height: AppSpacing.lg),
                if (!desktop) _mobileNavigation(),
                if (!desktop) const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (desktop) ...[
                        SizedBox(width: 235, child: _sidebar()),
                        const SizedBox(width: AppSpacing.lg),
                      ],
                      Expanded(
                        child: _loading
                            ? const Center(child: CircularProgressIndicator())
                            : RefreshIndicator(
                                onRefresh: _load,
                                child: SingleChildScrollView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  child: _content(),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );

  Widget _header(bool desktop) => GlassPanel(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    child: Row(
      children: [
        const BrandLockup(compact: true),
        if (desktop) ...[
          const SizedBox(width: AppSpacing.lg),
          Container(
            width: 1,
            height: 28,
            color: Theme.of(context).dividerColor,
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _section.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'Platform owner control center',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          _statusPill(
            AppIcons.secureUser,
            OperatorService.operatorEmail,
            AppColors.success,
          ),
        ] else
          const Spacer(),
        const SizedBox(width: AppSpacing.sm),
        const GlassThemeToggleButton(),
        IconButton(
          tooltip: 'Refresh control center',
          onPressed: _acting ? null : _load,
          icon: const Icon(AppIcons.refresh),
        ),
        IconButton(
          tooltip: 'End owner session',
          onPressed: _leave,
          icon: const Icon(AppIcons.logout),
        ),
      ],
    ),
  );

  Widget _sidebar() => GlassPanel(
    padding: const EdgeInsets.all(AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Text(
            'PLATFORM OPERATIONS',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final item in _ConsoleSection.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _navItem(item),
          ),
        const Spacer(),
        _statusPill(
          AppIcons.sessionLock,
          'MFA session · 2 hours',
          AppColors.aqua,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Every platform mutation is recorded in the operator audit trail.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );

  Widget _navItem(_ConsoleSection item) {
    final selected = item == _section;
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: .14)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: ListTile(
        dense: true,
        selected: selected,
        leading: Icon(item.icon, color: selected ? AppColors.primary : null),
        title: Text(
          item.label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        onTap: () => setState(() => _section = item),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _mobileNavigation() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final item in _ConsoleSection.values)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: Icon(item.icon, size: 17),
              label: Text(item.label),
              selected: item == _section,
              onSelected: (_) => setState(() => _section = item),
            ),
          ),
      ],
    ),
  );

  Widget _content() {
    if (_error != null) {
      return _empty(
        AppIcons.offline,
        'Control center unavailable',
        _error!,
        action: FilledButton.icon(
          onPressed: _load,
          icon: const Icon(AppIcons.refresh),
          label: const Text('Try again'),
        ),
      );
    }
    return switch (_section) {
      _ConsoleSection.overview => _overview(),
      _ConsoleSection.restaurants => _restaurants(),
      _ConsoleSection.billing => _billing(),
      _ConsoleSection.support => _supportAndPrivacy(),
      _ConsoleSection.security => _security(),
      _ConsoleSection.system => _systemHealth(),
    };
  }

  Widget _overview() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_system['databaseConfigured'] != true) ...[
        _notice(
          AppIcons.database,
          'Preview mode: connect the platform database',
          'The owner gate is working. Add SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY to the API, then apply the operator-console migration to activate live controls.',
          AppColors.warning,
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
      _sectionTitle(
        'Platform at a glance',
        'Live operational signals across every restaurant.',
      ),
      const SizedBox(height: AppSpacing.md),
      GridView.count(
        crossAxisCount: MediaQuery.sizeOf(context).width >= 1180 ? 4 : 2,
        childAspectRatio: MediaQuery.sizeOf(context).width < 600 ? 1.15 : 1.75,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        children: [
          _metricCard(
            'Restaurants',
            _number('businesses'),
            AppIcons.storefront,
            AppColors.primary,
            '${_number('active_businesses')} active',
          ),
          _metricCard(
            'Needs attention',
            _number('attention_businesses'),
            AppIcons.alertNotification,
            AppColors.warning,
            'Plans or access',
          ),
          _metricCard(
            'Live sessions',
            _number('active_sessions'),
            AppIcons.devices,
            AppColors.aqua,
            'Across all tenants',
          ),
          _metricCard(
            'Open support',
            _number('open_support_cases'),
            AppIcons.support,
            AppColors.pink,
            '${_number('open_invoices')} open invoices',
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.xl),
      LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;
          final recent = _businesses.take(5).toList();
          final cases = _support
              .where(
                (item) =>
                    '${item['status']}' == 'open' ||
                    '${item['status']}' == 'in_progress',
              )
              .take(5)
              .toList();
          final first = _dataPanel(
            'Recent restaurants',
            'Newest tenant workspaces',
            recent,
            _businessSummary,
            AppIcons.storefront,
          );
          final second = _dataPanel(
            'Priority inbox',
            'Open support cases',
            cases,
            _supportSummary,
            AppIcons.unreadMail,
          );
          return wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: first),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(child: second),
                  ],
                )
              : Column(
                  children: [
                    first,
                    const SizedBox(height: AppSpacing.lg),
                    second,
                  ],
                );
        },
      ),
    ],
  );

  Widget _restaurants() {
    final query = _restaurantQuery.toLowerCase();
    final filtered = _businesses.where((business) {
      final matchesQuery =
          query.isEmpty ||
          '${business['name']} ${business['business_code']}'
              .toLowerCase()
              .contains(query);
      final active = business['is_active'] == true;
      final status = '${business['subscription_status']}';
      final attention =
          !active ||
          [
            'overdue',
            'grace_period',
            'suspended',
            'cancelled',
          ].contains(status);
      final matchesFilter =
          _restaurantFilter == 'all' ||
          (_restaurantFilter == 'active' && active && !attention) ||
          (_restaurantFilter == 'attention' && attention);
      return matchesQuery && matchesFilter;
    }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(
          'Restaurant portfolio',
          'Provision workspaces, control access, plans, staff limits, and sessions.',
          action: FilledButton.icon(
            onPressed: _acting ? null : _showCreateBusiness,
            icon: const Icon(AppIcons.addBusiness),
            label: const Text('New restaurant'),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        GlassPanel(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 310,
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(AppIcons.search),
                    hintText: 'Search name or workspace code',
                  ),
                  onChanged: (value) =>
                      setState(() => _restaurantQuery = value),
                ),
              ),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: Text('All')),
                  ButtonSegment(value: 'active', label: Text('Healthy')),
                  ButtonSegment(value: 'attention', label: Text('Attention')),
                ],
                selected: {_restaurantFilter},
                onSelectionChanged: (value) =>
                    setState(() => _restaurantFilter = value.first),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (filtered.isEmpty)
          _empty(
            AppIcons.storefront,
            'No restaurants here yet',
            _businesses.isEmpty
                ? 'Provision the first restaurant to start managing the platform.'
                : 'No restaurant matches this filter.',
          )
        else
          ...filtered.map(_businessCard),
      ],
    );
  }

  Widget _businessCard(Map<String, dynamic> business) {
    final active = business['is_active'] == true;
    final status = '${business['subscription_status'] ?? 'unknown'}';
    final color = active && !['overdue', 'grace_period'].contains(status)
        ? AppColors.success
        : AppColors.warning;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: GlassPanel(
        accent: color,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 330,
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: color.withValues(alpha: .14),
                        child: Icon(AppIcons.restaurant, color: color),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${business['name'] ?? 'Unnamed restaurant'}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '${business['business_code'] ?? 'NO-CODE'} · ${business['address'] ?? 'No address'}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _statusPill(
                      AppIcons.layers,
                      _pretty('${business['subscription_tier'] ?? 'basic'}'),
                      AppColors.primary,
                    ),
                    _statusPill(
                      active ? AppIcons.success : AppIcons.pauseCircle,
                      _pretty(status),
                      color,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: 24,
              runSpacing: 10,
              children: [
                _smallStat(
                  AppIcons.team,
                  '${business['active_staff_count'] ?? 0}/${business['max_staff_limit'] ?? 0} active staff',
                ),
                _smallStat(
                  AppIcons.devices,
                  '${business['active_sessions'] ?? 0} sessions',
                ),
                _smallStat(
                  AppIcons.receipt,
                  '${business['ticket_count'] ?? 0} tickets',
                ),
                _smallStat(
                  AppIcons.pointOfSale,
                  business['has_cashier_module'] == true
                      ? 'Cashier enabled'
                      : 'Cashier disabled',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: _acting ? null : () => _showSubscription(business),
                  icon: const Icon(AppIcons.filter),
                  label: const Text('Plan & access'),
                ),
                OutlinedButton.icon(
                  onPressed: _acting ? null : () => _confirmRevoke(business),
                  icon: const Icon(AppIcons.phoneOff),
                  label: const Text('Revoke sessions'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _acting ? null : () => _confirmStatus(business),
                  icon: Icon(active ? AppIcons.pause : AppIcons.play),
                  label: Text(active ? 'Suspend' : 'Activate'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _billing() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _sectionTitle(
        'Plans & billing',
        'Monitor subscription health and invoice history across the portfolio.',
      ),
      const SizedBox(height: AppSpacing.md),
      Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: [
          _compactMetric('Trial', _countBusinesses('trial'), AppColors.aqua),
          _compactMetric(
            'Paid active',
            _countBusinesses('active'),
            AppColors.success,
          ),
          _compactMetric(
            'Overdue / grace',
            _countBusinesses('overdue') + _countBusinesses('grace_period'),
            AppColors.warning,
          ),
          _compactMetric(
            'Suspended',
            _countBusinesses('suspended') + _countBusinesses('cancelled'),
            AppColors.danger,
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.xl),
      _panelHeader('Invoice ledger', '${_invoices.length} latest invoices'),
      const SizedBox(height: AppSpacing.sm),
      if (_invoices.isEmpty)
        _empty(
          AppIcons.receipt,
          'No invoices recorded',
          'Subscription invoices will appear here after billing is connected.',
        )
      else
        ..._invoices.map(
          (invoice) => _listTile(
            icon: AppIcons.receipt,
            color: _statusColor('${invoice['status']}'),
            title:
                '${invoice['business_name'] ?? 'Restaurant'} · ${invoice['invoice_number'] ?? ''}',
            subtitle:
                '${_pretty('${invoice['plan_tier'] ?? ''}')} · due ${_date(invoice['due_at'])}',
            trailing:
                '${invoice['currency'] ?? 'ETB'} ${invoice['amount'] ?? 0} · ${_pretty('${invoice['status'] ?? ''}')}',
          ),
        ),
    ],
  );

  Widget _supportAndPrivacy() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _sectionTitle(
        'Support & privacy',
        'Resolve tenant cases and review account-deletion requests with an audit trail.',
      ),
      const SizedBox(height: AppSpacing.xl),
      _panelHeader('Support queue', '${_support.length} cases'),
      const SizedBox(height: AppSpacing.sm),
      if (_support.isEmpty)
        _empty(
          AppIcons.support,
          'Support inbox is clear',
          'New tenant support cases will be routed here.',
        )
      else
        ..._support.map((item) => _supportCard(item)),
      const SizedBox(height: AppSpacing.xl),
      _panelHeader('Deletion review', '${_deletions.length} requests'),
      const SizedBox(height: AppSpacing.sm),
      if (_deletions.isEmpty)
        _empty(
          AppIcons.privacy,
          'No deletion requests',
          'Privacy requests that require owner review will appear here.',
        )
      else
        ..._deletions.map(
          (request) => _listTile(
            icon: AppIcons.delete,
            color: AppColors.danger,
            title:
                '${request['business_name'] ?? 'Restaurant'} · ${_pretty('${request['status'] ?? ''}')}',
            subtitle:
                '${request['reason'] ?? 'No reason supplied'} · ${_date(request['requested_at'])}',
            action: OutlinedButton(
              onPressed: _acting ? null : () => _showDeletionReview(request),
              child: const Text('Review'),
            ),
          ),
        ),
    ],
  );

  Widget _supportCard(Map<String, dynamic> item) {
    final status = '${item['status'] ?? 'open'}';
    return _listTile(
      icon: AppIcons.support,
      color: _statusColor(status),
      title:
          '${item['business_name'] ?? 'Restaurant'} · ${item['subject'] ?? 'Support case'}',
      subtitle:
          '${_pretty('${item['priority'] ?? 'normal'}')} priority · ${item['description'] ?? ''}',
      action: DropdownButton<String>(
        value: ['open', 'in_progress', 'resolved', 'closed'].contains(status)
            ? status
            : 'open',
        items: const [
          DropdownMenuItem(value: 'open', child: Text('Open')),
          DropdownMenuItem(value: 'in_progress', child: Text('In progress')),
          DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
          DropdownMenuItem(value: 'closed', child: Text('Closed')),
        ],
        onChanged: _acting
            ? null
            : (value) {
                if (value == null || value == status) return;
                _run(
                  'Support case updated.',
                  () => OperatorService.updateSupportCase(
                    caseId: '${item['case_id']}',
                    status: value,
                  ),
                );
              },
      ),
    );
  }

  Widget _security() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _sectionTitle(
        'Security control',
        'Manage privileged access and inspect owner activity.',
      ),
      const SizedBox(height: AppSpacing.md),
      _notice(
        AppIcons.secureUser,
        'Current owner session',
        '${OperatorService.operatorEmail}\nProtected with password, MFA, a signed short-lived token, and server-side authorization.',
        AppColors.success,
      ),
      const SizedBox(height: AppSpacing.lg),
      LayoutBuilder(
        builder: (context, constraints) {
          final cards = [
            _securityCard(
              AppIcons.timer,
              'Short-lived access',
              'Owner sessions expire after two hours and are kept only in memory.',
              AppColors.aqua,
            ),
            _securityCard(
              AppIcons.key,
              'No client secrets',
              'Database service credentials stay in the TypeScript API, never in Flutter.',
              AppColors.primary,
            ),
            _securityCard(
              AppIcons.verifiedList,
              'Audited controls',
              'Restaurant, subscription, session, privacy, and support changes are logged.',
              AppColors.pink,
            ),
          ];
          return constraints.maxWidth >= 850
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      Expanded(child: cards[i]),
                      if (i < cards.length - 1)
                        const SizedBox(width: AppSpacing.md),
                    ],
                  ],
                )
              : Column(
                  children: [
                    for (final card in cards) ...[
                      card,
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ],
                );
        },
      ),
      const SizedBox(height: AppSpacing.xl),
      _panelHeader('Operator audit trail', '${_audit.length} latest events'),
      const SizedBox(height: AppSpacing.sm),
      if (_audit.isEmpty)
        _empty(
          AppIcons.history,
          'No audit events loaded',
          'Privileged actions will appear here once the operator database is connected.',
        )
      else
        ..._audit.map(
          (event) => _listTile(
            icon: AppIcons.history,
            color: AppColors.primary,
            title: _pretty('${event['action'] ?? 'operator_action'}'),
            subtitle:
                '${event['operator_email'] ?? 'Owner'} · ${_date(event['created_at'])}',
            trailing: '${event['subject_type'] ?? 'platform'}',
          ),
        ),
    ],
  );

  Widget _systemHealth() {
    final checks = <(String, String, bool, IconData)>[
      (
        'Owner authentication',
        'Password, MFA, and signed session secret',
        _system['operatorConfigured'] == true,
        AppIcons.administration,
      ),
      (
        'Platform database',
        'Service-role connection and operator RPC migration',
        _system['databaseConfigured'] == true,
        AppIcons.database,
      ),
      (
        'Payment verifier',
        'Upstream transaction-verification credential',
        _system['verifierConfigured'] == true,
        AppIcons.money,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(
          'System health',
          'Production configuration, automated lifecycle controls, and deployment readiness.',
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final check in checks)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _listTile(
              icon: check.$4,
              color: check.$3 ? AppColors.success : AppColors.warning,
              title: check.$1,
              subtitle: check.$2,
              trailing: check.$3 ? 'Ready' : 'Setup required',
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        _notice(
          AppIcons.cloudReady,
          'API environment',
          '${_pretty('${_system['environment'] ?? 'unknown'}')} · snapshot ${_date(_system['generatedAt'])}',
          AppColors.aqua,
        ),
        const SizedBox(height: AppSpacing.lg),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _acting || _system['databaseConfigured'] != true
                ? null
                : () => _run('Subscription lifecycle refreshed.', () async {
                    final changed =
                        await OperatorService.refreshSubscriptionStatuses();
                    if (mounted) {
                      _toast('$changed subscription records changed.');
                    }
                  }),
            icon: const Icon(AppIcons.refresh),
            label: const Text('Run subscription lifecycle'),
          ),
        ),
      ],
    );
  }

  Future<void> _showCreateBusiness() async {
    final name = TextEditingController();
    final code = TextEditingController();
    final address = TextEditingController();
    final adminName = TextEditingController();
    final adminPhone = TextEditingController(text: '+2519');
    final adminPassword = TextEditingController();
    final adminPin = TextEditingController();
    var tier = 'basic';
    var maxStaff = 5;
    var cashier = true;
    final values = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Provision restaurant'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Restaurant name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: code,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Workspace code',
                      hintText: 'MESOB-ADDIS',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: address,
                    decoration: const InputDecoration(labelText: 'Address'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: tier,
                          decoration: const InputDecoration(labelText: 'Plan'),
                          items: const [
                            DropdownMenuItem(
                              value: 'starter',
                              child: Text('Starter'),
                            ),
                            DropdownMenuItem(
                              value: 'basic',
                              child: Text('Basic'),
                            ),
                            DropdownMenuItem(value: 'pro', child: Text('Pro')),
                          ],
                          onChanged: (value) =>
                              setDialogState(() => tier = value ?? tier),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: maxStaff,
                          decoration: const InputDecoration(
                            labelText: 'Staff limit',
                          ),
                          items: const [5, 10, 20, 50]
                              .map(
                                (count) => DropdownMenuItem(
                                  value: count,
                                  child: Text('$count staff'),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setDialogState(
                            () => maxStaff = value ?? maxStaff,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: cashier,
                    title: const Text('Enable cashier module'),
                    onChanged: (value) => setDialogState(() => cashier = value),
                  ),
                  const Divider(),
                  Text(
                    'ROOT ADMIN',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: adminName,
                    decoration: const InputDecoration(labelText: 'Admin name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: adminPhone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Admin phone'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: adminPassword,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Temporary password (10+ characters)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: adminPin,
                    decoration: const InputDecoration(
                      labelText: 'Staff number / PIN',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, {
                'name': name.text,
                'businessCode': code.text,
                'address': address.text,
                'tier': tier,
                'status': 'trial',
                'maxStaff': maxStaff,
                'hasCashier': cashier,
                'adminName': adminName.text,
                'adminPhone': adminPhone.text,
                'adminPassword': adminPassword.text,
                'adminPin': adminPin.text,
              }),
              child: const Text('Provision securely'),
            ),
          ],
        ),
      ),
    );
    for (final controller in [
      name,
      code,
      address,
      adminName,
      adminPhone,
      adminPassword,
      adminPin,
    ]) {
      controller.dispose();
    }
    if (values != null) {
      await _run(
        'Restaurant provisioned.',
        () => OperatorService.createBusiness(values),
      );
    }
  }

  Future<void> _showSubscription(Map<String, dynamic> business) async {
    var tier = '${business['subscription_tier'] ?? 'basic'}';
    var status = '${business['subscription_status'] ?? 'active'}';
    var maxStaff = (business['max_staff_limit'] as num?)?.toInt() ?? 5;
    var cashier = business['has_cashier_module'] == true;
    final values = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Plan & access · ${business['name']}'),
          content: SizedBox(
            width: 470,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: tier,
                  decoration: const InputDecoration(labelText: 'Plan'),
                  items: const [
                    DropdownMenuItem(value: 'starter', child: Text('Starter')),
                    DropdownMenuItem(value: 'basic', child: Text('Basic')),
                    DropdownMenuItem(value: 'pro', child: Text('Pro')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => tier = value ?? tier),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(
                    labelText: 'Subscription status',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'trial', child: Text('Trial')),
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'overdue', child: Text('Overdue')),
                    DropdownMenuItem(
                      value: 'grace_period',
                      child: Text('Grace period'),
                    ),
                    DropdownMenuItem(
                      value: 'suspended',
                      child: Text('Suspended'),
                    ),
                    DropdownMenuItem(
                      value: 'cancelled',
                      child: Text('Cancelled'),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => status = value ?? status),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: '$maxStaff',
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Maximum staff'),
                  onChanged: (value) =>
                      maxStaff = int.tryParse(value) ?? maxStaff,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: cashier,
                  title: const Text('Cashier module'),
                  onChanged: (value) => setDialogState(() => cashier = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, {
                'tier': tier,
                'status': status,
                'maxStaff': maxStaff,
                'hasCashier': cashier,
              }),
              child: const Text('Save controls'),
            ),
          ],
        ),
      ),
    );
    if (values == null) return;
    await _run(
      'Subscription controls updated.',
      () => OperatorService.updateSubscription(
        businessId: '${business['business_id']}',
        tier: '${values['tier']}',
        status: '${values['status']}',
        maxStaff: values['maxStaff'] as int,
        hasCashier: values['hasCashier'] as bool,
        endsAt: business['subscription_ends_at']?.toString(),
        graceEndsAt: business['grace_ends_at']?.toString(),
      ),
    );
  }

  Future<void> _confirmStatus(Map<String, dynamic> business) async {
    final active = business['is_active'] == true;
    final confirmed = await _confirm(
      active ? 'Suspend restaurant?' : 'Activate restaurant?',
      active
          ? 'This blocks the workspace and immediately revokes its active staff sessions.'
          : 'This restores workspace access. Subscription rules still apply.',
      active ? 'Suspend' : 'Activate',
    );
    if (confirmed) {
      await _run(
        active ? 'Restaurant suspended.' : 'Restaurant activated.',
        () => OperatorService.setBusinessStatus(
          businessId: '${business['business_id']}',
          active: !active,
          reason: 'Owner console action',
        ),
      );
    }
  }

  Future<void> _confirmRevoke(Map<String, dynamic> business) async {
    final confirmed = await _confirm(
      'Revoke every active session?',
      'All staff at ${business['name']} will need to sign in again.',
      'Revoke sessions',
    );
    if (confirmed) {
      await _run('Active sessions revoked.', () async {
        await OperatorService.revokeBusinessSessions(
          businessId: '${business['business_id']}',
          reason: 'Owner console security action',
        );
      });
    }
  }

  Future<void> _showDeletionReview(Map<String, dynamic> request) async {
    var status = '${request['status'] ?? 'pending_review'}';
    if (![
      'pending_review',
      'retention_hold',
      'approved',
      'rejected',
    ].contains(status)) {
      status = 'pending_review';
    }
    final notes = TextEditingController(
      text: '${request['review_notes'] ?? ''}',
    );
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Privacy request · ${request['business_name']}'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${request['reason'] ?? 'No reason supplied'}'),
                const SizedBox(height: AppSpacing.lg),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(
                    labelText: 'Review decision',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'pending_review',
                      child: Text('Pending review'),
                    ),
                    DropdownMenuItem(
                      value: 'retention_hold',
                      child: Text('Retention hold'),
                    ),
                    DropdownMenuItem(
                      value: 'approved',
                      child: Text('Approved'),
                    ),
                    DropdownMenuItem(
                      value: 'rejected',
                      child: Text('Rejected'),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => status = value ?? status),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notes,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Audit notes'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, (status, notes.text)),
              child: const Text('Record review'),
            ),
          ],
        ),
      ),
    );
    notes.dispose();
    if (result != null) {
      await _run(
        'Deletion review recorded.',
        () => OperatorService.reviewDeletionRequest(
          requestId: '${request['request_id']}',
          status: result.$1,
          notes: result.$2,
        ),
      );
    }
  }

  Future<bool> _confirm(String title, String message, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Widget _sectionTitle(String title, String subtitle, {Widget? action}) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            if (!AppVariant.usesMinimalCopy) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      ),
      if (action != null) ...[const SizedBox(width: AppSpacing.md), action],
    ],
  );

  Widget _metricCard(
    String label,
    int value,
    IconData icon,
    Color color,
    String detail,
  ) => GlassPanel(
    accent: color,
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: color),
            const Spacer(),
            Text(
              '$value',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            if (!AppVariant.usesMinimalCopy)
              Text(detail, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ],
    ),
  );

  Widget _compactMetric(String label, int value, Color color) => SizedBox(
    width: 210,
    child: GlassPanel(
      accent: color,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: .14),
            child: Text(
              '$value',
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.titleSmall),
          ),
        ],
      ),
    ),
  );

  Widget _dataPanel(
    String title,
    String subtitle,
    List<Map<String, dynamic>> items,
    Widget Function(Map<String, dynamic>) row,
    IconData emptyIcon,
  ) => GlassPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _panelHeader(title, subtitle),
        const SizedBox(height: AppSpacing.md),
        if (items.isEmpty)
          _empty(
            emptyIcon,
            'Nothing to show yet',
            'Live platform data will appear here.',
          )
        else
          ...items.map(row),
      ],
    ),
  );

  Widget _businessSummary(Map<String, dynamic> item) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.primary.withValues(alpha: .12),
          child: const Icon(
            AppIcons.storefront,
            size: 18,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${item['name']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${item['business_code']} · ${_pretty('${item['subscription_status']}')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _supportSummary(Map<String, dynamic> item) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Icon(
          AppIcons.dot,
          size: 10,
          color: _statusColor('${item['priority']}'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${item['subject']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${item['business_name']} · ${_pretty('${item['status']}')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _panelHeader(String title, String detail) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      if (!AppVariant.usesMinimalCopy)
        Text(detail, style: Theme.of(context).textTheme.bodySmall),
    ],
  );

  Widget _listTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    String? trailing,
    Widget? action,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: GlassPanel(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: .13),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (!AppVariant.usesMinimalCopy) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.md),
            Text(
              trailing,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ],
          if (action != null) ...[const SizedBox(width: AppSpacing.md), action],
        ],
      ),
    ),
  );

  Widget _notice(IconData icon, String title, String message, Color color) =>
      GlassPanel(
        accent: color,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(message, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _securityCard(
    IconData icon,
    String title,
    String message,
    Color color,
  ) => GlassPanel(
    accent: color,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 30),
        const SizedBox(height: AppSpacing.md),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(message, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );

  Widget _empty(
    IconData icon,
    String title,
    String message, {
    Widget? action,
  }) => GlassPanel(
    padding: const EdgeInsets.all(AppSpacing.xl),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (!AppVariant.usesMinimalCopy) ...[
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action,
            ],
          ],
        ),
      ),
    ),
  );

  Widget _statusPill(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .11),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: color.withValues(alpha: .24)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );

  Widget _smallStat(IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        icon,
        size: 17,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );

  int _number(String key) => (_metrics[key] as num?)?.toInt() ?? 0;
  int _countBusinesses(String status) => _businesses
      .where((item) => '${item['subscription_status']}' == status)
      .length;
  String _pretty(String value) => value.isEmpty
      ? 'Unknown'
      : value
            .replaceAll('_', ' ')
            .split(' ')
            .map(
              (word) => word.isEmpty
                  ? word
                  : '${word[0].toUpperCase()}${word.substring(1)}',
            )
            .join(' ');
  String _date(dynamic value) {
    final date = DateTime.tryParse('$value')?.toLocal();
    if (date == null) return 'not set';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Color _statusColor(String status) {
    final value = status.toLowerCase();
    if (['active', 'paid', 'resolved', 'closed', 'low'].contains(value)) {
      return AppColors.success;
    }
    if ([
      'overdue',
      'grace_period',
      'open',
      'medium',
      'normal',
      'pending_review',
    ].contains(value)) {
      return AppColors.warning;
    }
    if ([
      'suspended',
      'cancelled',
      'critical',
      'high',
      'rejected',
    ].contains(value)) {
      return AppColors.danger;
    }
    return AppColors.primary;
  }
}
