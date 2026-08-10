import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'business_gateway_screen.dart';
import 'api_service.dart';
import 'staff_login_screen.dart';
import 'core/session/session_controller.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'localization_service.dart';
import 'offline_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // TODO(security): move these to --dart-define / env. Kept inline for now
  // per the current restructuring phase (security is a later sprint).
  await Supabase.initialize(
    url: 'https://lpbdxtzyzlaioggefscc.supabase.co',
    publishableKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxwYmR4dHp5emxhaW9nZ2Vmc2NjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIyOTMyMDUsImV4cCI6MjA5Nzg2OTIwNX0.X9d4_FkisQRQXYFhyVJ_-5XSsbkS1VCHMLLybfGfpzs',
  );

  // Local Hive engine + automatic background sync loops.
  await SyncManager.initialize();
  SyncManager.instance.startBackgroundSync();

  final session = SessionController();
  final lockedBusiness = DeviceStorage.getLockedBusiness();
  if (lockedBusiness['id'] != null) {
    session.bindBusiness(
      businessId: lockedBusiness['id']!,
      businessName: lockedBusiness['name'] ?? 'Restaurant',
    );
    ApiService.currentBusinessId = lockedBusiness['id'];
  }
  ApiService.configureSession(session);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: session),
        ChangeNotifierProvider(create: (_) => ThemeController()),
        ChangeNotifierProvider(create: (_) => LocalizationService()),
      ],
      child: const VerifyMeApp(),
    ),
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
      title: 'CHEKMI',
      debugShowCheckedModeBanner: false,
      locale: localization.locale,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: theme.mode,
      home: initial,
    );
  }
}
