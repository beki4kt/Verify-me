class AppConfigurationException implements Exception {
  const AppConfigurationException(this.problems);

  final List<String> problems;

  @override
  String toString() => 'Invalid CHEKMI configuration: ${problems.join(' ')}';
}

/// Compile-time configuration shared by the customer app and owner console.
///
/// Backend coordinates are always explicit; missing or mixed environments fail
/// before Supabase initializes.
class AppEnvironment {
  AppEnvironment._();

  static const bool _isProductBuild = bool.fromEnvironment('dart.vm.product');
  static const String environmentName = String.fromEnvironment(
    'CHEKMI_ENV',
    defaultValue: _isProductBuild ? 'production' : 'development',
  );

  static const String _configuredApiUrl = String.fromEnvironment(
    'VERIFY_ME_API_URL',
  );
  static const String _configuredVerificationUrl = String.fromEnvironment(
    'CHEKMI_VERIFICATION_URL',
  );
  static bool get usesEdgeVerification =>
      _configuredVerificationUrl.trim().isNotEmpty;
  static String get verificationUrl => usesEdgeVerification
      ? _normalizeUrl(_configuredVerificationUrl)
      : '$apiBaseUrl/verify-and-create';
  static const String _configuredSupabaseUrl = String.fromEnvironment(
    'CHEKMI_SUPABASE_URL',
  );
  static const String _configuredSupabaseKey = String.fromEnvironment(
    'CHEKMI_SUPABASE_PUBLISHABLE_KEY',
  );

  static const String _productionSupabaseHost =
      'lpbdxtzyzlaioggefscc.supabase.co';
  static const Set<String> _productionApiHosts = {
    'chekmi.app.aletcloud.com',
    'chekmi-backend-1.app.aletcloud.com',
  };
  static String get apiBaseUrl {
    final configured = _configuredApiUrl.trim();
    if (configured.isNotEmpty) return _normalizeUrl(configured);
    return '';
  }

  static String get supabaseUrl => _normalizeUrl(_configuredSupabaseUrl);

  static String get supabasePublishableKey => _configuredSupabaseKey.trim();

  static bool get isProduction =>
      environmentName.trim().toLowerCase() == 'production';

  static void validateOrThrow() {
    final problems = validationErrors(
      environment: environmentName,
      apiUrl: apiBaseUrl,
      supabaseUrl: supabaseUrl,
      supabasePublishableKey: supabasePublishableKey,
      apiUrlWasProvided: _configuredApiUrl.trim().isNotEmpty,
      supabaseUrlWasProvided: _configuredSupabaseUrl.trim().isNotEmpty,
      supabaseKeyWasProvided: _configuredSupabaseKey.trim().isNotEmpty,
      verificationUrl: _configuredVerificationUrl,
    );
    if (problems.isNotEmpty) throw AppConfigurationException(problems);
  }

