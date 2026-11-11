import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verify_me/core/config/app_variant.dart';
import 'package:verify_me/iphone/entry_auth_flow.dart';

void main() {
  if (!AppVariant.isUiPreview) return;

  testWidgets('offline code entry shows staff login without authenticating', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: WorkspaceConnectScreen()));
    await tester.enterText(find.byType(TextField).first, 'mesob-demo');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.byType(StaffSignInPreviewScreen), findsOneWidget);
    expect(find.text('MESOB-DEMO'), findsOneWidget);
    expect(find.textContaining('No lookup performed'), findsOneWidget);
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No membership was checked'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
