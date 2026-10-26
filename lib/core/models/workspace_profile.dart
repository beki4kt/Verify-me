/// Server-provided workflow and permissions. Industry is presentation only;
/// capability checks remain authoritative in database RPCs.
class WorkspaceProfile {
  const WorkspaceProfile({
    required this.useCase,
    required this.defaultReferenceKind,
    required this.reviewPolicy,
    required this.tipsEnabled,
    required this.overpaymentPolicy,
    required this.capabilities,
  });

  final String useCase;
  final String defaultReferenceKind;
  final String reviewPolicy;
  final bool tipsEnabled;
  final String overpaymentPolicy;
  final Set<String> capabilities;

  bool can(String capability) => capabilities.contains(capability);
  bool get requiresReview => reviewPolicy == 'review_required';
  bool get isRestaurant => useCase == 'restaurant';

  factory WorkspaceProfile.fromJson(Map<String, dynamic> json) {
    final rawCapabilities = json['capabilities'];
    final capabilityMap = rawCapabilities is Map
        ? Map<String, dynamic>.from(rawCapabilities)
        : const <String, dynamic>{};
    return WorkspaceProfile(
      useCase: json['use_case']?.toString() ?? 'general',
      defaultReferenceKind:
          json['default_reference_kind']?.toString() ?? 'none',
      reviewPolicy: json['review_policy']?.toString() ?? 'automatic',
      tipsEnabled: json['tips_enabled'] == true,
      overpaymentPolicy: json['overpayment_policy']?.toString() ?? 'unresolved',
      capabilities: capabilityMap.entries
          .where((entry) => entry.value == true)
          .map((entry) => entry.key)
          .toSet(),
    );
  }
}
