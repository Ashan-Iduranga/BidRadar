import 'package:bidradar/core/theme/app_theme.dart';
import 'package:bidradar/data/models/models.dart';
import 'package:bidradar/ui/widgets/fit_score_badge.dart';
import 'package:bidradar/ui/widgets/tender_card.dart';
import 'package:bidradar/ui/widgets/verdict_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? AppTheme.light(),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('VerdictChip', () {
    for (final (kind, label) in [
      (VerdictKind.bid, 'Bid'),
      (VerdictKind.noBid, 'No bid'),
      (VerdictKind.review, 'Review'),
      (null, 'Pending'),
    ]) {
      testWidgets('shows text and icon for $kind, not colour alone', (
        tester,
      ) async {
        await tester.pumpWidget(_wrap(VerdictChip(verdict: kind)));
        expect(find.text(label), findsOneWidget);
        expect(find.byType(Icon), findsOneWidget);
        expect(find.bySemanticsLabel('Verdict: $label'), findsOneWidget);
      });
    }

    testWidgets('renders in dark theme', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const VerdictChip(verdict: VerdictKind.bid),
          theme: AppTheme.dark(),
        ),
      );
      expect(find.text('Bid'), findsOneWidget);
    });
  });

  testWidgets('FitScoreBadge clamps and announces the score', (tester) async {
    await tester.pumpWidget(_wrap(const FitScoreBadge(score: 130)));
    expect(find.text('100'), findsOneWidget);
    expect(find.bySemanticsLabel('Fit score 100 of 100'), findsOneWidget);
  });

  group('deadlineLabel', () {
    final now = DateTime(2026, 11, 1, 9);
    test('unknown', () => expect(deadlineLabel(null, now), 'Deadline unknown'));
    test('closed', () {
      expect(deadlineLabel(DateTime(2026, 10, 30), now), 'Closed');
    });
    test('today', () {
      expect(deadlineLabel(DateTime(2026, 11, 1, 17), now), 'Closes today');
    });
    test('in N days', () {
      expect(deadlineLabel(DateTime(2026, 11, 8, 12), now), 'Closes in 7 days');
    });
  });

  testWidgets('TenderCard shows title, buyer, verdict and veto reason', (
    tester,
  ) async {
    final tender = Tender(
      source: TenderSourceType.worldBank,
      sourceId: 'OP000123',
      title: 'Supply of desktop computers for district offices',
      buyer: 'Ministry of Health',
      country: 'LKA',
      cpvCodes: const ['30200000'],
      deadline: DateTime(2026, 10, 20),
      noticeText: '...',
      textHash: 'h',
      fetchedAt: DateTime(2026, 11, 1),
    );
    final verdict = Verdict(
      id: 'v',
      tenderId: tender.id,
      companyId: 'c',
      verdict: VerdictKind.noBid,
      fitScore: 0,
      criteria: const [],
      missingDocs: const [],
      rulesResult: const RulesResult(
        vetoes: [
          RuleVeto(
            rule: VetoRule.deadlinePassed,
            message: 'Deadline passed on 20 Oct 2026',
          ),
        ],
      ),
      status: VerdictStatus.rulesVeto,
      model: 'rules',
      at: DateTime(2026, 11, 1),
    );
    await tester.pumpWidget(
      _wrap(
        TenderCard(
          tender: tender,
          verdict: verdict,
          now: DateTime(2026, 11, 1),
        ),
      ),
    );
    expect(find.textContaining('Supply of desktop'), findsOneWidget);
    expect(find.text('Ministry of Health · LKA'), findsOneWidget);
    expect(find.text('No bid'), findsOneWidget);
    expect(find.text('Closed'), findsOneWidget);
    expect(find.text('World Bank'), findsOneWidget);
    expect(find.text('Deadline passed on 20 Oct 2026'), findsOneWidget);
  });
}
