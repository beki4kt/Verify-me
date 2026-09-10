import 'package:flutter/foundation.dart';

import 'app_environment.dart';

/// Compile-time product switches used by installable review builds.
///
/// Product presentation switches shared by installable and preview builds.
abstract final class AppVariant {
  static const bool isTest2 = bool.fromEnvironment('CHEKMI_TEST2');
  static const bool forceIPhoneUi = bool.fromEnvironment('CHEKMI_IPHONE_UI');
  static const bool isUiPreview = bool.fromEnvironment('CHEKMI_UI_PREVIEW');
  static const bool webCameraTest = bool.fromEnvironment(
    'CHEKMI_WEB_CAMERA_TEST',
  );
  static const bool usesMinimalCopy = bool.fromEnvironment(
    'CHEKMI_MINIMAL_UI',
    defaultValue: true,
  );

  /// Public store builds are organization-only clients. Platform operations,
  /// plan sales, and providers that have not passed live acceptance stay out
  /// of the customer binary while remaining available in development.
  static bool get isPublicRelease => AppEnvironment.isProduction && !isTest2;
  static bool get exposesOperatorConsole => !isPublicRelease;
  static bool get showsPlanMarketing => !isPublicRelease;

  static const allPaymentProviders = <({String id, String label})>[
    (id: 'telebirr', label: 'Telebirr'),
    (id: 'cbe', label: 'CBE'),
    (id: 'cbebirr', label: 'CBE Birr'),
    (id: 'dashen', label: 'Dashen'),
    (id: 'abyssinia', label: 'Abyssinia'),
    (id: 'mpesa', label: 'M-Pesa'),
  ];

  static List<({String id, String label})> get enabledPaymentProviders =>
      isPublicRelease
      ? allPaymentProviders.take(1).toList()
      : allPaymentProviders;

  static bool isPaymentProviderEnabled(String provider) {
    if (!isPublicRelease) return true;
    final normalized = provider.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    return normalized == 'telebirr';
  }

  /// Uses the native-feeling iPhone presentation on iOS, while allowing the
  /// same presentation to be reviewed in a desktop browser during development.
  static bool get usesIPhoneUi =>
      forceIPhoneUi || (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS);

  static const String buildLabel = isTest2 ? 'TEST 2' : '';
}
