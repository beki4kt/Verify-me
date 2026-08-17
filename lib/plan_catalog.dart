enum BillingPeriod { monthly, quarterly }

enum PlanFeature {
  paymentVerification,
  receiptScanning,
  liveTicketQueue,
  transactionHistory,
  dailyRevenueReport,
  advancedFilters,
  bankAnalytics,
  cashierWorkspace,
  tipPayouts,
  receiptEvidence,
  multiDevice,
  prioritySupport,
}

class PlanDefinition {
  const PlanDefinition({
    required this.id,
    required this.name,
    required this.tagline,
    required this.verificationLimit,
    required this.staffLimit,
    required this.monthlyPriceEtb,
    required this.quarterlyPriceEtb,
    required this.features,
    this.recommended = false,
  });

  final String id;
  final String name;
  final String tagline;
  final int? verificationLimit;
  final int? staffLimit;
  final int? monthlyPriceEtb;
  final int? quarterlyPriceEtb;
  final Set<PlanFeature> features;
  final bool recommended;

  bool get hasUnlimitedVerifications => verificationLimit == null;
  bool get hasUnlimitedStaff => staffLimit == null;
  bool includes(PlanFeature feature) => features.contains(feature);

  int? priceFor(BillingPeriod period) => switch (period) {
    BillingPeriod.monthly => monthlyPriceEtb,
    BillingPeriod.quarterly => quarterlyPriceEtb,
  };

  int? get quarterlySavingsEtb {
    final monthly = monthlyPriceEtb;
    final quarterly = quarterlyPriceEtb;
    if (monthly == null || quarterly == null) return null;
    return (monthly * 3) - quarterly;
  }
}

class PlanCatalog {
  PlanCatalog._();

  static const basic = PlanDefinition(
    id: 'basic',
    name: 'Basic',
    tagline: 'Everything a small restaurant needs to verify payments safely.',
    verificationLimit: 2500,
    staffLimit: 1,
    monthlyPriceEtb: 1200,
    quarterlyPriceEtb: 3000,
    features: {
      PlanFeature.paymentVerification,
      PlanFeature.receiptScanning,
      PlanFeature.liveTicketQueue,
      PlanFeature.transactionHistory,
    },
  );

  static const pro = PlanDefinition(
    id: 'pro',
    name: 'Pro',
    tagline: 'Full financial visibility and team control for growing service.',
    verificationLimit: null,
    staffLimit: null,
    monthlyPriceEtb: null,
    quarterlyPriceEtb: null,
    recommended: true,
    features: {
      PlanFeature.paymentVerification,
      PlanFeature.receiptScanning,
      PlanFeature.liveTicketQueue,
      PlanFeature.transactionHistory,
      PlanFeature.dailyRevenueReport,
      PlanFeature.advancedFilters,
      PlanFeature.bankAnalytics,
      PlanFeature.cashierWorkspace,
      PlanFeature.tipPayouts,
      PlanFeature.receiptEvidence,
      PlanFeature.multiDevice,
      PlanFeature.prioritySupport,
    },
  );

  static const all = [basic, pro];

  static PlanDefinition fromTier(String? tier) {
    return tier?.trim().toLowerCase() == pro.id ? pro : basic;
  }
}
