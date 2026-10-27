import 'package:flutter_test/flutter_test.dart';
import 'package:verify_me/core/models/workspace_code.dart';

void main() {
  test('normalizes a generated workspace code', () {
    expect(WorkspaceCode.normalize(' ck-a0b1c2d3e4 '), 'CK-A0B1C2D3E4');
  });

  test('rejects malformed and unbounded lookup input', () {
    expect(WorkspaceCode.normalize(' mesob-demo '), 'MESOB-DEMO');
    for (final input in [
      '',
      'CK',
      'CK_123',
      'CK-123456789Z?',
      'CK-1234567890\nCK-1111111111',
      'x' * 200,
    ]) {
      expect(WorkspaceCode.normalize(input), isNull, reason: input);
    }
  });
}
