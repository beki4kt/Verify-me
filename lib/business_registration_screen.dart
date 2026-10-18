import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'api_service.dart';
import 'core/config/app_variant.dart';
import 'core/theme/app_colors.dart';
import 'launch_experience.dart';
import 'offline_storage.dart';
import 'plan_catalog.dart';

class BusinessRegistrationScreen extends StatefulWidget {
  const BusinessRegistrationScreen({super.key});
  @override
  State<BusinessRegistrationScreen> createState() =>
      _BusinessRegistrationScreenState();
}

class _BusinessRegistrationScreenState
    extends State<BusinessRegistrationScreen> {
  int step = 0;
  String useCase = 'general';
  bool team = false;
  String review = 'automatic';
  String reference = 'none';
  String plan = 'basic';
  BillingPeriod period = BillingPeriod.monthly;
  String provider = 'telebirr';
  bool awaitingConfirmation = false;
  bool busy = false;
  bool hidePassword = true;
  String? error;
  final business = TextEditingController();
  final owner = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final account = TextEditingController();

  @override
  void initState() {
    super.initState();
    final draft = DeviceStorage.getOnboardingDraft();
    if (draft != null) {
      step = (draft['step'] as int? ?? 0).clamp(0, 3);
      useCase = draft['use_case']?.toString() ?? useCase;
      team = draft['team'] == true;
      review = draft['review']?.toString() ?? review;
      reference = draft['reference']?.toString() ?? reference;
      plan = draft['plan']?.toString() ?? plan;
      period = draft['period'] == 'quarterly'
          ? BillingPeriod.quarterly
          : BillingPeriod.monthly;
      provider = draft['provider']?.toString() ?? provider;
      business.text = draft['business']?.toString() ?? '';
      owner.text = draft['owner']?.toString() ?? '';
      phone.text = draft['phone']?.toString() ?? '';
      email.text = draft['email']?.toString() ?? '';
      account.text = draft['account']?.toString() ?? '';
      awaitingConfirmation = draft['confirmation_pending'] == true;
    }
    for (final field in [business, owner, phone, email, account]) {
      field.addListener(_saveDraft);
    }
  }

  void _saveDraft() {
    DeviceStorage.saveOnboardingDraft({
      'step': step,
      'use_case': useCase,
      'team': team,
      'review': review,
      'reference': reference,
      'plan': plan,
      'period': period.name,
      'provider': provider,
      'business': business.text,
      'owner': owner.text,
      'phone': phone.text,
      'email': email.text,
      'account': account.text,
      'confirmation_pending': awaitingConfirmation,
    });
  }

  @override
  void dispose() {
    for (final field in [business, owner, phone, email, password, account]) {
      field.dispose();
    }
    super.dispose();
  }

  void _chooseUseCase(String value) {
    setState(() {
      useCase = value;
      reference = switch (value) {
        'restaurant' => 'table',
        'shop' => 'order',
        'service' => 'invoice',
        _ => 'none',
      };
    });
    _saveDraft();
  }

  void _next() {
    setState(() {
      step++;
      error = null;
    });
    _saveDraft();
  }

  void _back() {
    if (step == 0) {
      Navigator.maybePop(context);
      return;
    }
    setState(() {
      step--;
      error = null;
    });
    _saveDraft();
  }

  Future<void> _submit() async {
    if (business.text.trim().length < 2 ||
        owner.text.trim().length < 2 ||
        !RegExp(r'^\+251[79]\d{8}$').hasMatch(phone.text.trim()) ||
        !email.text.trim().contains('@') ||
        password.text.length < 10 ||
        account.text.trim().length < 6) {
      setState(
        () => error = 'Complete every field. Use a +251 phone and a password of at least 10 characters.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (!ApiService.hasOwnerAuth) {
        if (awaitingConfirmation) {
          await ApiService.signInOwner(email.text, password.text);
        } else {
          final signedIn = await ApiService.signUpOwner(
            email.text,
            password.text,
          );
          if (!signedIn) {
            if (!mounted) return;
            setState(() => awaitingConfirmation = true);
            _saveDraft();
            return;
          }
        }
      }
      final result = await ApiService.requestOwnerWorkspace(
        businessName: business.text.trim(),
        ownerName: owner.text.trim(),
        ownerPhone: phone.text.trim(),
        useCase: useCase,
        referenceKind: reference,
        reviewPolicy: review,
        team: team,
        plan: plan,
        billingPeriod: period.name,
        provider: provider,
        receivingAccount: account.text.trim(),
      );
      await DeviceStorage.clearOnboardingDraft();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        CupertinoPageRoute<void>(
          builder: (_) => OwnerActivationScreen(registration: result),
        ),
        (_) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _choice(
    String value,
    String title,
    String description,
    IconData icon,
    String selected,
    ValueChanged<String> onSelect,
  ) {
    final active = value == selected;
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Semantics(
        button: true,
        selected: active,
        child: Material(
          color: active
              ? AppColors.primary.withValues(alpha: .12)
              : Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(19),
          child: InkWell(
            borderRadius: BorderRadius.circular(19),
            onTap: () => onSelect(value),
            child: Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(19),
                border: Border.all(
                  color: active
                      ? AppColors.primary
                      : Theme.of(context).colorScheme.outlineVariant,
                  width: active ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: active
                        ? AppColors.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          description,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (active)
                    const Icon(
                      CupertinoIcons.check_mark_circled_solid,
                      color: AppColors.primary,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _content() => switch (step) {
    0 => [
      _choice(
        'shop',
        'Shop / Retail',
        'Customer payments and orders',
        CupertinoIcons.bag,
        useCase,
        _chooseUseCase,
      ),
      _choice(
        'restaurant',
        'Restaurant / Cafe',
        'Tables, orders and optional tips',
        CupertinoIcons.square_list,
        useCase,
        _chooseUseCase,
      ),
      _choice(
        'service',
        'Services',
        'Invoices, bookings and customers',
        CupertinoIcons.briefcase,
        useCase,
        _chooseUseCase,
      ),
      _choice(
        'general',
        'General Business',
        'A flexible payment workspace',
        CupertinoIcons.square_grid_2x2,
        useCase,
        _chooseUseCase,
      ),
    ],
    1 => [
      Text(
        'Who will be using Chekmi?',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 14),
      _choice(
        'solo',
        'Just Me',
        'I verify and manage payments myself',
        CupertinoIcons.person,
        team ? 'team' : 'solo',
        (v) {
          setState(() {
            team = false;
            review = 'automatic';
          });
          _saveDraft();
        },
      ),
      _choice(
        'team',
        'Me and My Team',
        'Staff can verify and review payments',
        CupertinoIcons.person_2,
        team ? 'team' : 'solo',
        (v) {
          setState(() {
            team = true;
            plan = 'pro';
          });
          _saveDraft();
        },
      ),
      const SizedBox(height: 16),
      Text(
        'How should payments be handled?',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 14),
      _choice(
        'automatic',
        'Complete Automatically',
        'After bank verification, Chekmi marks the payment complete',
        CupertinoIcons.checkmark_shield,
        review,
        (v) {
          setState(() => review = v);
          _saveDraft();
        },
      ),
      _choice(
        'review_required',
        'Require Review',
        'An authorized member completes it after verification',
        CupertinoIcons.person_crop_circle_badge_checkmark,
        review,
        (v) {
          setState(() => review = v);
          _saveDraft();
        },
      ),
      const SizedBox(height: 16),
      Text(
        'Track payments against',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        key: ValueKey(reference),
        initialValue: reference,
        decoration: const InputDecoration(labelText: 'Default reference'),
        items: const [
          DropdownMenuItem(value: 'none', child: Text('No extra reference')),
          DropdownMenuItem(value: 'invoice', child: Text('Invoice')),
          DropdownMenuItem(value: 'order', child: Text('Order')),
          DropdownMenuItem(value: 'booking', child: Text('Booking')),
          DropdownMenuItem(value: 'customer', child: Text('Customer')),
          DropdownMenuItem(value: 'table', child: Text('Table')),
          DropdownMenuItem(value: 'note', child: Text('Note')),
        ],
        onChanged: (v) {
          if (v != null) {
            setState(() => reference = v);
            _saveDraft();
          }
        },
      ),
    ],
    2 => [
      Text(
        'Choose the plan that fits today.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      const SizedBox(height: 18),
      SegmentedButton<BillingPeriod>(
        segments: const [
          ButtonSegment(value: BillingPeriod.monthly, label: Text('Monthly')),
          ButtonSegment(
            value: BillingPeriod.quarterly,
            label: Text('3 months'),
          ),
        ],
        selected: {period},
        onSelectionChanged: (v) {
          setState(() => period = v.first);
          _saveDraft();
        },
      ),
      const SizedBox(height: 20),
      for (final item in PlanCatalog.all)
        _choice(
          item.id,
          item.name,
          item.priceFor(period) == null
              ? '${item.tagline} Price arranged during activation.'
              : '${item.priceFor(period)} ETB / ${period == BillingPeriod.monthly ? 'month' : '3 months'} · ${item.staffLimit} member',
          item.id == 'basic'
              ? CupertinoIcons.square_stack
              : CupertinoIcons.sparkles,
          plan,
          (v) {
            if (team && v == 'basic') {
              setState(() => error = 'A team needs the Pro plan.');
              return;
            }
            setState(() {
              plan = v;
              error = null;
            });
            _saveDraft();
          },
        ),
      const SizedBox(height: 6),
      const Text(
        'Choosing a plan does not charge you. Activation is reviewed after registration.',
      ),
    ],
    _ => [
      TextField(
        controller: business,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Business name'),
      ),
      const SizedBox(height: 13),
      TextField(
        controller: owner,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Your name'),
      ),
      const SizedBox(height: 13),
      TextField(
        controller: phone,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(
          labelText: 'Phone number',
          hintText: '+2519…',
        ),
      ),
      const SizedBox(height: 13),
      TextField(
        controller: email,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        decoration: const InputDecoration(labelText: 'Owner email'),
      ),
      const SizedBox(height: 13),
      TextField(
        controller: password,
        obscureText: hidePassword,
        autofillHints: const [AutofillHints.newPassword],
        decoration: InputDecoration(
          labelText: 'Password',
          helperText: 'At least 10 characters',
          suffixIcon: IconButton(
            tooltip: hidePassword ? 'Show password' : 'Hide password',
            onPressed: () => setState(() => hidePassword = !hidePassword),
            icon: Icon(
              hidePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
        ),
      ),
      const SizedBox(height: 23),
      Text('Receiving account', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        initialValue: provider,
        decoration: const InputDecoration(labelText: 'Payment provider'),
        items: AppVariant.enabledPaymentProviders
            .map(
              (item) =>
                  DropdownMenuItem(value: item.id, child: Text(item.label)),
            )
            .toList(),
        onChanged: (v) {
          if (v != null) {
            setState(() => provider = v);
            _saveDraft();
          }
        },
      ),
      const SizedBox(height: 13),
      TextField(
        controller: account,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(
          labelText: 'Account or wallet number',
        ),
      ),
      if (awaitingConfirmation)
        const Padding(
          padding: EdgeInsets.only(top: 20),
          child: Text(
            'Confirm the email we sent, then enter your password here and continue.',
          ),
        ),
    ],
  };

  @override
  Widget build(BuildContext context) {
    const titles = [
      'Let’s personalize Chekmi for you.',
      'Make payments work your way.',
      'Choose your plan.',
      'Create your workspace.',
    ];
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: _back,
          icon: const Icon(CupertinoIcons.back),
          tooltip: 'Back',
        ),
        title: const Text('Register your business'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
              children: [
                LinearProgressIndicator(
                  value: (step + 1) / 4,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 11),
                Text(
                  'Step ${step + 1} of 4',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 26),
                Text(
                  titles[step],
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  step == 0
                      ? 'Tell us how you work. You can change this later.'
                      : step == 3
                      ? 'Your email confirms ownership. Your plan starts only after activation.'
                      : 'A few choices now will make your workspace feel right from the start.',
                ),
                const SizedBox(height: 27),
                ..._content(),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 15),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 30),
                SizedBox(
                  height: 55,
                  child: FilledButton(
                    onPressed: busy
                        ? null
                        : step == 3
                        ? _submit
                        : _next,
                    child: busy
                        ? const CircularProgressIndicator()
                        : Text(
                            step == 3
                                ? awaitingConfirmation
                                      ? 'I’ve confirmed my email'
                                      : 'Create workspace request'
                                : 'Continue',
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
