import 'package:flutter_test/flutter_test.dart';
import 'package:verify_me/receipt_parser.dart';

void main() {
  group('ReceiptParser', () {
    test('extracts an anchored Telebirr reference', () {
      const text =
          'Payment successful\nTransaction ID: CJU5RZ5NM3\nAmount 250.00 ETB';
      expect(
        ReceiptParser.extractTransactionId(text, 'Telebirr'),
        'CJU5RZ5NM3',
      );
    });

    test('extracts a CBE FT reference split by OCR spacing', () {
      const text =
          'Commercial Bank of Ethiopia\nReference No: FT25 301XQ1W1\nAccount 1000123456789';
      expect(ReceiptParser.extractTransactionId(text, 'CBE'), 'FT25301XQ1W1');
    });

    test('extracts an Abyssinia reference from provider format', () {
      const text = 'Transfer completed FT252195GT6N amount 1000 ETB';
      expect(
        ReceiptParser.extractTransactionId(text, 'Abyssinia'),
        'FT252195GT6N',
      );
    });

    test('extracts an M-Pesa receipt number', () {
      const text = 'M-PESA\nReceipt No. SCW4GOZXQZDJ\nCompleted';
      expect(ReceiptParser.extractTransactionId(text, 'MPesa'), 'SCW4GOZXQZDJ');
    });

    test('does not return an amount, date, or phone number', () {
      const text = 'Amount 1200.00 ETB\nDate 05/08/2026\nPhone +251911223344';
      expect(ReceiptParser.extractTransactionId(text, 'Telebirr'), isNull);
    });
  });
}
