import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:verify_me/core/services/demo_verification_client.dart';
import 'package:verify_me/core/theme/app_theme.dart';
import 'package:verify_me/core/theme/theme_controller.dart';
import 'package:verify_me/localization_service.dart';
import 'package:verify_me/staff_login_screen.dart';
import 'package:verify_me/trial_mode_screen.dart';
import 'package:verify_me/waiter_dashboard.dart';

void main() {
  Future<void> show(
    WidgetTester tester,
    Widget home, {
    bool reducedMotion = false,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeController()),
          ChangeNotifierProvider(create: (_) => LocalizationService()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(iPhone: true),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(disableAnimations: reducedMotion),
            child: child!,
          ),
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'connected login supports keyboard, password visibility and reduced motion',
    (tester) async {
      await show(tester, const StaffLoginScreen(), reducedMotion: true);
      expect(find.text('WORKSPACE CONNECTED'), findsOneWidget);
      expect(find.text('Your team.\nReady for business.'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const Key('iphone-staff-password')),
      );
      await tester.tap(find.byTooltip('Show password'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('iphone-staff-password')))
            .obscureText,
        false,
      );
      await tester.tap(find.byKey(const Key('iphone-staff-sign-in')));
      await tester.pumpAndSettle();
      expect(
        find.text('Enter your phone number and password.'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'demo opens a provider directly and respects zero remaining checks',
    (tester) async {
      final client = DemoVerificationClient(
        token: () async => 'a' * 64,
        client: MockClient(
          (_) async => http.Response('{"demo":true,"remaining":0}', 200),
        ),
      );
      await show(tester, TrialModeScreen(client: client, manualOnly: true));
      expect(find.text('0 of 10 free checks remaining'), findsOneWidget);
      await tester.ensureVisible(find.text('Telebirr'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Telebirr'));
      await tester.pumpAndSettle();
      expect(find.text('Telebirr demo'), findsNothing);
      expect(find.byType(WaiterDashboard), findsNothing);
      client.close();
    },
  );
  testWidgets('demo method goes to demo reference entry without staff login', (
    tester,
  ) async {
    final client = DemoVerificationClient(
      token: () async => 'a' * 64,
      client: MockClient(
        (_) async => http.Response('{"demo":true,"remaining":10}', 200),
      ),
    );
    await show(tester, TrialModeScreen(client: client, manualOnly: true));
    await tester.ensureVisible(find.text('Telebirr'));
    await tester.tap(find.text('Telebirr'));
    await tester.pumpAndSettle();
    expect(find.text('DEMO SCAN MODE'), findsOneWidget);
    expect(find.byKey(const Key('demo-reference')), findsOneWidget);
    expect(find.byType(WaiterDashboard), findsNothing);
    client.close();
  });
}
