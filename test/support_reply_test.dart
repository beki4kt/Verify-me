import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:verify_me/core/theme/app_theme.dart';
import 'package:verify_me/core/theme/theme_controller.dart';
import 'package:verify_me/localization_service.dart';
import 'package:verify_me/support_privacy_screen.dart';

void main() {
  testWidgets('shows the owner response inside support case history', (
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
            loadConsents: () async => [],
            loadCases: () async => const [
              {
                'subject': 'Payment reference review',
                'category': 'payment',
                'status': 'in_progress',
                'owner_response':
                    'We found the transfer and are checking the destination.',
              },
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('support-owner-response')), findsOneWidget);
    expect(
      find.text('We found the transfer and are checking the destination.'),
      findsOneWidget,
    );
  });
}
