class AppConfigurationException implements Exception {
  const AppConfigurationException(this.problems);

  final List<String> problems;

  @override
  String toString() => 'Invalid CHEKMI configuration: ${problems.join(' ')}';
}

/// Compile-time configuration shared by the customer app and owner console.
///
/// Development keeps sensible local defaults. Release builds default to the
/// production environment and require every public endpoint to be supplied
/// explicitly with `--dart-define` or `--dart-define-from-file`.
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
  static const String _configuredSupabaseUrl = String.fromEnvironment(
    'CHEKMI_SUPABASE_URL',
  );
  static const String _configuredSupabaseKey = String.fromEnvironment(
    'CHEKMI_SUPABASE_PUBLISHABLE_KEY',
  );

  static const String _developmentApiUrl = 'http://172.20.10.2:3000/api';
  static const String _developmentSupabaseUrl =
      'https://lpbdxtzyzlaioggefscc.supabase.co';
  static const String _developmentSupabaseKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxwYmR4dHp5emxhaW9nZ2Vmc2NjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIyOTMyMDUsImV4cCI6MjA5Nzg2OTIwNX0.X9d4_FkisQRQXYFhyVJ_-5XSsbkS1VCHMLLybfGfpzs';

  static String get apiBaseUrl => _normalizeUrl(
    _configuredApiUrl.trim().isEmpty ? _developmentApiUrl : _configuredApiUrl,
  );

  static String get supabaseUrl => _normalizeUrl(
    _configuredSupabaseUrl.trim().isEmpty
        ? _developmentSupabaseUrl
        : _configuredSupabaseUrl,
  );

  static String get supabasePublishableKey =>
      _configuredSupabaseKey.trim().isEmpty
      ? _developmentSupabaseKey
      : _configuredSupabaseKey.trim();

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
  }) {
    final problems = <String>[];
    final mode = environment.trim().toLowerCase();
    final protectedMode = mode == 'production' || mode == 'staging';
    if (!const {'development', 'staging', 'production'}.contains(mode)) {
      problems.add('CHEKMI_ENV must be development, staging, or production.');
    }

    if (protectedMode) {
      if (!apiUrlWasProvided) {
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

    _validateEndpoint(
      value: apiUrl,
      label: 'VERIFY_ME_API_URL',
      requireHttps: protectedMode,
      problems: problems,
      requireApiPath: true,
    );
    _validateEndpoint(
      value: supabaseUrl,
      label: 'CHEKMI_SUPABASE_URL',
      requireHttps: true,
      problems: problems,
    );

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
