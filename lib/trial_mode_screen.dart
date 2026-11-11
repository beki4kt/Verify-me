import 'package:flutter/material.dart';

import 'demo_scanner_screen.dart';
import 'core/services/demo_verification_client.dart';

/// Public demo entry stays independent of business authentication and dashboards.
class TrialModeScreen extends StatelessWidget {
  const TrialModeScreen({super.key, this.client, this.manualOnly = false});
  final DemoVerificationClient? client;
  final bool manualOnly;
  @override
  Widget build(BuildContext context) =>
      DemoScannerScreen(client: client, manualOnly: manualOnly);
}
