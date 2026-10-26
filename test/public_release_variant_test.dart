import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:verify_me/business_gateway_screen.dart';
import 'package:verify_me/core/config/app_environment.dart';
import 'package:verify_me/core/config/app_variant.dart';
import 'package:verify_me/core/theme/app_theme.dart';
import 'package:verify_me/core/theme/theme_controller.dart';
import 'package:verify_me/localization_service.dart';
import 'package:verify_me/pricing_screen.dart';

void main() {
  test(
    'public production build exposes only contracted release capabilities',
    () {
      expect(AppVariant.isPublicRelease, isTrue);
      expect(AppVariant.exposesOperatorConsole, isFalse);
      expect(AppVariant.showsPlanMarketing, isTrue);
      expect(AppVariant.enabledPaymentProviders, const [
        (id: 'telebirr', label: 'Telebirr'),
      ]);
      expect(AppVariant.isPaymentProviderEnabled('Telebirr'), isTrue);
      expect(AppVariant.isPaymentProviderEnabled('CBE'), isFalse);
    },
    skip: !AppEnvironment.isProduction,
  );

  testWidgets(
    'public gateway exposes pricing without demo or owner operations',
    (tester) async {
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
            theme: AppTheme.dark(),
            home: const BusinessGatewayScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('gateway-mobile-pricing')), findsOneWidget);
      expect(find.text('PRICING'), findsOneWidget);
      expect(find.text('LIVE DEMO'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('gateway-mobile-pricing')));
      await tester.pumpAndSettle();

      expect(find.byType(PricingScreen), findsOneWidget);
      expect(find.text('Choose a plan'), findsOneWidget);
      expect(find.text('LIVE DEMO'), findsNothing);
      expect(tester.takeException(), isNull);
    },
    skip: !AppEnvironment.isProduction,
  );
}
