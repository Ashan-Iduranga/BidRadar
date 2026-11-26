import 'dart:io';

import 'package:bidradar/data/models/models.dart';
import 'package:bidradar/domain/agent/ai_failure.dart';
import 'package:bidradar/domain/agent/ai_model.dart';
import 'package:bidradar/domain/agent/bid_agent.dart';
import 'package:bidradar/domain/agent/gemini_model.dart';
import 'package:bidradar/domain/agent/guards.dart';
import 'package:bidradar/domain/agent/quote_verifier.dart';
import 'package:bidradar/domain/rules/eligibility_rules.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime.utc(2026, 11, 2, 12);

const company = Company(
  id: 'c1',
  name: 'Lanka Code Works',
  country: 'LKA',
  annualTurnover: 850000,
  currency: 'EUR',
  teamSize: 28,
  ownerUid: 'u1',
);
const profile = CompanyProfile(
  companyId: 'c1',
  cpvCodes: ['72000000'],
  countries: ['LKA'],
  certifications: ['ISO 9001'],
);

const notice =
    'Supply of a hospital appointment system. Bidders must hold ISO 9001 '
    'certification. Minimum 3 years of experience in health software. '
    'Average annual turnover of at least EUR 500,000.';

Tender tender({
  Duration closesIn = const Duration(days: 10),
  String country = 'LKA',
  List<String> cpv = const ['72200000'],
}) => Tender(
  source: TenderSourceType.ted,
  sourceId: '1-2026',
  title: 'Hospital appointment system',
  buyer: 'Ministry of Health',
  country: country,
  cpvCodes: cpv,
  deadline: now.add(closesIn),
  noticeText: notice,
  textHash: 'h',
  fetchedAt: now,
);

Criterion crit(String quote, {CriterionMet met = CriterionMet.yes}) =>
    Criterion(criterion: 'c', quote: quote, met: met);

AiVerdictPayload payload({
  VerdictKind verdict = VerdictKind.bid,
  int fit = 85,
  double confidence = 0.9,
  List<Criterion>? criteria,
}) => AiVerdictPayload(
  verdict: verdict,
  fitScore: fit,
  confidence: confidence,
  criteria:
      criteria ??
      [
        crit('Bidders must hold ISO 9001 certification'),
        crit('Minimum 3 years of experience in health software'),
      ],
  missingDocs: const ['ISO 9001 certificate copy'],
);

/// A scripted model: returns or throws the next item each call.
class FakeModel implements AiModel {
  FakeModel(this.script);
  final List<Object> script;
  int calls = 0;

  /// The rejectedQuotes passed on each call.
  final rejected = <List<String>>[];

  @override
  String get modelName => 'fake-model';

  @override
  Future<AiVerdictPayload> judgeTender({
    required Company company,
    required CompanyProfile profile,
    required Tender tender,
    List<String> rejectedQuotes = const [],
  }) async {
    final next = script[calls < script.length ? calls : script.length - 1];
    calls++;
    rejected.add(rejectedQuotes);
    if (next is AiVerdictPayload) return next;
    if (next is Duration) {
      await Future<void>.delayed(next);
      return payload();
    }
    throw next;
  }
}

/// Always answers BID with perfect, verified evidence.
class AlwaysBid extends FakeModel {
  AlwaysBid() : super([payload()]);
}

