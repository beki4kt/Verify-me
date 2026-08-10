class ReceiptParser {
  static const _labels = <String>[
    r'TRANSACTION\s*(?:ID|NO|NUMBER|REF(?:ERENCE)?)',
    r'TRANS?\s*(?:ID|NO)',
    r'TXN\s*(?:ID|NO|REF)',
    r'TRX\s*(?:ID|NO|REF)',
    r'RECEIPT\s*(?:ID|NO|NUMBER)',
    r'REFERENCE\s*(?:ID|NO|NUMBER)?',
    r'REF\s*(?:ID|NO|NUMBER)?',
  ];

  static String? extractTransactionId(String rawText, String targetBank) {
    if (rawText.trim().isEmpty) return null;
    final text = rawText
        .toUpperCase()
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'[‐‑‒–—]'), '-')
        .replaceAll('|', 'I');
    final bank = targetBank.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

    for (final line in text.split('\n')) {
      final normalizedLine = line.replaceAll(RegExp(r'\s+'), ' ').trim();
      for (final label in _labels) {
        final match = RegExp(
          '$label\\s*[:#.=-]?\\s*([A-Z0-9][A-Z0-9 \\-]{5,31})',
        ).firstMatch(normalizedLine);
        if (match != null) {
          final candidate = _clean(match.group(1)!);
          if (_validForProvider(candidate, bank, anchored: true)) {
            return candidate;
          }
        }
      }
    }

    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    for (var i = 0; i < lines.length - 1; i++) {
      if (_labels.any(
        (label) => RegExp('^$label\\s*[:#.=-]?\\s*\$').hasMatch(lines[i]),
      )) {
        final candidate = _clean(lines[i + 1]);
        if (_validForProvider(candidate, bank, anchored: true)) {
          return candidate;
        }
      }
    }

    final compact = text.replaceAll(RegExp(r'[^A-Z0-9]+'), ' ');
    for (final pattern in _providerPatterns(bank)) {
      for (final match in pattern.allMatches(compact)) {
        final candidate = _clean(match.group(0)!);
        if (_validForProvider(candidate, bank, anchored: false)) {
          return candidate;
        }
      }
    }
    for (final match in RegExp(r'\b[A-Z0-9]{8,16}\b').allMatches(compact)) {
      final candidate = match.group(0)!;
      if (_validForProvider(candidate, bank, anchored: false)) return candidate;
    }
    return null;
  }

  static String _clean(String value) => value
      .replaceAll(RegExp(r'[^A-Z0-9]'), '')
      .replaceAll(RegExp(r'^(?:NO|NUMBER)'), '');

  static List<RegExp> _providerPatterns(String bank) {
    if (bank.contains('cbe') || bank.contains('abyssinia')) {
      return [RegExp(r'\bFT[A-Z0-9]{9,14}\b')];
    }
    if (bank.contains('telebirr')) {
      return [RegExp(r'\b[A-Z]{2,4}[A-Z0-9]{6,10}\b')];
    }
    if (bank.contains('mpesa')) {
      return [RegExp(r'\b[A-Z]{2,4}[A-Z0-9]{8,12}\b')];
    }
    return [
      RegExp(r'\bFT[A-Z0-9]{9,14}\b'),
      RegExp(r'\b[A-Z]{2,4}[A-Z0-9]{6,12}\b'),
    ];
  }

  static bool _validForProvider(
    String value,
    String bank, {
    required bool anchored,
  }) {
    if (value.length < 8 || value.length > 18) return false;
    if (!value.contains(RegExp(r'[A-Z]')) || !value.contains(RegExp(r'\d'))) {
      return false;
    }
    if (RegExp(r'^(?:251|09)\d+$').hasMatch(value)) return false;
    if ((bank.contains('cbe') || bank.contains('abyssinia')) &&
        !value.startsWith('FT')) {
      return anchored && value.length >= 10;
    }
    return true;
  }
}
