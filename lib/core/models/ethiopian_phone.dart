typedef EthiopianPhoneParts = ({String prefix, String subscriber});

/// Converts Ethiopian mobile numbers to Supabase Auth's E.164 form.
/// A local number, 251 prefix, or +251 prefix are accepted; other countries
/// are rejected until the business rules and SMS provider support them.
String normalizeEthiopianPhone(String value) {
  final compact = value.replaceAll(RegExp(r'[\s()\-]'), '');
  final candidate = compact.startsWith('+251')
      ? compact
      : compact.startsWith('251')
      ? '+$compact'
      : compact.startsWith('0')
      ? '+251${compact.substring(1)}'
      : '+251$compact';
  if (!RegExp(r'^\+251[79]\d{8}$').hasMatch(candidate)) {
    throw const FormatException('Enter a valid Ethiopian mobile number.');
  }
  return candidate;
}

EthiopianPhoneParts splitEthiopianPhone(String value) {
  final normalized = value.replaceAll(RegExp(r'\s'), '');
  final match = RegExp(r'^\+251([79])(\d{8})$').firstMatch(normalized);
  if (match != null) {
    return (prefix: match.group(1)!, subscriber: match.group(2)!);
  }
  return (prefix: '9', subscriber: normalized.replaceFirst('+2519', ''));
}

String formatEthiopianPhone(String prefix, String subscriber) {
  final digits = subscriber.replaceAll(RegExp(r'\s'), '');
  if (!const {'7', '9'}.contains(prefix) ||
      !RegExp(r'^\d{8}$').hasMatch(digits)) {
    throw const FormatException('Enter a valid Ethiopian phone number.');
  }
  return '+251$prefix$digits';
}
