import 'package:flutter_test/flutter_test.dart';
import 'package:verify_me/core/models/ethiopian_phone.dart';

void main() {
  test('formats both supported Ethiopian mobile prefixes', () {
    expect(formatEthiopianPhone('9', '12345678'), '+251912345678');
    expect(formatEthiopianPhone('7', '12345678'), '+251712345678');
  });

  test('splits stored Ethiopian phone numbers for staff editing', () {
    expect(splitEthiopianPhone('+251712345678'), (
      prefix: '7',
      subscriber: '12345678',
    ));
    expect(splitEthiopianPhone('+251912345678'), (
      prefix: '9',
      subscriber: '12345678',
    ));
  });

  test('rejects unsupported prefixes and invalid subscriber lengths', () {
    expect(() => formatEthiopianPhone('8', '12345678'), throwsFormatException);
    expect(() => formatEthiopianPhone('9', '1234'), throwsFormatException);
  });
}
