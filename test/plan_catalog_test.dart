import 'package:flutter_test/flutter_test.dart';
import 'package:verify_me/plan_catalog.dart';

void main() {
  test('Basic pricing matches the approved monthly and quarterly offer', () {
    expect(PlanCatalog.basic.monthlyPriceEtb, 1200);
    expect(PlanCatalog.basic.quarterlyPriceEtb, 3000);
    expect(PlanCatalog.basic.quarterlySavingsEtb, 600);
    expect(PlanCatalog.basic.verificationLimit, 2500);
    expect(PlanCatalog.basic.staffLimit, 1);
  });

  test('Pro owns the premium operational features', () {
    expect(PlanCatalog.pro.hasUnlimitedVerifications, isTrue);
    expect(PlanCatalog.pro.hasUnlimitedStaff, isTrue);
    expect(PlanCatalog.pro.includes(PlanFeature.dailyRevenueReport), isTrue);
    expect(PlanCatalog.basic.includes(PlanFeature.dailyRevenueReport), isFalse);
    expect(PlanCatalog.pro.includes(PlanFeature.cashierWorkspace), isTrue);
    expect(PlanCatalog.pro.includes(PlanFeature.tipPayouts), isTrue);
    expect(PlanCatalog.pro.recommended, isTrue);
  });
}
