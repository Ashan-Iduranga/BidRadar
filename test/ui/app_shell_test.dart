import 'dart:async';

import 'package:bidradar/app.dart';
import 'package:bidradar/core/firebase/firebase_bootstrap.dart';
import 'package:bidradar/core/router/app_router.dart';
import 'package:bidradar/ui/feed/feed_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseReadyProvider.overrideWithValue(false),
          // Widget tests do not open the drift database.
          cachedTendersProvider.overrideWith((ref) => Stream.value([])),
          lastSyncProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const BidRadarApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('without Firebase, the shell opens on Feed with a banner', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('No tenders yet'), findsOneWidget);
    expect(find.textContaining('Firebase not configured'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('all 5 tabs and the 3 pushed pages are reachable', (
    tester,
  ) async {
    await pumpApp(tester);

    for (final (tab, title) in [
      ('Pipeline', 'No bids in progress'),
      ('Deadlines', 'No upcoming deadlines'),
      ('Insights', 'No results yet'),
      ('Company', 'Firebase is not configured'),
      ('Feed', 'No tenders yet'),
    ]) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(tab),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget, reason: 'tab $tab');
    }

    await tester.tap(find.text('Scan notice'));
    await tester.pumpAndSettle();
    expect(find.text('Scan a printed tender'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // The Approvals button is owner-only; open the route directly.
    unawaited(
      GoRouter.of(tester.element(find.byType(NavigationBar)))
          .push(Routes.approvals),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nothing to approve'), findsOneWidget);
  });
}
