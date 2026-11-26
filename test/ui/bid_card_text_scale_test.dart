import 'package:bidradar/core/theme/app_theme.dart';
import 'package:bidradar/data/models/models.dart';
import 'package:bidradar/ui/pipeline/pipeline_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (name, theme) in [
    ('light', AppTheme.light()),
    ('dark', AppTheme.dark()),
  ]) {
    testWidgets('BidCard fits a 320 dp phone at 200% text ($name)', (
      tester,
    ) async {
      // A narrow phone: 640 x 1400 px at 2x.
      tester.view.physicalSize = const Size(640, 1400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final bid = Bid(
        id: 'b1',
        tenderId: 't1',
        companyId: 'c',
        stage: BidStage.watching,
        ownerUid: 'u',
        updatedAt: DateTime.now(),
        title: 'Supply and installation of a patient records system',
        buyer: 'Ministry of Health, Western Province',
        deadline: DateTime.now().add(const Duration(days: 12)),
        verdict: VerdictKind.review,
        approval: ApprovalState.pending,
        tasks: const [
          BidTask(id: '1', title: 'ISO 9001 certificate', done: true),
          BidTask(id: '2', title: 'Bid security'),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: MediaQuery.withClampedTextScaling(
            minScaleFactor: 2,
            maxScaleFactor: 2,
            child: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: BidCard(bid: bid),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Any RenderFlex overflow in the card's info row fails the test.
      expect(tester.takeException(), isNull);
      expect(find.text('Awaiting approval'), findsOneWidget);
    });
  }
}
