import 'package:flutter_test/flutter_test.dart';
import 'package:verify_me/core/config/app_environment.dart';

void main() {
  group('AppEnvironment validation', () {
    test('accepts a complete HTTPS production configuration', () {
      final problems = AppEnvironment.validationErrors(
        environment: 'production',
        apiUrl: 'https://api.chekmi.example/api',
        supabaseUrl: 'https://project.supabase.co',
        supabasePublishableKey: 'sb_publishable_valid_public_client_key',
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
        supabaseUrl: 'https://project.supabase.co',
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
        supabaseUrl: 'https://project.supabase.co',
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
        supabaseUrl: 'https://project.supabase.co',
        supabasePublishableKey: 'development-public-key',
      );

      expect(problems, isEmpty);
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
