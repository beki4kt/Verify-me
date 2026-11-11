typedef EthiopianPhoneParts = ({String prefix, String subscriber});

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
