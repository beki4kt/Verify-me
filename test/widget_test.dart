import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:verify_me/business_gateway_screen.dart';
import 'package:verify_me/core/theme/app_theme.dart';
import 'package:verify_me/core/theme/app_colors.dart';
import 'package:verify_me/core/theme/theme_controller.dart';
import 'package:verify_me/core/widgets/app_shell.dart';
import 'package:verify_me/localization_service.dart';
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
    expect(find.text('Preview verification'), findsOneWidget);
  });
}
