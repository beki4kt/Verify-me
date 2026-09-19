import 'package:flutter_test/flutter_test.dart';
import 'package:verify_me/support_privacy_screen.dart';

void main() {
  test('restores only acceptances for the displayed legal version', () {
    final accepted = acceptedLegalDocumentTypes(const [
      {'document_type': 'privacy', 'document_version': '2026-09-10'},
      {'document_type': 'terms', 'document_version': '2026-08-12'},
    ], version: '2026-09-10');

    expect(accepted, {'privacy'});
  });
}
