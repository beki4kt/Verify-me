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
  /// Parses raw OCR text to extract transaction specifics
  static ParsedReceipt parse(String rawText) {
    String? txId;
    double? amount;
    String? date;

    // 1. Match Transaction IDs (Supports common alphanumeric formats like CC1234567, TXN98765, etc.)
    final txRegex = RegExp(r'\b[A-Z0-9]{10,12}\b|\b[A-Z]{2}\d{8,10}\b', caseSensitive: false);
    final txMatch = txRegex.firstMatch(rawText);
    if (txMatch != null) {
      txId = txMatch.group(0)?.toUpperCase();
    }

    // 2. Match Amounts (Looks for numbers following words like "Amount", "ETB", "Paid", or pure currency formats)
    final amountRegex = RegExp(r'(?:amount|etb|paid|sum)[:\s]*([\d,]+\.\d{2})', caseSensitive: false);
    final amountMatch = amountRegex.firstMatch(rawText);
    if (amountMatch != null) {
      final cleanAmountStr = amountMatch.group(1)?.replaceAll(',', '');
      amount = double.tryParse(cleanAmountStr ?? '');
    } else {
      // Fallback: look for any decimal number matching standard financial formats xx.xx
      final generalAmountRegex = RegExp(r'\b\d+[\.,]\d{2}\b');
      final matches = generalAmountRegex.allMatches(rawText);
      if (matches.isNotEmpty) {
        final cleanAmountStr = matches.first.group(0)?.replaceAll(',', '');
        amount = double.tryParse(cleanAmountStr ?? '');
      }
    }

    // 3. Match Dates (Supports DD/MM/YYYY, YYYY-MM-DD, or text months)
    final dateRegex = RegExp(r'\b\d{2}[-/.\s]\d{2}[-/.\s]\d{4}\b|\b\d{4}[-/.\s]\d{2}[-/.\s]\d{2}\b');
    final dateMatch = dateRegex.firstMatch(rawText);
    if (dateMatch != null) {
      date = dateMatch.group(0);
    }

    // Validation Check: A receipt must have at least a recognizable Transaction ID and Amount to be considered real
    bool isValid = (txId != null && amount != null);

    return ParsedReceipt(
      transactionId: txId,
      amount: amount,
      date: date,
      isValid: isValid,
    );
  }
}