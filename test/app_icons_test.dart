import 'package:flutter_test/flutter_test.dart';
import 'package:verify_me/core/theme/app_icons.dart';

void main() {
  test('CHEKMI semantic icons use the Lucide outline font', () {
    const representativeIcons = [
      AppIcons.dashboard,
      AppIcons.receipt,
      AppIcons.scanReceipt,
      AppIcons.money,
      AppIcons.team,
      AppIcons.settings,
      AppIcons.success,
      AppIcons.warning,
    ];

    for (final icon in representativeIcons) {
      expect(icon.fontPackage, 'flutter_lucide');
      expect(icon.fontFamily, 'lucide');
    }
  });

  test('primary navigation meanings have distinct glyphs', () {
    expect({
      AppIcons.dashboard.codePoint,
      AppIcons.receipt.codePoint,
      AppIcons.team.codePoint,
      AppIcons.settings.codePoint,
    }, hasLength(4));
  });
}
