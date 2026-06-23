class ParsedReceipt {
  final String? transactionId;
  final double? amount;
  final String? date;
  final bool isValid;

  ParsedReceipt({
    this.transactionId,
    this.amount,
    this.date,
    required this.isValid,
  });
}

class ReceiptParser {
  static ParsedReceipt parse(String rawText) {
    String? txId;
    
    // Telebirr IDs are generally 10 alphanumeric characters
    final txRegex = RegExp(r'\b[A-Z0-9]{10}\b', caseSensitive: false);
    final matches = txRegex.allMatches(rawText);
    
    for (final match in matches) {
      String candidate = match.group(0)!.toUpperCase();
      
      // Filter out words that happen to be exactly 10 letters long
      List<String> ignoreWords = ['TRANSACTION', 'SUCCESSFUL', 'COMPLETED'];
      if (ignoreWords.contains(candidate)) continue;

      // An ID MUST contain at least one number (prevents grabbing random words)
      if (RegExp(r'\d').hasMatch(candidate)) {
        txId = candidate;
        break; 
      }
    }

    return ParsedReceipt(
      transactionId: txId,
      isValid: txId != null,
    );
  }
}