  /// Pure validation entry point used by release tooling and unit tests.
  static List<String> validationErrors({
    required String environment,
    required String apiUrl,
    required String supabaseUrl,
    required String supabasePublishableKey,
    bool apiUrlWasProvided = true,
    bool supabaseUrlWasProvided = true,
    bool supabaseKeyWasProvided = true,
    String verificationUrl = '',
  }) {
    final problems = <String>[];
    final mode = environment.trim().toLowerCase();
    final protectedMode = mode == 'production' || mode == 'staging';
    if (verificationUrl.trim().isNotEmpty) {
      _validateEndpoint(
        value: verificationUrl,
        label: 'CHEKMI_VERIFICATION_URL',
        requireHttps: protectedMode,
        problems: problems,
      );
      final uri = Uri.tryParse(verificationUrl);
      final project = Uri.tryParse(supabaseUrl);
      if (uri?.host != project?.host ||
          uri?.path != '/functions/v1/chekmi-verify') {
        problems.add(
          'CHEKMI_VERIFICATION_URL must use this Supabase project’s chekmi-verify function.',
        );
      }
    }
    if (!const {
      'development',
      'preview',
      'staging',
      'production',
    }.contains(mode)) {
      problems.add(
        'CHEKMI_ENV must be development, preview, staging, or production.',
      );
    }

    final usesDedicatedVerification = verificationUrl.trim().isNotEmpty;
    if (mode != 'preview') {
      if (!apiUrlWasProvided && !usesDedicatedVerification) {
        problems.add('VERIFY_ME_API_URL is required for $mode builds.');
      }
      if (!supabaseUrlWasProvided) {
        problems.add('CHEKMI_SUPABASE_URL is required for $mode builds.');
      }
      if (!supabaseKeyWasProvided) {
        problems.add(
          'CHEKMI_SUPABASE_PUBLISHABLE_KEY is required for $mode builds.',
        );
      }
    }

    if (apiUrlWasProvided || !usesDedicatedVerification) {
      _validateEndpoint(
        value: apiUrl,
        label: 'VERIFY_ME_API_URL',
        requireHttps: protectedMode,
        problems: problems,
        requireApiPath: true,
      );
    }
    _validateEndpoint(
      value: supabaseUrl,
      label: 'CHEKMI_SUPABASE_URL',
      requireHttps: protectedMode,
      problems: problems,
    );

    final projectHost = Uri.tryParse(supabaseUrl)?.host.toLowerCase();
    if (mode == 'production' && projectHost != _productionSupabaseHost) {
      problems.add(
        'Production must use the approved production Supabase project.',
      );
    }
    if (mode != 'production' && projectHost == _productionSupabaseHost) {
      problems.add(
        'Nonproduction builds cannot use the production Supabase project.',
      );
    }
    final apiHost = Uri.tryParse(apiUrl)?.host.toLowerCase();
    if (mode != 'production' && _productionApiHosts.contains(apiHost)) {
      problems.add('Nonproduction builds cannot use the production API host.');
    }

    final key = supabasePublishableKey.trim();
    if (key.isEmpty) {
      problems.add('CHEKMI_SUPABASE_PUBLISHABLE_KEY cannot be empty.');
    } else if (_looksLikePlaceholder(key)) {
      problems.add(
        'CHEKMI_SUPABASE_PUBLISHABLE_KEY still contains a placeholder.',
      );
    }
    return problems;
  }

  static void _validateEndpoint({
    required String value,
    required String label,
    required bool requireHttps,
    required List<String> problems,
    bool requireApiPath = false,
  }) {
    final normalized = _normalizeUrl(value);
    final uri = Uri.tryParse(normalized);
    if (normalized.isEmpty ||
        uri == null ||
        !uri.hasScheme ||
        uri.host.isEmpty) {
      problems.add('$label must be an absolute URL.');
      return;
    }
    if (requireHttps && uri.scheme.toLowerCase() != 'https') {
      problems.add('$label must use HTTPS outside development.');
    } else if (!requireHttps &&
        uri.scheme.toLowerCase() != 'http' &&
        uri.scheme.toLowerCase() != 'https') {
      problems.add('$label must use HTTP or HTTPS.');
    }
    if (uri.host == '0.0.0.0') {
      problems.add('$label cannot use the server bind address 0.0.0.0.');
    }
    if (uri.hasQuery || uri.hasFragment || uri.userInfo.isNotEmpty) {
      problems.add(
        '$label cannot contain credentials, a query, or a fragment.',
      );
    }
    if (requireApiPath && uri.path != '/api' && !uri.path.endsWith('/api')) {
      problems.add('$label must end with /api.');
    }
    if (_looksLikePlaceholder(normalized)) {
      problems.add('$label still contains a placeholder.');
    }
  }

  static bool _looksLikePlaceholder(String value) {
    final normalized = value.toLowerCase();
    return normalized.contains('your-') ||
        normalized.contains('your_') ||
        normalized.contains('change_me') ||
        normalized.contains('replace_me') ||
        normalized.contains('<') ||
        normalized.contains('>');
  }

  static String _normalizeUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.endsWith('/')) return trimmed.substring(0, trimmed.length - 1);
    return trimmed;
  }
}
