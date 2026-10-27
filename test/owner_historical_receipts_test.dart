import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verify_me/owner_historical_receipts_screen.dart';

void main() {
  testWidgets(
    'read-only owner history shows server rows and truthful details',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: OwnerHistoricalReceiptsScreen(
            loadReceipts: () async => [
              {
                'ticket_id': 'synthetic-ticket',
                'verified_amount': 250,
                'currency': 'ETB',
                'provider': 'telebirr',
                'transaction_reference': 'SYNTHETIC-1',
              },
            ],
            loadDetail: (_) async => {
              'verified_amount': 250,
              'currency': 'ETB',
              'provider': 'telebirr',
              'transaction_reference': 'SYNTHETIC-1',
              'evidence_status': 'missing_original',
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Past receipts'), findsOneWidget);
      expect(find.text('250 ETB'), findsOneWidget);
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();
      expect(find.text('Receipt details'), findsOneWidget);
      expect(find.text('missing_original'), findsOneWidget);
      expect(
        find.textContaining('Original image access is not available'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('read-only history has a useful empty state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OwnerHistoricalReceiptsScreen(loadReceipts: () async => []),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No verified receipts yet.'), findsOneWidget);
  });
}
