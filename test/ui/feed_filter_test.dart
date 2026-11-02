import 'package:bidradar/data/local/app_database.dart';
import 'package:bidradar/data/models/models.dart';
import 'package:bidradar/ui/feed/feed_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

FeedItem item(
  String id, {
  TenderSourceType source = TenderSourceType.ted,
  List<String> cpv = const ['72200000'],
  int? daysLeft = 10,
  bool vetoed = false,
  bool warning = false,
}) => FeedItem(
  Tender(
    source: source,
    sourceId: id,
    title: id,
    buyer: 'B',
    country: 'LKA',
    cpvCodes: cpv,
    deadline: daysLeft == null
        ? null
        : DateTime.utc(2026, 11, 2).add(Duration(days: daysLeft)),
    noticeText: id,
    textHash: id,
    fetchedAt: DateTime.utc(2026, 11, 2),
  ),
  RulesResult(
    vetoes: [
      if (vetoed) const RuleVeto(rule: VetoRule.countryNotServed, message: 'x'),
    ],
    warnings: [if (warning) 'Deadline unknown.'],
  ),
);

List<String> ids(List<FeedItem> l) => l.map((i) => i.tender.sourceId).toList();

void main() {
  final items = [
    item('late', daysLeft: 20),
    item('soon', daysLeft: 2),
    item('warn', daysLeft: 1, warning: true),
    item('nodate', daysLeft: null),
    item('removed', daysLeft: 1, vetoed: true),
    item('wb', source: TenderSourceType.worldBank, cpv: [], daysLeft: 5),
    item('build', cpv: ['45000000'], daysLeft: 3),
  ];

  test('default shows eligible tenders, clean passes first by deadline', () {
    expect(ids(applyFeedFilter(items, const FeedFilter())), [
      'soon',
      'build',
      'wb',
      'late',
      'nodate',
      'warn',
    ]);
  });

  test('status filters', () {
    expect(
      ids(applyFeedFilter(items, const FeedFilter(status: FeedStatus.review))),
      ['warn'],
    );
    expect(
      ids(applyFeedFilter(items, const FeedFilter(status: FeedStatus.removed))),
      ['removed'],
    );
    expect(
      applyFeedFilter(items, const FeedFilter(status: FeedStatus.all)),
      hasLength(items.length),
    );
    expect(
      ids(applyFeedFilter(items, const FeedFilter(status: FeedStatus.all)))
          .last,
      'removed',
      reason: 'removed tenders rank last',
    );
  });

  test('source filter', () {
    final f = FeedFilter(sources: {TenderSourceType.worldBank});
    expect(ids(applyFeedFilter(items, f)), ['wb']);
  });

  test('sector filter matches sub-codes and drops tenders without CPV', () {
    const f = FeedFilter(sector: '72000000');
    final out = ids(applyFeedFilter(items, f));
    expect(out, containsAll(['soon', 'late']));
    expect(out, isNot(contains('build')));
    expect(out, isNot(contains('wb')));
  });

  test('filter state helpers', () {
    const f = FeedFilter();
    expect(f.isDefault, isTrue);
    expect(f.copyWith(sector: () => '72000000').sector, '72000000');
    expect(
      f.copyWith(sector: () => '72000000').copyWith(sector: () => null).sector,
      isNull,
    );
  });

  test('syncSummary and updatedLabel', () {
    expect(
      syncSummary(
        SyncReport(
          ranAt: DateTime.utc(2026),
          added: 12,
          matched: 9,
          vetoed: 3,
          errors: const ['World Bank: no connection'],
        ),
      ),
      '12 new · 9 match · 3 removed by rules · World Bank: no connection',
    );
    expect(
      syncSummary(SyncReport(ranAt: DateTime.utc(2026))),
      'No new tenders',
    );

    final now = DateTime(2026, 11, 2, 12);
    expect(updatedLabel(null, now), 'Never synced');
    expect(
      updatedLabel(now.subtract(const Duration(seconds: 20)), now),
      'Updated just now',
    );
    expect(
      updatedLabel(now.subtract(const Duration(minutes: 5)), now),
      'Updated 5 min ago',
    );
    expect(
      updatedLabel(now.subtract(const Duration(hours: 3)), now),
      'Updated 3 h ago',
    );
    expect(
      updatedLabel(now.subtract(const Duration(days: 1)), now),
      'Updated yesterday',
    );
    expect(
      updatedLabel(now.subtract(const Duration(days: 4)), now),
      'Updated 4 days ago',
    );
  });
}
