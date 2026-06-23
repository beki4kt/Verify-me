class ParsedReceipt {
  final String? transactionId;
  final String? detectedBankName;
  final String? endpoint;
  final bool isValid;

  ParsedReceipt({
    this.transactionId,
    this.detectedBankName,
    this.endpoint,
    required this.isValid,
  });
}

class ReceiptParser {
  static ParsedReceipt parse(String rawText) {
    String? txId;
    String detectedBank = 'Telebirr'; // Default fallback
    String endpoint = '/verify-telebirr'; 

    final textLower = rawText.toLowerCase();

    // 1. Auto-Detect the Bank based on Keywords
    if (textLower.contains('commercial bank') || textLower.contains('cbe') && !textLower.contains('birr')) {
      detectedBank = 'CBE (Mobile Banking)';
      endpoint = '/verify-cbe';
    } else if (textLower.contains('cbebirr') || textLower.contains('cbe birr')) {
      detectedBank = 'CBE Birr';
      endpoint = '/verify-cbebirr';
    } else if (textLower.contains('dashen') || textLower.contains('amole')) {
      detectedBank = 'Dashen';
      endpoint = '/verify-dashen';
    } else if (textLower.contains('abyssinia') || textLower.contains('boa')) {
      detectedBank = 'Bank of Abyssinia';
      endpoint = '/verify-abyssinia';
    } else if (textLower.contains('m-pesa') || textLower.contains('mpesa') || textLower.contains('safaricom')) {
      detectedBank = 'M-Pesa';
      endpoint = '/verify-mpesa';
    } else if (textLower.contains('telebirr')) {
      detectedBank = 'Telebirr';
      endpoint = '/verify-telebirr';
    }

    // 2. Extract Transaction ID
    // Broadened to 8-16 characters since different banks use different ID lengths (e.g., CBE uses FT...)
    final txRegex = RegExp(r'\b[A-Z0-9]{8,16}\b', caseSensitive: false);
    final matches = txRegex.allMatches(rawText);
    
    for (final match in matches) {
      String candidate = match.group(0)!.toUpperCase();
      
      // Filter out common receipt words that happen to be the same length as IDs
      List<String> ignoreWords = [
        'TRANSACTION', 'SUCCESSFUL', 'COMPLETED', 'TRANSFER', 'REFERENCE', 
        'COMMERCIAL', 'TELEBIRR', 'ABYSSINIA', 'DASHEN'
      ];
      if (ignoreWords.contains(candidate)) continue;

      // An ID MUST contain at least one number (prevents grabbing pure text words)
      if (RegExp(r'\d').hasMatch(candidate)) {
        txId = candidate;
        break; 
      }
    }

    return ParsedReceipt(
      transactionId: txId,
      detectedBankName: detectedBank,
      endpoint: endpoint,
      isValid: txId != null,
    );
  }
}