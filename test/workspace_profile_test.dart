import 'package:flutter_test/flutter_test.dart';
import 'package:verify_me/core/models/workspace_profile.dart';

void main() {
  test('server capabilities determine actions independently of use case', () {
    final profile = WorkspaceProfile.fromJson({
      'use_case': 'shop',
      'default_reference_kind': 'order',
      'review_policy': 'review_required',
      'tips_enabled': false,
      'overpayment_policy': 'unresolved',
      'capabilities': {
        'verify_payment': true,
        'review_payment': false,
        'view_ledger': true,
      },
    });
    expect(profile.can('verify_payment'), isTrue);
    expect(profile.can('review_payment'), isFalse);
    expect(profile.can('view_ledger'), isTrue);
    expect(profile.requiresReview, isTrue);
    expect(profile.isRestaurant, isFalse);
  });
}
