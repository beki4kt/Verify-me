import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'api_service.dart';
import 'core/config/app_variant.dart';
import 'core/config/payment_context.dart';
import 'core/models/business_presets.dart';
import 'core/models/ethiopian_phone.dart';
import 'core/widgets/entry_components.dart';
import 'iphone/interactive_preview_screen.dart';
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
  String categoryId = 'shop_retail';
  String subtypeId = 'supermarket';
  String workflowId = 'single_counter';
  bool adjustSetup = false;
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
  final otp = TextEditingController();
  final account = TextEditingController();

  bool get phoneIdentity => AppVariant.phoneOwnerAuthAvailable;

  @override
  void initState() {
    super.initState();
    final draft = DeviceStorage.getOnboardingDraft();
    if (draft != null) {
      final oldStep = (draft['step'] as int? ?? 0).clamp(0, 4);
      step = draft['onboarding_version'] == 2
          ? oldStep
          : switch (oldStep) {
              0 => 0,
              1 => 2,
              2 => 3,
              _ => 4,
            };
      useCase = draft['use_case']?.toString() ?? useCase;
      categoryId =
          draft['category_id']?.toString() ??
          switch (useCase) {
            'shop' => 'shop_retail',
            'restaurant' => 'food_hospitality',
            'service' => 'services_professionals',
            _ => 'general_personal',
          };
      final category = BusinessPresets.category(categoryId);
      subtypeId =
          draft['subtype_id']?.toString() ??
          (useCase == 'restaurant' ? 'restaurant' : category.subtypes.first.id);
      workflowId =
          draft['workflow_id']?.toString() ??
          BusinessPresets.subtype(category, subtypeId).choices.first.id;
      team = draft['team'] == true;
      review = draft['review']?.toString() ?? review;
      reference = draft['reference']?.toString() ?? reference;
      plan = draft['plan']?.toString() ?? plan;
      period = draft['period'] == 'quarterly'
          ? BillingPeriod.quarterly
          : BillingPeriod.monthly;
      provider = draft['provider']?.toString() ?? provider;
      awaitingConfirmation =
          draft['confirmation_pending'] == true &&
          draft['identity_method'] == (phoneIdentity ? 'phone' : 'email');
    } else {
      _applyWorkflow();
    }
  }

  void _saveDraft() {
    DeviceStorage.saveOnboardingDraft({
      'onboarding_version': 2,
      'step': step,
      'category_id': categoryId,
      'subtype_id': subtypeId,
      'workflow_id': workflowId,
      'use_case': useCase,
      'team': team,
      'review': review,
      'reference': reference,
      'plan': plan,
      'period': period.name,
      'provider': provider,
      'confirmation_pending': awaitingConfirmation,
      'identity_method': phoneIdentity ? 'phone' : 'email',
    });
  }

  @override
  void dispose() {
    for (final field in [
      business,
      owner,
      phone,
      email,
      password,
      otp,
      account,
    ]) {
      field.dispose();
    }
    super.dispose();
  }

  BusinessCategory get category => BusinessPresets.category(categoryId);
  BusinessSubtype get subtype => BusinessPresets.subtype(category, subtypeId);
  WorkflowChoice get workflow => BusinessPresets.workflow(subtype, workflowId);

  void _chooseCategory(String value) {
    setState(() {
      categoryId = value;
      subtypeId = category.subtypes.first.id;
      workflowId = subtype.choices.first.id;
      _applyWorkflow();
    });
    _saveDraft();
  }

  void _chooseSubtype(String value) {
    setState(() {
      subtypeId = value;
      workflowId = subtype.choices.first.id;
      _applyWorkflow();
    });
    _saveDraft();
  }

  void _chooseWorkflow(String value) {
    setState(() {
      workflowId = value;
      _applyWorkflow();
    });
    _saveDraft();
  }

  void _applyWorkflow() {
    useCase = subtype.backendUseCase ?? category.backendUseCase;
    reference = workflow.reference;
    team = workflow.team;
    review = workflow.review;
    if (team) plan = 'pro';
  }

  void _next() {
    if (step == 2 && (category.previewOnly || useCase == 'personal')) {
      Navigator.of(context).push(
        CupertinoPageRoute<void>(
          builder: (_) =>
              InteractivePreviewScreen(events: category.previewOnly),
        ),
      );
      return;
    }
    setState(() {
      step++;
      error = null;
    });
    _saveDraft();
  }

  void _back() {
    if (step == 0) {
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
      } else {
        navigator.pushReplacement(
          CupertinoPageRoute<void>(builder: (_) => const WelcomeScreen()),
        );
      }
      return;
    }
    setState(() {
      step--;
      error = null;
    });
    _saveDraft();
  }

  Future<void> _submit() async {
    if (AppVariant.isUiPreview) {
      setState(() => error = 'Registration needs the functional build.');
      return;
    }
    if (!AppVariant.selfRegistrationAvailable) {
      setState(
        () => error = 'Business registration is not open yet. Your setup choices are saved on this device.',
      );
      return;
    }
    String normalizedPhone;
    try {
      normalizedPhone = normalizeEthiopianPhone(phone.text);
    } on FormatException {
      setState(() => error = 'Enter a valid Ethiopian mobile number.');
      return;
    }
    final credentialsNeeded = !ApiService.hasOwnerAuth;
    if (business.text.trim().length < 2 ||
        owner.text.trim().length < 2 ||
        (credentialsNeeded &&
            !phoneIdentity &&
            !email.text.trim().contains('@')) ||
        (credentialsNeeded &&
            !(phoneIdentity && awaitingConfirmation) &&
            password.text.length < 10) ||
        (credentialsNeeded &&
            phoneIdentity &&
            awaitingConfirmation &&
            !RegExp(r'^\d{6}$').hasMatch(otp.text.trim())) ||
        account.text.trim().length < 6) {
      setState(
        () => error =
            'Complete the required fields and check your sign-in details.',
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
          if (phoneIdentity) {
            await ApiService.verifyOwnerPhoneOtp(phone.text, otp.text);
          } else {
            await ApiService.signInOwner(email.text, password.text);
          }
        } else {
          final signedIn = phoneIdentity
              ? await ApiService.signUpOwnerPhone(phone.text, password.text)
              : await ApiService.signUpOwner(email.text, password.text);
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
        ownerPhone: normalizedPhone,
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

  Widget _categoryCard(BusinessCategory item, {bool wide = false}) {
    final selected = item.id == categoryId;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? EntryColors.selected : EntryColors.surface,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () => _chooseCategory(item.id),
          child: Container(
            height: wide ? 69 : 124,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: selected ? EntryColors.blue : EntryColors.line,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: wide
                ? Row(
                    children: [
                      Icon(item.icon, color: EntryColors.muted, size: 21),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          item.label,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (selected)
                        const Icon(
                          CupertinoIcons.checkmark,
                          color: EntryColors.blue,
                          size: 18,
                        ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(item.icon, color: EntryColors.muted, size: 21),
                          const Spacer(),
                          if (selected)
                            const Icon(
                              CupertinoIcons.checkmark,
                              color: EntryColors.blue,
                              size: 17,
                            ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        item.label,
                        maxLines: 2,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.13,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _selectionRow({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? EntryColors.selected : EntryColors.surface,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 53),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: selected ? EntryColors.blue : EntryColors.line,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(
                  selected
                      ? CupertinoIcons.checkmark_circle_fill
                      : CupertinoIcons.circle,
                  color: selected ? EntryColors.blue : EntryColors.muted,
                  size: 21,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  List<Widget> _content() => switch (step) {
    0 => [
      for (var row = 0; row < 2; row++) ...[
        Row(
          children: [
            Expanded(child: _categoryCard(BusinessPresets.categories[row * 2])),
            const SizedBox(width: 10),
            Expanded(
              child: _categoryCard(BusinessPresets.categories[row * 2 + 1]),
            ),
          ],
        ),
        const SizedBox(height: 10),
      ],
      _categoryCard(BusinessPresets.categories[4], wide: true),
    ],
    1 => [
      for (final item in category.subtypes)
        _selectionRow(
          title: item.label,
          selected: item.id == subtypeId,
          onTap: () => _chooseSubtype(item.id),
        ),
    ],
    2 => [
      Text(
        subtype.label,
        style: const TextStyle(
          color: EntryColors.muted,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 16),
      for (final item in subtype.choices)
        _selectionRow(
          title: item.label,
          selected: item.id == workflowId,
          onTap: () => _chooseWorkflow(item.id),
        ),
      const SizedBox(height: 20),
      const Divider(color: EntryColors.line),
      _summaryRow(
        'Track by',
        reference == 'none'
            ? 'Payment reference'
            : PaymentContextKind.fromStorage(reference).label,
      ),
      _summaryRow('Workspace', team ? 'My Team' : 'Just Me'),
      _summaryRow(
        'Completion',
        review == 'review_required' ? 'Review' : 'Auto',
      ),
      const Divider(color: EntryColors.line),
      TextButton(
        onPressed: () => setState(() => adjustSetup = !adjustSetup),
        style: TextButton.styleFrom(foregroundColor: EntryColors.blue),
        child: Text(adjustSetup ? 'Hide setup' : 'Adjust setup'),
      ),
      if (adjustSetup) ...[
        const SizedBox(height: 12),
        const Text(
          'Who uses Chekmi?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 9),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Just Me')),
            ButtonSegment(value: true, label: Text('My Team')),
          ],
          selected: {team},
          onSelectionChanged: (value) {
            setState(() {
              team = value.first;
              if (team) plan = 'pro';
            });
            _saveDraft();
          },
        ),
        const SizedBox(height: 19),
        const Text(
          'When is payment complete?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 9),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'automatic', label: Text('Auto')),
            ButtonSegment(value: 'review_required', label: Text('Review')),
          ],
          selected: {review},
          onSelectionChanged: (value) {
            setState(() => review = value.first);
            _saveDraft();
          },
        ),
        const SizedBox(height: 19),
        DropdownButtonFormField<String>(
          key: ValueKey(reference),
          initialValue: reference,
          decoration: const InputDecoration(labelText: 'Track payments by'),
          items: PaymentContextKind.values
              .where((kind) => kind != PaymentContextKind.other)
              .map(
                (kind) => DropdownMenuItem(
                  value: kind.name,
                  child: Text(
                    kind == PaymentContextKind.none
                        ? 'Payment reference'
                        : kind.label,
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => reference = value);
              _saveDraft();
            }
          },
        ),
      ],
      if (category.previewOnly || useCase == 'personal') ...[
        const SizedBox(height: 15),
        const Text(
          'This setup is an illustrative preview. Registration is not open yet.',
          style: TextStyle(color: EntryColors.muted),
        ),
      ],
    ],
    3 => [
      SegmentedButton<BillingPeriod>(
        segments: const [
          ButtonSegment(value: BillingPeriod.monthly, label: Text('Monthly')),
          ButtonSegment(
            value: BillingPeriod.quarterly,
            label: Text('3 months'),
          ),
        ],
        selected: {period},
        onSelectionChanged: (value) {
          setState(() => period = value.first);
          _saveDraft();
        },
      ),
      const SizedBox(height: 20),
      for (final item in PlanCatalog.all)
        _selectionRow(
          title: item.priceFor(period) == null
              ? '${item.name} · Price arranged at activation'
              : '${item.name} · ${item.priceFor(period)} ETB / ${period == BillingPeriod.monthly ? 'month' : '3 months'}',
          selected: item.id == plan,
          onTap: () {
            if (team && item.id == 'basic') {
              setState(() => error = 'A team needs the Pro plan.');
              return;
            }
            setState(() {
              plan = item.id;
              error = null;
            });
            _saveDraft();
          },
        ),
      const SizedBox(height: 8),
      const Text(
        'No charge now. Activation is reviewed after registration.',
        style: TextStyle(color: EntryColors.muted),
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
        decoration: const InputDecoration(labelText: 'Owner name'),
      ),
      const SizedBox(height: 13),
      TextField(
        controller: phone,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(
          labelText: 'Phone number',
          hintText: '9…',
          prefixText: '+251  ',
        ),
      ),
      const SizedBox(height: 13),
      if (!phoneIdentity) ...[
        TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(
            labelText: 'Owner email for sign-in',
          ),
        ),
        const SizedBox(height: 13),
      ],
      if (phoneIdentity && awaitingConfirmation)
        TextField(
          controller: otp,
          keyboardType: TextInputType.number,
          maxLength: 6,
          autofillHints: const [AutofillHints.oneTimeCode],
          decoration: const InputDecoration(labelText: 'SMS verification code'),
        )
      else
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
                hidePassword ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
              ),
            ),
          ),
        ),
      const SizedBox(height: 22),
      const Text(
        'Receiving account',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: provider,
        decoration: const InputDecoration(labelText: 'Payment provider'),
        items: AppVariant.enabledPaymentProviders
            .map(
              (item) =>
                  DropdownMenuItem(value: item.id, child: Text(item.label)),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() => provider = value);
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
          padding: EdgeInsets.only(top: 16),
          child: Text(
            'Confirm your identity, then continue here.',
            style: TextStyle(color: EntryColors.muted),
          ),
        ),
    ],
  };

  Widget _summaryRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Text(label, style: const TextStyle(color: EntryColors.muted)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final subtypeTitle = switch (categoryId) {
      'shop_retail' => 'What kind of shop?',
      'food_hospitality' => 'What do you operate?',
      'services_professionals' => 'What service do you offer?',
      'events_venues' => 'What type of event?',
      _ => 'How will you use Chekmi?',
    };
    final titles = [
      'Choose your business',
      subtypeTitle,
      subtype.question,
      'Choose your plan',
      'Create your business',
    ];
    return ChekmiEntryTheme(
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(23, 16, 23, 0),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: EntryBackButton(onPressed: _back),
                        ),
                        const SizedBox(height: 21),
                        EntryStepProgress(step: step + 1, total: 5),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(23, 27, 23, 18),
                      children: [
                        Text(
                          titles[step],
                          style: const TextStyle(
                            fontSize: 31,
                            height: 1.09,
                            letterSpacing: -1.2,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (step == 4) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${subtype.label} · ${workflow.label}',
                            style: const TextStyle(color: EntryColors.muted),
                          ),
                        ],
                        const SizedBox(height: 28),
                        ..._content(),
                        if (error != null) ...[
                          const SizedBox(height: 15),
                          Text(
                            error!,
                            style: const TextStyle(color: EntryColors.error),
                          ),
                        ],
                        if (step == 4) ...[
                          const SizedBox(height: 16),
                          Text(
                            phoneIdentity
                                ? 'Verify your phone. Your plan begins only after activation.'
                                : 'Confirm your email. Your plan begins only after activation.',
                            style: const TextStyle(color: EntryColors.muted),
                          ),
                          if (awaitingConfirmation)
                            TextButton(
                              onPressed: () => Navigator.of(context).push(
                                CupertinoPageRoute<void>(
                                  builder: (_) => const OwnerSignInScreen(),
                                ),
                              ),
                              child: const Text('Already confirmed? Sign in'),
                            ),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(23, 8, 23, 20),
                    child: EntryActionButton(
                      label: step == 4
                          ? awaitingConfirmation
                                ? phoneIdentity
                                      ? 'Verify phone'
                                      : 'I’ve confirmed my email'
                                : 'Request activation'
                          : step == 2 &&
                                (category.previewOnly || useCase == 'personal')
                          ? 'Explore Preview'
                          : 'Continue',
                      loading: busy,
                      onPressed: step == 4 ? _submit : _next,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