void main() {
  const rules = EligibilityRules();
  RulesResult rulesFor(Tender t) =>
      rules.check(company: company, profile: profile, tender: t, now: now);

  BidAgent agent(AiModel m) => BidAgent(
    model: m,
    clock: () => now,
    sleep: (_) async {},
    timeout: const Duration(milliseconds: 50),
  );

  Future<Verdict> judge(AiModel m, Tender t) => agent(m)
      .judge(company: company, profile: profile, tender: t, rules: rulesFor(t));

  group('QuoteVerifier', () {
    const v = QuoteVerifier();

    test('exact quotes pass, ignoring case, punctuation and spacing', () {
      final r = v.check([
        crit('bidders must hold ISO-9001   certification.'),
        crit('“Average annual turnover of at least EUR 500,000”'),
        crit('...Minimum 3 years of experience…'),
      ], notice);
      expect(r.allVerified, isTrue);
    });

    test('paraphrases, translations and joins fail', () {
      final r = v.check([
        crit('Bidders need ISO 9001'),
        crit('Mínimo 3 años de experiencia'),
        crit('ISO 9001 certification ... health software'),
      ], notice);
      expect(r.criteria.map((c) => c.quoteVerified), [false, false, false]);
    });

    test('too-short quotes prove nothing', () {
      expect(v.check([crit('ISO')], notice).allVerified, isFalse);
      // Long enough, but only 2 words.
      expect(v.check([crit('ISO 9001')], notice).allVerified, isFalse);
    });

    test('quotes match whole words only', () {
      const longer =
          'Minimum 13 years of experience. Average annual turnover of at '
          'least EUR 1,500,000 in the last 3 years.';
      bool ok(String q) => v.check([crit(q)], longer).allVerified;
      expect(ok('3 years of experience'), isFalse, reason: 'it says 13');
      expect(ok('13 years of experience'), isTrue);
      expect(ok('at least EUR 500,000'), isFalse, reason: 'it says 1,500,000');
      expect(ok('500,000 in the last'), isFalse);
      expect(ok('at least EUR 1,500,000'), isTrue);
      expect(ok('at least EUR 1.500.000'), isTrue, reason: 'same number');
      expect(ok('ears of experience'), isFalse, reason: 'part of a word');
    });
  });

  group('VerdictGuards', () {
    const g = VerdictGuards();
    final good = [crit('x')];

    test('a rules veto always wins', () {
      final r = g.apply(
        aiVerdict: VerdictKind.bid,
        fitScore: 99,
        confidence: 1,
        criteria: good,
        rules: const RulesResult(
          vetoes: [RuleVeto(rule: VetoRule.deadlinePassed, message: 'late')],
        ),
      );
      expect(r.verdict, VerdictKind.noBid);
    });

    test('low confidence, low fit, unmet criteria, no evidence and '
        'warnings each force REVIEW', () {
      ({VerdictKind verdict, String? reason}) bid({
        double conf = 0.9,
        int fit = 80,
        List<Criterion>? c,
        List<String> warnings = const [],
      }) => g.apply(
        aiVerdict: VerdictKind.bid,
        fitScore: fit,
        confidence: conf,
        criteria: c ?? good,
        rules: RulesResult(vetoes: const [], warnings: warnings),
      );
      expect(bid().verdict, VerdictKind.bid);
      expect(bid(conf: 0.3).verdict, VerdictKind.review);
      expect(bid(fit: 20).verdict, VerdictKind.review);
      expect(bid(c: []).verdict, VerdictKind.review);
      expect(
        bid(c: [crit('x', met: CriterionMet.no)]).verdict,
        VerdictKind.review,
      );
      expect(bid(warnings: ['Deadline unknown.']).verdict, VerdictKind.review);
    });

    test('a confident NO_BID with an unmet requirement stays NO_BID', () {
      final r = g.apply(
        aiVerdict: VerdictKind.noBid,
        fitScore: 10,
        confidence: 0.9,
        criteria: [
          crit('x'),
          crit('y', met: CriterionMet.no),
        ],
        rules: const RulesResult.pass(),
      );
      expect(r.verdict, VerdictKind.noBid);
    });

    test('a NO_BID without an unmet requirement goes to REVIEW', () {
      ({VerdictKind verdict, String? reason}) noBid(List<Criterion> c) =>
          g.apply(
            aiVerdict: VerdictKind.noBid,
            fitScore: 10,
            confidence: 0.9,
            criteria: c,
            rules: const RulesResult.pass(),
          );
      expect(noBid([]).verdict, VerdictKind.review);
      expect(noBid([]).reason, contains('without quoting any evidence'));
      expect(noBid(good).verdict, VerdictKind.review);
      expect(
        noBid([crit('x', met: CriterionMet.unknown)]).verdict,
        VerdictKind.review,
      );
    });

    test('a BID resting on an unknown requirement goes to REVIEW', () {
      final r = g.apply(
        aiVerdict: VerdictKind.bid,
        fitScore: 90,
        confidence: 0.95,
        criteria: [
          crit('x'),
          const Criterion(
            criterion: 'ISO 27001',
            quote: 'q',
            met: CriterionMet.unknown,
          ),
        ],
        rules: const RulesResult.pass(),
      );
      expect(r.verdict, VerdictKind.review);
      expect(r.reason, contains('"ISO 27001"'));
    });

    test('an AI NO_BID with no evidence does not hide the tender', () async {
      final m = FakeModel([
        payload(verdict: VerdictKind.noBid, fit: 10, criteria: []),
      ]);
      final v = await judge(m, tender());
      expect(v.verdict, VerdictKind.review);
      expect(v.status, VerdictStatus.accepted);
    });
  });

  group('BidAgent', () {
    test('accepted BID with verified quotes and audit fields', () async {
      final v = await judge(AlwaysBid(), tender());
      expect(v.verdict, VerdictKind.bid);
      expect(v.status, VerdictStatus.accepted);
      expect(v.criteria.every((c) => c.quoteVerified), isTrue);
      expect(v.model, 'fake-model');
      expect(v.id, startsWith('ai_c1_ted_1-2026_'));
      expect(v.missingDocs, ['ISO 9001 certificate copy']);
    });

    test(
      'unverifiable quotes: one retry, then REVIEW quotes_rejected',
      () async {
        final bad = payload(criteria: [crit('Bidders need ten engineers')]);
        final m = FakeModel([bad, bad]);
        final v = await judge(m, tender());
        expect(m.calls, 2);
        expect(v.verdict, VerdictKind.review);
        expect(v.status, VerdictStatus.quotesRejected);
        expect(v.note, contains('could not be found'));
      },
    );

    test('a good retry after a bad quote is accepted', () async {
      final bad = payload(criteria: [crit('Bidders need ten engineers')]);
      final m = FakeModel([bad, payload()]);
      final v = await judge(m, tender());
      expect(m.calls, 2);
      expect(v.status, VerdictStatus.accepted);
    });

    test('timeouts: 2 retries, then ai_unavailable for a person', () async {
      final m = FakeModel([const Duration(seconds: 1)]);
      final v = await judge(m, tender());
      expect(m.calls, 3);
      expect(v.status, VerdictStatus.aiUnavailable);
      expect(v.verdict, VerdictKind.review);
      expect(v.note, contains('timed out'));
    });

    test('one failure then success is fine', () async {
      final m = FakeModel([Exception('503'), payload()]);
      expect((await judge(m, tender())).status, VerdictStatus.accepted);
    });

    test('never more than 3 model calls per tender in total', () async {
      final bad = payload(criteria: [crit('Bidders need ten engineers')]);
      final m = FakeModel([
        Exception('503'),
        const FormatException('bad json'),
        bad,
        payload(),
      ]);
      final v = await judge(m, tender());
      expect(m.calls, 3);
      expect(v.status, VerdictStatus.quotesRejected);
    });

    test('the quote retry names the quotes that were not found', () async {
      final bad = payload(criteria: [crit('Bidders need ten engineers')]);
      final m = FakeModel([bad, payload()]);
      await judge(m, tender());
      expect(m.rejected, [
        <String>[],
        ['Bidders need ten engineers'],
      ]);
    });

    test('an error after a bad quote still keeps the answer', () async {
      final bad = payload(criteria: [crit('Bidders need ten engineers')]);
      final m = FakeModel([bad, Exception('503')]);
      final v = await judge(m, tender());
      expect(m.calls, 3);
      expect(v.status, VerdictStatus.quotesRejected);
    });

    test('a request limit is not retried and not called daily', () async {
      final m = FakeModel([
        QuotaExceeded('Quota exceeded for requests per minute'),
      ]);
      final v = await judge(m, tender());
      expect(m.calls, 1);
      expect(v.status, VerdictStatus.aiUnavailable);
      expect(v.note, contains('request limit'));
      expect(v.note, isNot(contains('daily')));
    });

    test('malformed answers: one retry, then ai_unavailable', () async {
      final m = FakeModel([const FormatException('bad json')]);
      final v = await judge(m, tender());
      expect(m.calls, 2);
      expect(v.status, VerdictStatus.aiUnavailable);
      expect(v.note, contains('invalid answer'));
    });
  });

  group('AI failures', () {
    test('notice-specific failures are told apart from global ones', () {
      expect(AiFailure.of(const FormatException('bad json')), AiFailure.notice);
      expect(AiFailure.of(TypeError()), AiFailure.notice);
      expect(
        AiFailure.of(
          FirebaseAIException('Candidate was blocked due to recitation'),
        ),
        AiFailure.notice,
      );
      expect(
        AiFailure.of(FirebaseAIException('Response was blocked due to SAFETY')),
        AiFailure.notice,
      );
      expect(
        AiFailure.of(const SocketException('Failed host lookup')),
        AiFailure.offline,
      );
      expect(
        AiFailure.of(
          FirebaseException(plugin: 'firebase_app_check', code: 'unknown'),
        ),
        AiFailure.auth,
      );
      expect(AiFailure.of(Exception('503')), AiFailure.service);
      for (final f in AiFailure.values) {
        expect(f.stopsSync, f != AiFailure.notice);
      }
    });

    test('only an explicit daily limit is called the daily quota', () {
      expect(
        AiFailure.of(QuotaExceeded('Quota exceeded: requests per day')),
        AiFailure.dailyQuota,
      );
      expect(
        AiFailure.of(QuotaExceeded('Quota exceeded: requests per minute')),
        AiFailure.rateLimit,
      );
      expect(
        AiFailure.of(QuotaExceeded('Resource has been exhausted')),
        AiFailure.rateLimit,
      );
    });

    test(
      'a blocked answer: one retry, then ai_unavailable for this notice',
      () async {
        final blocked = FirebaseAIException(
          'Candidate was blocked due to SAFETY',
        );
        final m = FakeModel([blocked]);
        final o = await agent(m).assess(
          company: company,
          profile: profile,
          tender: tender(),
          rules: rulesFor(tender()),
        );
        expect(m.calls, 2);
        expect(o.failure, AiFailure.notice);
        expect(o.verdict.status, VerdictStatus.aiUnavailable);
        expect(o.verdict.note, contains('safety filter'));
      },
    );
  });

  group('Rule integrity: an AI that always says BID', () {
    // Proposal objective: expired or ineligible tenders get 0 BID verdicts.
    final ineligible = {
      'expired': tender(closesIn: const Duration(days: -1)),
      'closes right now': tender(closesIn: Duration.zero),
      'wrong country': tender(country: 'ESP'),
      'wrong sector': tender(cpv: ['45000000']),
    };
    for (final MapEntry(key: name, value: t) in ineligible.entries) {
      test('$name → NO_BID and the AI is never called', () async {
        final m = AlwaysBid();
        final v = await judge(m, t);
        expect(v.verdict, VerdictKind.noBid);
        expect(v.status, VerdictStatus.rulesVeto);
        expect(m.calls, 0);
      });
    }
  });

  group('GeminiModel prompt', () {
    test('contains the profile, the facts and the fenced notice', () {
      final p = GeminiModel.buildPrompt(
        company: company,
        profile: profile,
        tender: tender(),
      );
      expect(p, contains('"name": "Lanka Code Works"'));
      expect(p, contains('Sri Lanka'));
      expect(p, contains('ISO 9001'));
      expect(p, contains('NOTICE (quote only from here):\n<<<\n$notice\n>>>'));
    });

    test('a quote retry lists the rejected quotes', () {
      final p = GeminiModel.buildPrompt(
        company: company,
        profile: profile,
        tender: tender(),
        rejectedQuotes: ['Bidders need ten engineers'],
      );
      expect(p, contains('CORRECTION'));
      expect(p, contains('- "Bidders need ten engineers"'));
      expect(
        GeminiModel.buildPrompt(
          company: company,
          profile: profile,
          tender: tender(),
        ),
        isNot(contains('CORRECTION')),
      );
    });

    test('very long notices are cut', () {
      final long = Tender.fromJson({
        ...tender().toJson(),
        'noticeText': 'a' * (GeminiModel.maxNoticeChars + 500),
      });
      final p = GeminiModel.buildPrompt(
        company: company,
        profile: profile,
        tender: long,
      );
      expect(p.length, lessThan(GeminiModel.maxNoticeChars + 2000));
    });
  });
}
