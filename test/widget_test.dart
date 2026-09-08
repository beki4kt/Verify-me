import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:verify_me/core/services/demo_verification_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:verify_me/business_gateway_screen.dart';
import 'package:verify_me/core/theme/app_theme.dart';
import 'package:verify_me/core/theme/app_colors.dart';
import 'package:verify_me/core/theme/theme_controller.dart';
import 'package:verify_me/core/widgets/app_shell.dart';
import 'package:verify_me/core/widgets/payment_brand.dart';
import 'package:verify_me/localization_service.dart';
import 'package:verify_me/pricing_screen.dart';
import 'package:verify_me/super_admin_login_screen.dart';
import 'package:verify_me/support_privacy_screen.dart';
import 'package:verify_me/trial_mode_screen.dart';
import 'package:verify_me/waiter_dashboard.dart';

void main() {
  testWidgets('provisioning screen renders the polished SaaS visual system', (
    tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeController()),
          ChangeNotifierProvider(create: (_) => LocalizationService()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const BusinessGatewayScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Workspace'), findsOneWidget);
    expect(find.text('CONNECT'), findsWidgets);
    expect(find.byType(FloatingNavIsland), findsOneWidget);
    expect(find.byType(GradientText), findsWidgets);
    expect(find.text('Every payment.\nVerified.'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('CHEKMI'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);

    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await pointer.addPointer();
    await pointer.moveTo(tester.getCenter(find.byType(ElevatedButton).first));
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping the CHEKMI logo opens protected owner access', (
    tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeController()),
          ChangeNotifierProvider(create: (_) => LocalizationService()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const BusinessGatewayScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BrandMark));
    await tester.pumpAndSettle();

    expect(find.byType(SuperAdminLoginScreen), findsOneWidget);
    expect(find.byKey(const Key('operatorEmailField')), findsOneWidget);
    expect(find.byKey(const Key('operatorPasswordField')), findsOneWidget);
    expect(find.byKey(const Key('operatorCodeField')), findsOneWidget);
  });

  test('button text styles can animate without inheritance assertions', () {
    final theme = AppTheme.dark();
    final buttonStyle = theme.elevatedButtonTheme.style!.textStyle!.resolve(
      {},
    )!;

    expect(buttonStyle.inherit, isFalse);
    expect(
      () => TextStyle.lerp(const TextStyle(inherit: false), buttonStyle, .5),
      returnsNormally,
    );
  });

  testWidgets('light theme uses readable ink on a warm background', (
    tester,
  ) async {
    late ThemeData captured;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            captured = Theme.of(context);
            return const Scaffold(body: Text('Readable content'));
          },
        ),
      ),
    );

    expect(captured.scaffoldBackgroundColor, AppColors.lightBg);
    expect(captured.colorScheme.onSurface, AppColors.lightInk);
    expect(captured.textTheme.bodyLarge?.color, isNot(Colors.white));
  });

  testWidgets('global language and theme controls stay touch-friendly', (
    tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeController()),
          ChangeNotifierProvider(create: (_) => LocalizationService()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(
            body: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GlassLanguageToggleButton(),
                  GlassThemeToggleButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byType(GlassLanguageToggleButton)),
      const Size(80, 40),
    );
    expect(
      tester.getSize(find.byType(GlassThemeToggleButton)),
      const Size(44, 44),
    );
  });

  testWidgets('live demo opens payment methods without a staff dashboard', (
    tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeController()),
          ChangeNotifierProvider(create: (_) => LocalizationService()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: TrialModeScreen(
            manualOnly: true,
            client: DemoVerificationClient(
              token: () async => 'a' * 64,
              client: MockClient(
                (_) async => http.Response('{"demo":true,"remaining":10}', 200),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Demo scanner'), findsOneWidget);
    expect(find.text('Payment method'), findsOneWidget);
    expect(find.byType(WaiterDashboard), findsNothing);
    expect(find.text('OPEN PAYMENTS'), findsNothing);
    expect(find.byType(PaymentLogo), findsNWidgets(6));
    expect(find.textContaining('SUFFIX'), findsNothing);
  });

  testWidgets('browser-safe waiter entry opens without camera OCR', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
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
          theme: AppTheme.dark(),
          home: const WaiterDashboard(forceManualReceiptEntry: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scan receipt'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Use manual entry in Safari'), findsOneWidget);

    await tester.tap(find.text('Telebirr'));
    await tester.pumpAndSettle();

    expect(find.text('NEW PAYMENT'), findsOneWidget);
    expect(find.text('REFERENCE'), findsOneWidget);
    expect(find.text('Invoice number (optional)'), findsOneWidget);
    expect(find.text('AMOUNT (ETB)'), findsOneWidget);
    expect(find.textContaining('ACCOUNT SUFFIX'), findsNothing);
    expect(find.textContaining('CBE BIRR PHONE'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('payment provider aliases resolve to the correct official logos', () {
    expect(
      PaymentBrandData.resolve('Commercial Bank of Ethiopia').asset,
      'assets/payment_logos/cbe.png',
    );
    expect(
      PaymentBrandData.resolve('CBEBirr').asset,
      'assets/payment_logos/cbe_birr.png',
    );
    expect(
      PaymentBrandData.resolve('Safaricom M-Pesa').asset,
      'assets/payment_logos/mpesa.png',
    );
  });

  testWidgets('pricing is one animated Basic or Pro decision surface', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeController()),
          ChangeNotifierProvider(create: (_) => LocalizationService()),
        ],
        child: MaterialApp(theme: AppTheme.dark(), home: const PricingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PLANS'), findsOneWidget);
    expect(find.text('Choose a plan'), findsOneWidget);
    expect(find.text('Basic'), findsWidgets);
    expect(find.text('Pro'), findsWidgets);
    expect(find.text('PRO'), findsOneWidget);
    expect(find.text('1200 ETB'), findsOneWidget);
    expect(find.text('Reports · analytics'), findsOneWidget);

    await tester.tap(find.textContaining('3 months').first);
    await tester.pumpAndSettle();

    expect(find.text('3000 ETB'), findsOneWidget);
    expect(find.textContaining('Save 600 ETB'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('help center exposes support, policies, and admin deletion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
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
          theme: AppTheme.dark(),
          home: SupportPrivacyScreen(
            allowAccountDeletion: true,
            loadCases: () async => [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('supportSubjectField')), findsOneWidget);
    expect(find.text('SEND TO CHEKMI SUPPORT'), findsOneWidget);

    await tester.tap(find.text('Policies'));
    await tester.pumpAndSettle();
    expect(find.text('Privacy notice'), findsOneWidget);
    expect(find.text('Service terms'), findsOneWidget);

    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('deletionReasonField')), findsOneWidget);
    expect(find.text('REQUEST ACCOUNT DELETION'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
