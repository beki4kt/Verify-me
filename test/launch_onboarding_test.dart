import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verify_me/business_registration_screen.dart';
import 'package:verify_me/launch_experience.dart';

void main() {
  testWidgets('welcome offers distinct registration, connection and preview', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Connect to Existing Workspace'), findsOneWidget);
    expect(find.text('Explore Preview'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    expect(find.byType(BusinessRegistrationScreen), findsOneWidget);
    expect(find.text('Shop / Retail'), findsOneWidget);
  });

  testWidgets(
    'registration carries preset into workflow and real plan choice',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(home: BusinessRegistrationScreen()),
      );
      await tester.tap(find.text('Services'));
      await tester.scrollUntilVisible(find.text('Continue'), 180);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Make payments work your way.'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Track payments against'), 180);
      await tester.pumpAndSettle();
      expect(find.text('Invoice'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Me and My Team'), 180);
      await tester.tap(find.text('Me and My Team'));
      await tester.scrollUntilVisible(find.text('Continue'), 180);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Choose your plan.'), findsOneWidget);
      expect(find.textContaining('1200 ETB'), findsOneWidget);
      expect(
        find.textContaining('Price arranged during activation'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
