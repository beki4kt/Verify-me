import 'package:flutter_test/flutter_test.dart';
import 'package:verify_me/core/config/app_environment.dart';

void main() {
  test('Mesob iPhone relay pilot cannot silently use the Edge verifier', () {
    expect(AppEnvironment.isProduction, isTrue);
    expect(AppEnvironment.usesEdgeVerification, isFalse);
    expect(
      AppEnvironment.verificationUrl,
      'https://api.chekmiverifier.com.et/api/verify-and-create',
    );
    expect(
      AppEnvironment.validationErrors(
        environment: AppEnvironment.environmentName,
        apiUrl: AppEnvironment.apiBaseUrl,
        supabaseUrl: AppEnvironment.supabaseUrl,
        supabasePublishableKey: AppEnvironment.supabasePublishableKey,
      ),
      isEmpty,
    );
  }, skip: !const bool.fromEnvironment('CHEKMI_RELAY_PILOT'));

  group('AppEnvironment validation', () {
    test('verification endpoint stays within the configured Supabase project', () {
      List<String> validate(String url) => AppEnvironment.validationErrors(
        environment: 'production',
        apiUrl: 'https://api.chekmi.example/api',
        supabaseUrl: 'https://lpbdxtzyzlaioggefscc.supabase.co',
        supabasePublishableKey: 'sb_publishable_valid_public_client_key',
        verificationUrl: url,
      );
      expect(
        validate(
          'https://lpbdxtzyzlaioggefscc.supabase.co/functions/v1/chekmi-verify',
        ),
        isEmpty,
      );
      expect(
        validate('https://other.supabase.co/functions/v1/chekmi-verify'),
        isNotEmpty,
      );
      expect(
        validate('http://project.supabase.co/functions/v1/chekmi-verify'),
        isNotEmpty,
      );
    });
    test('accepts a complete HTTPS production configuration', () {
      final problems = AppEnvironment.validationErrors(
        environment: 'production',
        apiUrl: 'https://api.chekmi.example/api',
        supabaseUrl: 'https://lpbdxtzyzlaioggefscc.supabase.co',
        supabasePublishableKey: 'sb_publishable_valid_public_client_key',
      );

      expect(problems, isEmpty);
    });

    test('accepts an edge-only production configuration', () {
      final problems = AppEnvironment.validationErrors(
        environment: 'production',
        apiUrl: '',
        supabaseUrl: 'https://lpbdxtzyzlaioggefscc.supabase.co',
        supabasePublishableKey: 'sb_publishable_valid_public_client_key',
        apiUrlWasProvided: false,
        verificationUrl: 'https://lpbdxtzyzlaioggefscc.supabase.co/functions/v1/chekmi-verify',
      );

      expect(problems, isEmpty);
    });

    test('accepts a complete HTTPS staging configuration', () {
      final problems = AppEnvironment.validationErrors(
        environment: 'staging',
        apiUrl: 'https://staging-api.chekmi.example/api',
        supabaseUrl: 'https://staging-project.supabase.co',
        supabasePublishableKey: 'sb_publishable_staging_public_client_key',
      );

      expect(problems, isEmpty);
    });

    test('requires explicit staging values', () {
      final problems = AppEnvironment.validationErrors(
        environment: 'staging',
        apiUrl: 'http://192.168.1.20:3000/api',
        supabaseUrl: 'https://lpbdxtzyzlaioggefscc.supabase.co',
        supabasePublishableKey: 'development-public-key',
        apiUrlWasProvided: false,
        supabaseUrlWasProvided: false,
        supabaseKeyWasProvided: false,
      );

      expect(problems, contains(contains('VERIFY_ME_API_URL is required')));
      expect(problems, contains(contains('must use HTTPS')));
      expect(problems, contains(contains('CHEKMI_SUPABASE_URL is required')));
      expect(
        problems,
        contains(contains('CHEKMI_SUPABASE_PUBLISHABLE_KEY is required')),
      );
    });

    test('requires explicit production values', () {
      final problems = AppEnvironment.validationErrors(
        environment: 'production',
        apiUrl: 'http://172.20.10.4:3000/api',
        supabaseUrl: 'https://lpbdxtzyzlaioggefscc.supabase.co',
        supabasePublishableKey: 'development-public-key',
        apiUrlWasProvided: false,
        supabaseUrlWasProvided: false,
        supabaseKeyWasProvided: false,
      );

      expect(problems, contains(contains('VERIFY_ME_API_URL is required')));
      expect(problems, contains(contains('must use HTTPS')));
      expect(problems, contains(contains('CHEKMI_SUPABASE_URL is required')));
      expect(
        problems,
        contains(contains('CHEKMI_SUPABASE_PUBLISHABLE_KEY is required')),
      );
    });

    test('allows an HTTP LAN API only in development', () {
      final problems = AppEnvironment.validationErrors(
        environment: 'development',
        apiUrl: 'http://192.168.1.20:3000/api',
        supabaseUrl: 'http://127.0.0.1:54321',
        supabasePublishableKey: 'development-public-key',
      );

      expect(problems, isEmpty);
    });

    test('allows a same-project local Edge endpoint in development', () {
      final problems = AppEnvironment.validationErrors(
        environment: 'development',
        apiUrl: 'http://127.0.0.1:3000/api',
        supabaseUrl: 'http://127.0.0.1:54321',
        supabasePublishableKey: 'local-anon-key',
        verificationUrl: 'http://127.0.0.1:54321/functions/v1/chekmi-verify',
      );
      expect(problems, isEmpty);
    });

    test('nonproduction modes reject the production project and API host', () {
      for (final mode in ['development', 'staging', 'preview']) {
        final problems = AppEnvironment.validationErrors(
          environment: mode,
          apiUrl: 'https://chekmi-backend-1.app.aletcloud.com/api',
          supabaseUrl: 'https://lpbdxtzyzlaioggefscc.supabase.co',
          supabasePublishableKey: 'sb_publishable_configuration_only',
        );
        expect(problems, contains(contains('production Supabase project')));
        expect(problems, contains(contains('production API host')));
      }
      final currentHost = AppEnvironment.validationErrors(
        environment: 'staging',
        apiUrl: 'https://chekmi.app.aletcloud.com/api',
        supabaseUrl: 'https://staging-project.supabase.co',
        supabasePublishableKey: 'sb_publishable_configuration_only',
      );
      expect(currentHost, contains(contains('production API host')));
    });

    test('production rejects an alternate Supabase project', () {
      final problems = AppEnvironment.validationErrors(
        environment: 'production',
        apiUrl: 'https://api.chekmi.example/api',
        supabaseUrl: 'https://staging-project.supabase.co',
        supabasePublishableKey: 'sb_publishable_configuration_only',
      );
      expect(problems, contains(contains('approved production Supabase')));
    });

    test('rejects bind addresses and placeholder values', () {
      final problems = AppEnvironment.validationErrors(
        environment: 'development',
        apiUrl: 'http://0.0.0.0:3000/api',
        supabaseUrl: 'https://YOUR_PROJECT.supabase.co',
        supabasePublishableKey: 'CHANGE_ME',
      );

      expect(problems, contains(contains('0.0.0.0')));
      expect(problems, contains(contains('placeholder')));
    });
  });
}
