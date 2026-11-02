import 'package:bidradar/data/models/models.dart';
import 'package:bidradar/domain/insights/insights.dart';
import 'package:bidradar/domain/insights/profile_advisor.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime.utc(2026, 11, 2);

Bid bid(
  String id,
  BidStage stage, {
  VerdictKind? verdict,
  List<String> reasons = const [],
}) => Bid(
  id: id,
  tenderId: 't$id',
  companyId: 'c',
  stage: stage,
  ownerUid: 'u',
  title: id,
  buyer: 'B',
  verdict: verdict,
  lossReasons: reasons,
  updatedAt: now,
);

(Tender, Verdict) judged(
  String id,
  String buyer,
  List<String> cpv,
  VerdictKind kind,
  int fit, {
  VerdictStatus status = VerdictStatus.accepted,
}) => (
  Tender(
    source: TenderSourceType.ted,
    sourceId: id,
    title: id,
    buyer: buyer,
    country: 'LVA',
    cpvCodes: cpv,
    noticeText: id,
    textHash: id,
    fetchedAt: now,
  ),
  Verdict(
    id: 'v$id',
    tenderId: 'ted_$id',
    companyId: 'c',
    verdict: kind,
    fitScore: fit,
    criteria: const [],
    missingDocs: const [],
    rulesResult: const RulesResult.pass(),
    status: status,
    model: 'm',
    at: now,
  ),
);

void main() {
  final stats = InsightsStats.compute(
    bids: [
      bid('a', BidStage.won, verdict: VerdictKind.bid),
      bid(
        'b',
        BidStage.lost,
        verdict: VerdictKind.bid,
        reasons: ['Price too high'],
      ),
      bid(
        'c',
        BidStage.lost,
        verdict: VerdictKind.review,
        reasons: ['Price too high', 'Missed the deadline'],
      ),
      bid('d', BidStage.lost, reasons: ['Other']), // no verdict
      bid('e', BidStage.preparing),
    ],
    judged: [
      judged('1', 'Riga City', ['79410000'], VerdictKind.bid, 90),
      judged('2', 'Riga City', ['79400000'], VerdictKind.bid, 70),
      judged('3', 'Tallinn', ['80500000'], VerdictKind.review, 45),
      judged('4', 'Vilnius', ['45000000'], VerdictKind.noBid, 10),
      judged(
        '5',
        'X',
        ['72000000'],
        VerdictKind.review,
        0,
        status: VerdictStatus.aiUnavailable,
      ),
      judged(
        '6',
        'Y',
        ['72000000'],
        VerdictKind.review,
        30,
        status: VerdictStatus.quotesRejected,
      ),
    ],
  );

  test('outcomes and win rate', () {
    expect(stats.won, 1);
    expect(stats.lost, 3);
    expect(stats.open, 1);
    expect(stats.winRate, 0.25);
  });

  test('loss reasons are counted, most common first', () {
    expect(stats.lossReasons.first.label, 'Price too high');
    expect(stats.lossReasons.first.count, 2);
    expect(stats.lossReasons, hasLength(3));
  });

  test('AI agreement counts only decided bids that were judged', () {
    // a: BID & won ✓, b: BID & lost ✗, c: REVIEW & lost ✓; d has no verdict.
    expect(stats.judgedDecided, 3);
    expect(stats.agreed, 2);
    expect(stats.agreement, closeTo(2 / 3, 1e-9));
  });

  test('verdict mix skips unavailable AI; fit uses accepted only', () {
    expect(stats.verdictMix, {
      VerdictKind.bid: 2,
      VerdictKind.review: 2, // 3 and the quotes-rejected 6
      VerdictKind.noBid: 1,
    });
    expect(stats.fitBands, [1, 0, 1, 1, 1]); // 10, 45, 70, 90
  });

  test('best buyers and sectors by average fit', () {
    expect(stats.topBuyers.first.label, 'Riga City');
    expect(stats.topBuyers.first.value, 80);
    expect(stats.topBuyers.first.count, 2);
    expect(stats.topSectors.first.label, 'Business services');
    expect(stats.topSectors.last.label, 'Construction work');
  });

  test('no data gives empty, not NaN', () {
    final empty = InsightsStats.compute(bids: const [], judged: const []);
    expect(empty.winRate, isNull);
    expect(empty.agreement, isNull);
    expect(empty.judged, 0);
  });

  group('profile suggestions', () {
    test('parse kinds; unknown kinds become advice only', () {
      final s = ProfileSuggestion.fromJson(const {
        'kind': 'add_sector',
        'value': ' 72000000 ',
        'reason': 'r',
      });
      expect(s.kind, SuggestionKind.addSector);
      expect(s.value, '72000000');
      expect(s.applicable, isTrue);
      final o = ProfileSuggestion.fromJson(const {
        'kind': 'hire',
        'value': 'x',
      });
      expect(o.kind, SuggestionKind.other);
      expect(o.applicable, isFalse);
    });

    test('the prompt lists lost bids with their reasons', () {
      const company = Company(
        id: 'c',
        name: 'n',
        country: 'LVA',
        annualTurnover: 1,
        currency: 'EUR',
        teamSize: 2,
        ownerUid: 'u',
      );
      const profile = CompanyProfile(
        companyId: 'c',
        cpvCodes: ['79400000'],
        countries: ['LVA'],
      );
      final p = GeminiProfileAdvisor.buildPrompt(company, profile, [
        bid(
          'Bridge design',
          BidStage.lost,
          reasons: ['Did not meet a requirement'],
        ),
      ]);
      expect(p, contains('Bridge design'));
      expect(p, contains('Did not meet a requirement'));
      expect(p, contains('79400000'));
    });
  });

  test('suggestions the profile already has are recognised', () {
    const p = CompanyProfile(
      companyId: 'c',
      cpvCodes: ['79400000'],
      countries: ['FIN'],
      certifications: ['ISO 9001'],
    );
    ProfileSuggestion s(String kind, String value) =>
        ProfileSuggestion.fromJson({'kind': kind, 'value': value});
    expect(s('add_country', 'fin').alreadyIn(p), isTrue);
    expect(s('add_country', 'EST').alreadyIn(p), isFalse);
    expect(s('add_sector', '79400000-1').alreadyIn(p), isTrue);
    expect(s('add_certification', 'iso 9001').alreadyIn(p), isTrue);
    expect(s('other', 'Lower prices').alreadyIn(p), isFalse);
  });
}
