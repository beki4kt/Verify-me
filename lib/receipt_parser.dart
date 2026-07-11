class ReceiptParser {
  /// Extracts the transaction ID based on banking keywords and bank-specific Regex patterns.
  static String? extractTransactionId(String rawText, String targetBank) {
    if (rawText.isEmpty) return null;

    // 1. Normalize the text (Uppercase, remove all line breaks, collapse extra spaces)
    final normalizedText = rawText.toUpperCase().replaceAll(RegExp(r'\s+'), ' ');

    // 2. Keyword-Based Anchors (Most reliable)
    // Looks for "REF NO", "TRANS ID", etc., and captures the next alphanumeric string
    final keywords = [
      r'REF NO', r'REF', r'TRANSACTION ID', r'TRANS ID', r'TID', 
      r'TXN ID', r'TRX ID', r'ID', r'TRANSACTION NO'
    ];
    
    for (final keyword in keywords) {
      // Matches the keyword, optional colons/dashes/spaces, then captures 6 to 15 alphanumeric chars
      final regex = RegExp('$keyword\\s*[:#-]?\\s*([A-Z0-9]{6,15})');
      final match = regex.firstMatch(normalizedText);
      if (match != null && match.groupCount >= 1) {
        return match.group(1);
      }
    }

    // 3. Bank-Specific Regex Fallbacks (If keywords are unreadable due to bad lighting/crumples)
    final bank = targetBank.toLowerCase();
    
    if (bank.contains('telebirr')) {
      // Telebirr typically uses a 10-12 character alphanumeric string
      final telebirrRegex = RegExp(r'\b[A-Z0-9]{10,12}\b');
      final match = telebirrRegex.firstMatch(normalizedText);
      if (match != null) return match.group(0);
    } 
    else if (bank.contains('cbe')) {
      // CBE often starts with FT followed by numbers, or is a long string of 10-12 digits
      final cbeRegex = RegExp(r'\bFT[0-9]{8,12}\b|\b[0-9]{10,12}\b');
      final match = cbeRegex.firstMatch(normalizedText);
      if (match != null) return match.group(0);
    }
    else if (bank.contains('dashen') || bank.contains('amole')) {
      // Dashen/Amole transaction IDs are generally numeric or alphanumeric
      final dashenRegex = RegExp(r'\b[A-Z0-9]{8,12}\b');
      final match = dashenRegex.firstMatch(normalizedText);
      if (match != null) return match.group(0);
    }

    // 4. The Last Resort / Hail Mary
    // Find the longest alphanumeric string (8-15 characters) that contains BOTH letters and numbers
    final fallbackRegex = RegExp(r'\b[A-Z0-9]{8,15}\b');
    final matches = fallbackRegex.allMatches(normalizedText);
    
    if (matches.isNotEmpty) {
      for (final m in matches) {
        final str = m.group(0)!;
        // Prioritize strings that have a mix of letters and numbers (highly likely to be an ID)
        if (str.contains(RegExp(r'[A-Z]')) && str.contains(RegExp(r'[0-9]'))) {
          return str;
        }
      }
      // If no mixed strings, just return the first long string we found
      return matches.first.group(0);
    }

    // If absolutely nothing matches, return null so the scanner keeps trying
    return null;
  }
}