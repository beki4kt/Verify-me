import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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
import 'package:verify_me/trial_mode_screen.dart';

void main() {
  testWidgets('provisioning screen renders the new visual system', (
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

    expect(find.text('Connect this terminal'), findsOneWidget);
    expect(find.text('CONNECT WORKSPACE'), findsOneWidget);
    expect(find.byType(BrandHero), findsOneWidget);
    expect(find.text('CHEKMI'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await pointer.addPointer();
    await pointer.moveTo(tester.getCenter(find.byType(ElevatedButton)));
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
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

  testWidgets('trial mode is reachable without an account', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeController()),
          ChangeNotifierProvider(create: (_) => LocalizationService()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const TrialModeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Trial mode'), findsOneWidget);
    expect(find.text('Waiter'), findsOneWidget);
    expect(find.text('VERIFY RECEIPT'), findsOneWidget);
    expect(find.byType(PaymentLogo), findsNWidgets(7));
    expect(find.textContaining('SUFFIX'), findsNothing);

    final trialScroll = find.byType(CustomScrollView);
    await tester.drag(trialScroll, const Offset(0, -260));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CBE'));
    await tester.pumpAndSettle();
    await tester.drag(trialScroll, const Offset(0, -320));
    await tester.pumpAndSettle();
    await tester.tap(find.text('VERIFY RECEIPT'));
    await tester.pumpAndSettle();

    expect(find.text('Receipt verified'), findsOneWidget);
    expect(find.text('Verified with CBE.'), findsOneWidget);
    expect(find.text('VERIFIED'), findsOneWidget);
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

  testWidgets('pricing presents trial, Basic, and recommended Pro plans', (
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

    expect(find.text('FREE INTERACTIVE TRIAL'), findsOneWidget);
    expect(find.text('Basic'), findsWidgets);
    expect(find.text('Pro'), findsWidgets);
    expect(find.text('BEST CHOICE'), findsOneWidget);
    expect(find.text('1200 ETB'), findsOneWidget);
    expect(
      find.text('Daily revenue reports and bank analytics'),
      findsOneWidget,
    );

    await tester.tap(find.textContaining('3 months').first);
    await tester.pumpAndSettle();

    expect(find.text('3000 ETB'), findsOneWidget);
    expect(find.textContaining('Save 600 ETB'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
