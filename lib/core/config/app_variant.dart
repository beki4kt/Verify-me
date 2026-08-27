/// Compile-time product switches used by installable review builds.
///
/// Test 2 keeps production behaviour intact while presenting a shorter,
/// icon-led interface for visual review.
abstract final class AppVariant {
  static const bool isTest2 = bool.fromEnvironment('CHEKMI_TEST2');
  static const bool usesMinimalCopy = bool.fromEnvironment(
    'CHEKMI_MINIMAL_UI',
    defaultValue: isTest2,
  );

  static const String buildLabel = isTest2 ? 'TEST 2' : '';
}
