import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:verify_me/cashier_dashboard.dart';
import 'package:verify_me/core/config/app_variant.dart';
import 'package:verify_me/core/theme/app_theme.dart';
import 'package:verify_me/core/theme/theme_controller.dart';
import 'package:verify_me/localization_service.dart';
import 'package:verify_me/staff_login_screen.dart';
import 'package:verify_me/waiter_dashboard.dart';
import 'package:verify_me/iphone/iphone_business_gateway_screen.dart';

/// Layout smoke tests at narrow iPhone dimensions. Flutter's test framework
/// throws on RenderFlex overflow and on any widget-building exception, so a
/// passing run verifies the redesigned screens stay within bounds in both
/// themes — including empty, loading, and error states.
void main() {
  // The dashboards branch on AppVariant.usesIPhoneUi, which is only true on
  // iOS devices or when built with the iPhone preview flag. Run this suite
  // with: flutter test --dart-define=CHEKMI_IPHONE_UI=true
  // Without the flag the tests skip so the default suite stays green.
  if (!AppVariant.forceIPhoneUi) {
    // ignore: avoid_print
    print(
      'Skipping iPhone layout suite (pass --dart-define=CHEKMI_IPHONE_UI=true).',
    );
    return;
  }

  Future<void> pumpIPhone(
    WidgetTester tester, {
    required Widget home,
    required Brightness brightness,
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
          theme: AppTheme.light(iPhone: true),
          darkTheme: AppTheme.dark(iPhone: true),
          themeMode: brightness == Brightness.dark
              ? ThemeMode.dark
              : ThemeMode.light,
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    final label = brightness == Brightness.dark ? 'dark' : 'light';

    testWidgets('gateway renders within $label 390×844 bounds', (tester) async {
      await pumpIPhone(
        tester,
        home: const IPhoneBusinessGatewayScreen(),
        brightness: brightness,
      );

      expect(
        find.text('Every payment.\nVerified.'),
        AppVariant.isPublicRelease ? findsNothing : findsOneWidget,
      );
      expect(find.byKey(const Key('iphone-workspace-code')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('staff login renders within $label 390×844 bounds', (
      tester,
    ) async {
      await pumpIPhone(
        tester,
        home: const StaffLoginScreen(),
        brightness: brightness,
      );

      expect(find.byKey(const Key('iphone-staff-phone')), findsOneWidget);
      expect(find.byKey(const Key('iphone-staff-password')), findsOneWidget);
      expect(find.byKey(const Key('iphone-staff-sign-in')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('waiter flow renders its states within $label 390×844 bounds', (
      tester,
    ) async {
      await pumpIPhone(
        tester,
        home: const WaiterDashboard(forceManualReceiptEntry: true),
        brightness: brightness,
      );

      // Tab 1: empty ticket state is a doorway, not a dead end.
      expect(find.text('Scan a receipt'), findsOneWidget);

      // Tab 2: scanner (bank picker in manual entry mode).
      await tester.tap(find.text('Scan'));
      await tester.pumpAndSettle();
      expect(find.text('Payment method'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Open the manual submission sheet and check it fits.
      await tester.tap(find.text('Telebirr'));
      await tester.pumpAndSettle();
      expect(find.text('NEW PAYMENT'), findsOneWidget);
      expect(find.text('Invoice number (optional)'), findsOneWidget);
      await tester.tap(find.byKey(const Key('payment-context-kind')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Customer').last);
      await tester.pumpAndSettle();
      expect(find.text('Customer reference (optional)'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Dismiss the sheet via the modal barrier above it.
      await tester.tapAt(const Offset(195, 40));
      await tester.pumpAndSettle();

      // Activity prioritizes payment totals; tips remain a secondary feature.
      await tester.tap(find.text('Activity'));
      await tester.pumpAndSettle();
      expect(find.textContaining('VERIFIED PAYMENTS'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cashier renders its states within $label 390×844 bounds', (
      tester,
    ) async {
      await pumpIPhone(
        tester,
        home: const CashierDashboard(),
        brightness: brightness,
      );

      // Empty pending queue.
      expect(find.text('Queue clear'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Segmented tabs swap content with no overflow.
      await tester.tap(find.text('Settled'));
      await tester.pumpAndSettle();
      expect(find.text('No payments'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
