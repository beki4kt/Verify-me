import 'package:flutter_test/flutter_test.dart';
import 'package:verify_me/core/config/app_environment.dart';
import 'package:verify_me/core/config/app_variant.dart';

void main() {
  test(
    'public production build exposes only contracted release capabilities',
    () {
      expect(AppVariant.isPublicRelease, isTrue);
      expect(AppVariant.exposesOperatorConsole, isFalse);
      expect(AppVariant.showsPlanMarketing, isFalse);
      expect(AppVariant.enabledPaymentProviders, const [
        (id: 'telebirr', label: 'Telebirr'),
      ]);
      expect(AppVariant.isPaymentProviderEnabled('Telebirr'), isTrue);
      expect(AppVariant.isPaymentProviderEnabled('CBE'), isFalse);
    },
    skip: !AppEnvironment.isProduction,
  );
}
