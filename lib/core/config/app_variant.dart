import 'package:flutter/foundation.dart';

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

  /// Uses the native-feeling iPhone presentation on iOS, while allowing the
  /// same presentation to be reviewed in a desktop browser during development.
  static bool get usesIPhoneUi =>
      forceIPhoneUi || (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS);

  static const String buildLabel = isTest2 ? 'TEST 2' : '';
}
