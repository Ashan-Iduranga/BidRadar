import 'package:bidradar/core/theme/app_theme.dart';
import 'package:bidradar/data/models/models.dart';
import 'package:bidradar/ui/tender_detail/tender_detail_page.dart';
import 'package:bidradar/ui/tender_detail/tender_detail_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final tender = Tender(
  source: TenderSourceType.ted,
  sourceId: '711841-2026',
  title: 'Maintenance of IT software',
  buyer: 'Comunidad de Madrid',
  country: 'ESP',
  cpvCodes: const ['72267100', '48000000'],
  deadline: DateTime.utc(2026, 11, 6, 22, 59),
  estimatedValue: 347490,
  currency: 'EUR',
  noticeText: 'Software maintenance for remote desktop support.',
  textHash: 'h',
  url: 'https://ted.europa.eu/en/notice/-/detail/711841-2026',
  documentUrls: const ['https://ted.europa.eu/en/notice/711841-2026/pdf'],
  fetchedAt: DateTime.utc(2026, 11, 2),
);

Future<void> pump(WidgetTester tester, TenderDetail detail) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tenderDetailProvider('ted_711841-2026')
            .overrideWithValue(AsyncData(detail)),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const TenderDetailPage(tenderId: 'ted_711841-2026'),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('shows facts, a veto, a warning and the verdict placeholder', (
    tester,
  ) async {
    await pump(
      tester,
      TenderDetail(
        tender: tender,
        rules: const RulesResult(
          vetoes: [
            RuleVeto(
              rule: VetoRule.countryNotServed,
              message: 'You do not deliver in Spain (ESP).',
            ),
          ],
          warnings: ['Closes in less than 72 hours.'],
        ),
      ),
    );

    expect(find.text('Maintenance of IT software'), findsOneWidget);
    expect(find.text('Comunidad de Madrid · Spain'), findsOneWidget);
    expect(find.text('EU TED · 711841-2026'), findsOneWidget);
    expect(find.text('72267100, 48000000'), findsOneWidget);
    expect(find.textContaining('347,490'), findsOneWidget);
    expect(find.text('You do not deliver in Spain (ESP).'), findsOneWidget);
    expect(find.text('Closes in less than 72 hours.'), findsOneWidget);
    expect(find.textContaining('Not sent to the AI'), findsOneWidget);
    expect(find.byTooltip('Share'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Open notice'), 200);
    expect(find.text('Open notice'), findsOneWidget);
    expect(find.text('PDF'), findsOneWidget);
  });

  testWidgets('a clean pass says so', (tester) async {
    await pump(
      tester,
      TenderDetail(tender: tender, rules: const RulesResult.pass()),
    );
    expect(find.textContaining('Passes every hard rule'), findsOneWidget);
    expect(find.textContaining('Not judged yet'), findsOneWidget);
  });

  testWidgets('a pruned tender shows not found with a way back', (
    tester,
  ) async {
    await pump(tester, const TenderDetail(tender: null, rules: null));
    expect(find.text('Tender not found'), findsOneWidget);
    expect(find.text('Back to feed'), findsOneWidget);
    expect(find.byTooltip('Share'), findsNothing);
  });

  test('share text has title, buyer, deadline and link', () {
    final text = shareText(tender);
    expect(text, contains('Maintenance of IT software'));
    expect(text, contains('Comunidad de Madrid · closes'));
    expect(text, contains('https://ted.europa.eu/'));
  });
}
