import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verify_me/business_registration_screen.dart';
import 'package:verify_me/launch_experience.dart';
import 'package:verify_me/iphone/interactive_preview_screen.dart';

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
    expect(find.text('Connect Workspace'), findsOneWidget);
    expect(find.text('Explore Preview'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    expect(find.byType(BusinessRegistrationScreen), findsOneWidget);
    expect(find.text('Choose your business'), findsOneWidget);
    expect(find.text('Shop & Retail'), findsOneWidget);
    expect(find.text('Events & Venues'), findsOneWidget);
  });

  testWidgets('workspace connection asks only for a code before staff login', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: WorkspaceConnectScreen()));
    expect(find.text('Workspace code'), findsWidgets);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Password'), findsNothing);
    expect(find.text('Email address'), findsNothing);
    expect(find.text('Business owner sign in'), findsOneWidget);
  });

  testWidgets('owner login starts with phone and retains email access', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: OwnerSignInScreen()));
    expect(find.text('Phone number'), findsOneWidget);
    expect(find.text('Owner email'), findsNothing);
    await tester.ensureVisible(find.text('Use email to sign in'));
    await tester.tap(find.text('Use email to sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Owner email'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('subtype and workflow lead to the real plan choice', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: BusinessRegistrationScreen()),
    );
    await tester.tap(find.text('Services & Professionals'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('What service do you offer?'), findsOneWidget);
    await tester.tap(find.text('Salon / Beauty'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('How do you take payments?'), findsOneWidget);
    await tester.tap(find.text('Walk-ins'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Track by'), 100);
    await tester.pumpAndSettle();
    expect(find.text('Customer'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Choose your plan'), findsOneWidget);
    expect(find.textContaining('1200 ETB'), findsOneWidget);
    expect(find.textContaining('Price arranged at activation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('event preview shows a truthful pending sample', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: InteractivePreviewScreen(events: true)),
    );
    expect(find.text('Event payments'), findsOneWidget);
    expect(find.textContaining('No bank check'), findsOneWidget);
    await tester.ensureVisible(find.text('Receipt reference').first);
    await tester.enterText(find.byType(TextField).at(1), 'TXN-208');
    await tester.ensureVisible(find.text('Expected amount').first);
    await tester.enterText(find.byType(TextField).at(2), '250');
    await tester.ensureVisible(find.text('Pending'));
    await tester.tap(find.text('Pending'));
    await tester.ensureVisible(find.text('Show sample result'));
    await tester.tap(find.text('Show sample result'));
    await tester.pumpAndSettle();
    expect(find.text('Payment Pending'), findsOneWidget);
    expect(find.text('No payment is counted or completed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
