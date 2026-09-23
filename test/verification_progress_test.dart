import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verify_me/core/widgets/verification_progress.dart';

void main() {
  testWidgets('shows every verification stage and delayed guidance', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VerificationProgress(
            stage: VerificationProgressStage.savingTicket,
            takingLonger: true,
          ),
        ),
      ),
    );

    expect(find.text('Checking provider'), findsOneWidget);
    expect(find.text('Confirming destination and amount'), findsOneWidget);
    expect(find.text('Saving ticket'), findsOneWidget);
    expect(find.byKey(const Key('verification-taking-longer')), findsOneWidget);
  });
}
