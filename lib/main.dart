import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:verify_me/core/theme/app_icons.dart';
import 'package:provider/provider.dart';

import 'business_gateway_screen.dart';
import 'api_service.dart';
import 'staff_login_screen.dart';
import 'core/config/app_environment.dart';
import 'core/config/app_variant.dart';
import 'core/session/session_controller.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'localization_service.dart';
import 'offline_storage.dart';

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      _reportUnhandledError(details.exception, area: 'flutter');
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      _reportUnhandledError(error, area: 'platform');
      return true;
    };
    runApp(const _ChekmiBootstrap());
  }, (error, stack) => _reportUnhandledError(error, area: 'zone'));
}

void _reportUnhandledError(Object error, {required String area}) {
  unawaited(
    ApiService.reportClientError(
      area: area,
      errorCode: error.runtimeType.toString(),
      platform: kIsWeb ? 'web' : defaultTargetPlatform.name,
    ),
  );
}

class _ChekmiBootstrap extends StatefulWidget {
  const _ChekmiBootstrap();

  @override
  State<_ChekmiBootstrap> createState() => _ChekmiBootstrapState();
}

class _ChekmiBootstrapState extends State<_ChekmiBootstrap> {
  late Future<void> _startup;
  late final SessionController _session;

  @override
  void initState() {
    super.initState();
    _session = SessionController();
    _startup = AppVariant.isUiPreview ? Future<void>.value() : _initialize();
  }

  Future<void> _initialize() async {
    AppEnvironment.validateOrThrow();
    await SyncManager.initialize();
    SyncManager.instance.startBackgroundSync();

    final lockedBusiness = DeviceStorage.getLockedBusiness();
    if (lockedBusiness['id'] != null) {
      _session.bindBusiness(
        businessId: lockedBusiness['id']!,
        businessName: lockedBusiness['name'] ?? 'Business',
      );
      ApiService.currentBusinessId = lockedBusiness['id'];
    }
    ApiService.configureSession(_session);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _startup,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        final configurationError = snapshot.error is AppConfigurationException;
        return MaterialApp(
          title: AppVariant.isTest2 ? 'CHEKMI Test 2' : 'CHEKMI',
          theme: AppTheme.dark(iPhone: AppVariant.usesIPhoneUi),
          home: Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      configurationError
                          ? AppIcons.settings
                          : AppIcons.database,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      configurationError
                          ? (AppVariant.usesMinimalCopy
                                ? 'Setup required'
                                : 'CHEKMI needs valid production configuration.')
                          : (AppVariant.usesMinimalCopy
                                ? 'Storage unavailable'
                                : 'CHEKMI could not open local storage.'),
                      textAlign: TextAlign.center,
                    ),
                    if (configurationError && !AppVariant.usesMinimalCopy) ...[
                      const SizedBox(height: 10),
                      Text(
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => setState(() => _startup = _initialize()),
                      icon: const Icon(AppIcons.refresh),
                      label: const Text('TRY AGAIN'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      if (snapshot.connectionState != ConnectionState.done) {
        return MaterialApp(
          title: AppVariant.isTest2 ? 'CHEKMI Test 2' : 'CHEKMI',
          theme: AppTheme.dark(iPhone: AppVariant.usesIPhoneUi),
          home: const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
        );
      }
      return MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: _session),
          ChangeNotifierProvider(create: (_) => ThemeController()),
          ChangeNotifierProvider(create: (_) => LocalizationService()),
        ],
        child: const VerifyMeApp(),
      );
    },
  );
}

class VerifyMeApp extends StatelessWidget {
  const VerifyMeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    final localization = context.watch<LocalizationService>();
    // Dynamic root routing: if the device is locked to a business, go straight
    // to staff login; otherwise start device provisioning.
    final locked = DeviceStorage.getLockedBusiness();
    final initial = locked['id'] != null
        ? const StaffLoginScreen()
        : const BusinessGatewayScreen();

    return MaterialApp(
      title: AppVariant.isTest2 ? 'CHEKMI Test 2' : 'CHEKMI',
      debugShowCheckedModeBanner: false,
      locale: localization.locale,
      theme: AppTheme.light(iPhone: AppVariant.usesIPhoneUi),
      darkTheme: AppTheme.dark(iPhone: AppVariant.usesIPhoneUi),
      themeMode: theme.mode,
      themeAnimationDuration: Duration(
        milliseconds: AppVariant.usesIPhoneUi ? 220 : 650,
      ),
      themeAnimationCurve: AppVariant.usesIPhoneUi
          ? Curves.easeOutCubic
          : Curves.easeInOutCubicEmphasized,
      builder: (context, child) =>
          AppEnvironment.environmentName.trim().toLowerCase() == 'staging'
          ? Banner(
              message: 'STAGING',
              location: BannerLocation.topEnd,
              color: const Color(0xFFD97706),
              child: child ?? const SizedBox.shrink(),
            )
          : child ?? const SizedBox.shrink(),
      home: initial,
    );
  }
}
