class ParsedReceipt {
  final String? transactionId;
  final String detectedBankName;
  final String? endpoint;
  final bool isValid;
  final String? amount;

  ParsedReceipt({
    this.transactionId,
    required this.detectedBankName,
    this.endpoint,
    required this.isValid,
    this.amount,
  });
}

class ReceiptParser {
  static ParsedReceipt parse(String text, String targetBank, String targetEndpoint) {
    String upperText = text.toUpperCase();
    String? id;
    
    // 1. TELEBIRR TARGETING
    if (targetBank == 'Telebirr') {
      // Telebirr IDs are typically 10 alphanumeric characters (e.g., 7A43B2C9X1)
      RegExp regExp = RegExp(r'\b[A-Z0-9]{10}\b');
      var match = regExp.firstMatch(upperText);
      if (match != null) id = match.group(0);
    } 
    // 2. CBE / CBE BIRR TARGETING
    else if (targetBank == 'CBE' || targetBank == 'CBE Birr') {
      // CBE Mobile Banking often starts with FT followed by numbers
      RegExp ftRegExp = RegExp(r'\bFT\d{8,14}\b');
      var ftMatch = ftRegExp.firstMatch(upperText);
      
      if (ftMatch != null) {
        id = ftMatch.group(0);
      } else {
        // Fallback for purely numeric CBE reference numbers
        RegExp numRegExp = RegExp(r'\b\d{10,14}\b');
        var numMatch = numRegExp.firstMatch(upperText);
        if (numMatch != null) id = numMatch.group(0);
      }
    } 
    // 3. DASHEN TARGETING
    else if (targetBank == 'Dashen') {
      // Dashen formats vary but are usually 9-12 alphanumeric
      RegExp regExp = RegExp(r'\b[A-Z0-9]{9,12}\b');
      var match = regExp.firstMatch(upperText);
      if (match != null) id = match.group(0);
    } 
    // 4. M-PESA TARGETING
    else if (targetBank == 'M-Pesa') {
      // Safaricom M-Pesa standard ID format (usually 10 chars starting with letters)
      RegExp regExp = RegExp(r'\b[A-Z0-9]{10}\b');
      var match = regExp.firstMatch(upperText);
      if (match != null) id = match.group(0);
    }
    // 5. UNIVERSAL FALLBACK
    else {
      RegExp regExp = RegExp(r'\b[A-Z0-9]{8,15}\b');
      var match = regExp.firstMatch(upperText);
      if (match != null) id = match.group(0);
    }

    return ParsedReceipt(
      transactionId: id,
      detectedBankName: targetBank,
      endpoint: targetEndpoint,
      isValid: id != null,
    );
  }
}