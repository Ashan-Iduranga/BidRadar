import 'package:bidradar/core/theme/app_theme.dart';
import 'package:bidradar/data/models/models.dart';
import 'package:bidradar/ui/deadlines/deadlines_page.dart';
import 'package:bidradar/ui/pipeline/pipeline_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Bid bid(String id, DateTime deadline) => Bid(
  id: id,
  tenderId: 't$id',
  companyId: 'c',
  stage: BidStage.watching,
  ownerUid: 'u',
  updatedAt: DateTime.now(),
  title: 'Patient records system $id',
  buyer: 'Ministry of Health',
  deadline: deadline,
);

void main() {
  for (final (name, theme) in [
    ('light', AppTheme.light()),
    ('dark', AppTheme.dark()),
  ]) {
    testWidgets('Deadlines fits a 360 dp phone at 200% text ($name)', (
      tester,
    ) async {
      // A small phone: 720 x 1600 px at 2x.
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      // Deadlines in the month the calendar opens on, so day cells carry
      // their dot (active bids show whether or not the date has passed).
      final now = DateTime.now();
      final bids = [
        for (final day in [1, 27, 28])
          bid('$day', DateTime(now.year, now.month, day, 14)),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [bidsProvider.overrideWith((ref) => Stream.value(bids))],
          child: MaterialApp(
            theme: theme,
            home: MediaQuery.withClampedTextScaling(
              minScaleFactor: 2,
              maxScaleFactor: 2,
              child: const DeadlinesPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Any RenderFlex overflow in the month grid fails the test. The bid
      // cards below it are pipeline_page.dart's BidCard and are not on
      // screen here.
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Next month'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  }
}
