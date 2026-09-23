import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verify_me/core/theme/app_motion.dart';
import 'package:verify_me/core/theme/app_theme.dart';
import 'package:verify_me/core/widgets/skeleton.dart';
import 'package:verify_me/core/widgets/state_views.dart';
import 'package:verify_me/core/widgets/status_pill.dart';

void main() {
  group('Pressable', () {
    testWidgets('fires onTap and stays settled with pumpAndSettle', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(iPhone: true),
          home: Center(
            child: Pressable(
              onTap: () => taps++,
              child: const SizedBox(width: 120, height: 48, child: Text('Row')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Row'));
      await tester.pumpAndSettle();

      expect(taps, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('is inert when disabled', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: Pressable(
              enabled: false,
              onTap: () => taps++,
              child: const SizedBox(width: 120, height: 48, child: Text('Row')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Row'));
      await tester.pumpAndSettle();

      expect(taps, 0);
    });
  });

  group('FadeThroughSwitcher', () {
    testWidgets('swaps content when the child key changes', (tester) async {
      var current = 0;
      late StateSetter setStateRoot;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              setStateRoot = setState;
              return Scaffold(
                body: FadeThroughSwitcher(
                  child: KeyedSubtree(
                    key: ValueKey(current),
                    child: Center(child: Text('Pane $current')),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pane 0'), findsOneWidget);

      setStateRoot(() => current = 1);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Pane 1'), findsOneWidget);
      expect(find.text('Pane 0'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('State views', () {
    testWidgets('EmptyView exposes an optional action doorway', (tester) async {
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(iPhone: true),
          home: EmptyView(
            icon: Icons.receipt,
            title: 'No open tickets',
            message: 'Scan a receipt to verify a payment.',
            actionLabel: 'Scan a receipt',
            onAction: () => opened = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No open tickets'), findsOneWidget);
      expect(find.text('Scan a receipt to verify a payment.'), findsOneWidget);

      await tester.tap(find.text('Scan a receipt'));
      expect(opened, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ErrorView offers a calm retry action', (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(iPhone: true),
          home: ErrorView(
            message: 'Camera access failed.',
            onRetry: () => retries++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Camera access failed.'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      expect(retries, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('LoadingView settles without perpetual tickers', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: LoadingView(message: 'Opening scanner')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Opening scanner'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('skeletons settle without perpetual shimmer tickers', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TicketSkeletonRow())),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('StatusPill', () {
    testWidgets('animates color changes without rebuilding the label', (
      tester,
    ) async {
      late StateSetter setStateRoot;
      var settled = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(iPhone: true),
          home: StatefulBuilder(
            builder: (context, setState) {
              setStateRoot = setState;
              return Scaffold(
                body: Center(
                  child: StatusPill(
                    label: settled ? 'settled' : 'pending',
                    color: settled ? const Color(0xFF10B981) : Colors.amber,
                  ),
                ),
              );
            },
          ),
        ),
      );
      expect(find.text('SETTLED'), findsOneWidget);

      setStateRoot(() => settled = false);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('PENDING'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
