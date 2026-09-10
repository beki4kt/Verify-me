import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:verify_me/core/theme/app_theme.dart';
import 'package:verify_me/core/theme/theme_controller.dart';
import 'package:verify_me/core/widgets/app_shell.dart';
import 'package:verify_me/iphone/iphone_business_gateway_screen.dart';
import 'package:verify_me/iphone/iphone_dashboard_shell.dart';
import 'package:verify_me/localization_service.dart';

void main() {
  test(
    'iPhone theme uses iOS platform behavior and system-like typography',
    () {
      final theme = AppTheme.dark(iPhone: true);

      expect(theme.platform, TargetPlatform.iOS);
      expect(theme.appBarTheme.toolbarHeight, 64);
      expect(theme.appBarTheme.centerTitle, isFalse);
      expect(theme.textTheme.bodyLarge?.fontSize, 17);
      expect(
        theme.pageTransitionsTheme.builders[TargetPlatform.iOS],
        isA<CupertinoPageTransitionsBuilder>(),
      );
    },
  );

  testWidgets('iPhone provisioning uses a modern native hierarchy', (
    tester,
  ) async {
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
          home: const IPhoneBusinessGatewayScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(IPhoneBusinessGatewayScreen), findsOneWidget);
    expect(find.byType(SliverAppBar), findsOneWidget);
    expect(find.byType(CupertinoTextField), findsOneWidget);
    expect(find.byKey(const Key('iphone-connect-workspace')), findsOneWidget);
    expect(find.text('Every payment.\nVerified.'), findsOneWidget);
    expect(find.text('Try the live demo'), findsOneWidget);
    expect(find.byType(FloatingNavIsland), findsNothing);

    await tester.tap(find.byKey(const Key('iphone-connect-workspace')));
    await tester.pump();

    expect(
      tester
          .widget<CupertinoTextField>(find.byType(CupertinoTextField))
          .focusNode
          ?.hasFocus,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('iPhone dashboard tabs preserve their child state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(iPhone: true),
        home: DefaultTabController(
          length: 3,
          child: Scaffold(
            body: const DashboardTabView(
              preserveState: true,
              physics: NeverScrollableScrollPhysics(),
              children: [
                _StatefulTab(label: 'Overview content'),
                _StatefulTab(label: 'Team content'),
                _StatefulTab(label: 'Manage content'),
              ],
            ),
            bottomNavigationBar: const IPhoneBottomTabBar(
              items: [
                IPhoneTabItem(label: 'Overview', icon: Icons.bar_chart),
                IPhoneTabItem(label: 'Team', icon: Icons.people),
                IPhoneTabItem(label: 'Manage', icon: Icons.settings),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Overview content'), findsOneWidget);
    await tester.tap(find.text('Team'));
    await tester.pumpAndSettle();
    expect(find.text('Team content'), findsOneWidget);

    await tester.tap(find.byKey(const Key('team-counter')));
    await tester.pump();
    expect(find.text('Team content 1'), findsOneWidget);

    await tester.tap(find.text('Overview'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Team'));
    await tester.pumpAndSettle();
    expect(find.text('Team content 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('iPhone dashboard keeps full-size preferences visible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var refreshCount = 0;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeController()),
          ChangeNotifierProvider(create: (_) => LocalizationService()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(iPhone: true),
          home: Scaffold(
            appBar: IPhoneDashboardNavigationBar(
              title: const Text('Admin'),
              onSignOut: () async {},
              onHelp: () {},
              onRefresh: () => refreshCount++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('iphone-language-toggle')), findsOneWidget);
    expect(find.byKey(const Key('iphone-theme-toggle')), findsOneWidget);
    expect(find.byKey(const Key('iphone-dashboard-refresh')), findsOneWidget);
    expect(find.byKey(const Key('iphone-dashboard-help')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('iphone-language-toggle'))),
      const Size(44, 44),
    );
    expect(
      tester.getSize(find.byKey(const Key('iphone-theme-toggle'))),
      const Size(44, 44),
    );
    await tester.tap(find.byKey(const Key('iphone-dashboard-refresh')));
    await tester.pump();
    expect(refreshCount, 1);
    expect(tester.takeException(), isNull);
  });
}

class _StatefulTab extends StatefulWidget {
  const _StatefulTab({required this.label});

  final String label;

  @override
  State<_StatefulTab> createState() => _StatefulTabState();
}

class _StatefulTabState extends State<_StatefulTab> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    final isTeam = widget.label == 'Team content';
    return Center(
      child: TextButton(
        key: isTeam ? const Key('team-counter') : null,
        onPressed: () => setState(() => _count++),
        child: Text(_count == 0 ? widget.label : '${widget.label} $_count'),
      ),
    );
  }
}
