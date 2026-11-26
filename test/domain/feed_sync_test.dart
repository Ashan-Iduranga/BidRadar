import 'dart:async';

import 'package:bidradar/core/net/resilient_http.dart';
import 'package:bidradar/data/local/app_database.dart';
import 'package:bidradar/data/models/models.dart';
import 'package:bidradar/data/repositories/sync_store.dart';
import 'package:bidradar/data/sources/tender_source.dart';
import 'package:bidradar/domain/agent/ai_model.dart';
import 'package:bidradar/domain/agent/bid_agent.dart';
import 'package:bidradar/domain/sync/feed_sync.dart';
import 'package:drift/native.dart';
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
);

Tender tender(
  String id, {
  TenderSourceType source = TenderSourceType.ted,
  String country = 'LKA',
  List<String> cpv = const ['72200000'],
  Duration closesIn = const Duration(days: 10),
}) => Tender(
  source: source,
  sourceId: id,
  title: 'Tender $id',
  buyer: 'Buyer',
  country: country,
  cpvCodes: cpv,
  deadline: now.add(closesIn),
  noticeText: 'notice $id',
  textHash: 'hash-$source-$id',
  fetchedAt: now,
);

class FakeSource implements TenderSource {
  FakeSource(this.type, this.result);
  @override
  final TenderSourceType type;
  FutureOr<List<Tender>> Function() result;
  int calls = 0;

  @override
  Future<List<Tender>> search(TenderQuery query) async {
    calls++;
    return result();
  }
}

class FakeStore implements SyncStore {
  final tenders = <Tender>[];
  final verdicts = <Verdict>[];
  Object? failWith;
  bool hang = false;

  @override
  Future<void> saveTenders(List<Tender> t) async {
    if (hang) await Completer<void>().future;
    if (failWith != null) throw failWith!;
    tenders.addAll(t);
  }

  @override
  Future<void> recordVerdicts(List<Verdict> v) async {
    if (hang) await Completer<void>().future;
    if (failWith != null) throw failWith!;
    verdicts.addAll(v);
  }
}

void main() {
  late AppDatabase db;
  late TenderCache cache;
  late SyncLog log;
  late FakeStore store;
  late FakeSource ted;
  late FakeSource wb;

  FeedSync sync() => FeedSync(
    sources: [ted, wb],
    cache: cache,
    log: log,
    store: store,
    clock: () => now,
    storeTimeout: const Duration(milliseconds: 50),
  );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    cache = TenderCache(db);
    log = SyncLog(db);
    store = FakeStore();
    ted = FakeSource(
      TenderSourceType.ted,
      () => [
        tender('ok'),
        tender('wrong-country', country: 'ESP'),
        tender('wrong-sector', cpv: ['45000000']),
      ],
    );
    wb = FakeSource(
      TenderSourceType.worldBank,
      () => [tender('wb1', source: TenderSourceType.worldBank, cpv: [])],
    );
  });
  tearDown(() => db.close());

  test('counts added, matched and vetoed tenders', () async {
    final r = await sync().run(company: company, profile: profile);
    expect(r.fetched, 4);
    expect(r.added, 4);
    expect(r.matched, 2); // "ok" and the World Bank one (sector unchecked)
    expect(r.vetoed, 2);
    expect(r.errors, isEmpty);
    expect(await cache.all(), hasLength(4));
  });

  test('only vetoed tenders get rules_veto NO_BID audit verdicts', () async {
    await sync().run(company: company, profile: profile);
    expect(store.tenders, hasLength(4));
    expect(store.verdicts.map((v) => v.tenderId).toSet(), {
      'ted_wrong-country',
      'ted_wrong-sector',
    });
    for (final v in store.verdicts) {
      expect(v.verdict, VerdictKind.noBid);
      expect(v.status, VerdictStatus.rulesVeto);
      expect(v.model, 'rules');
      expect(v.id, 'rules_c1_${v.tenderId}');
      expect(v.rulesResult.passed, isFalse);
    }
  });

  test(
    'a second run with the same data adds nothing and writes nothing',
    () async {
      await sync().run(company: company, profile: profile);
      store.tenders.clear();
      store.verdicts.clear();
      final r = await sync().run(company: company, profile: profile);
      expect(r.added, 0);
      expect(r.matched, 0);
      expect(store.tenders, isEmpty);
      expect(store.verdicts, isEmpty, reason: 'verdicts are append-only');
    },
  );

  test('one failing source is reported; the other still syncs', () async {
    wb.result = () => throw NetworkException('down');
    final r = await sync().run(company: company, profile: profile);
    expect(r.errors, ['World Bank: no connection']);
    expect(r.added, 3);
  });

  test('a Firestore failure keeps the local cache', () async {
    store.failWith = Exception('permission-denied');
    final r = await sync().run(company: company, profile: profile);
    expect(r.errors.single, 'Cloud save: permission denied');
    expect(await cache.all(), hasLength(4));
  });

  test('offline Firestore writes time out instead of hanging', () async {
    store.hang = true;
    final r = await sync().run(company: company, profile: profile);
    expect(r.errors.single, 'Cloud save: queued until online');
    expect(r.added, 4);
  });

  test('a tender that closed earlier today is not new on every sync', () async {
    ted.result = () => [
      tender('ok'),
      tender('closed-today', closesIn: const Duration(hours: -1)),
    ];
    for (var i = 0; i < 3; i++) {
      final r = await sync().run(company: company, profile: profile);
      expect(r.added, i == 0 ? 2 : 0);
      expect(r.vetoed, 0, reason: 'a closed notice is dropped, not vetoed');
    }
    expect(store.verdicts, isEmpty);
    expect(
      (await cache.all()).map((t) => t.sourceId),
      isNot(contains('closed-today')),
    );
  });

  test('closed tenders are pruned from the cache', () async {
    await cache.upsertAll([tender('old', closesIn: const Duration(days: -3))]);
    await sync().run(company: company, profile: profile);
    expect((await cache.all()).map((t) => t.sourceId), isNot(contains('old')));
  });

  test('every run is logged for "Updated … ago"', () async {
    expect(await log.watchLatest().first, isNull);
    await sync().run(company: company, profile: profile, background: true);
    final last = await log.watchLatest().first;
    expect(last!.ranAt, now);
    expect(last.matched, 2);
    expect(last.background, isTrue);
  });

  group('with the AI agent', () {
    late CountingModel model;
    late VerdictCache verdicts;

    FeedSync withAgent({int max = 5}) => FeedSync(
      sources: [ted, wb],
      cache: cache,
      log: log,
      store: store,
      clock: () => now,
      agent: BidAgent(model: model, clock: () => now, sleep: (_) async {}),
      verdicts: verdicts,
      maxAiPerSync: max,
    );

    setUp(() {
      model = CountingModel();
      verdicts = VerdictCache(db);
    });

    test('judges only eligible tenders, up to the per-sync limit', () async {
      final r = await withAgent(max: 1).run(company: company, profile: profile);
      expect(r.judged, 1);
      expect(model.calls, 1);
      // The rest are judged on the next sync.
      final r2 = await withAgent().run(company: company, profile: profile);
      expect(r2.judged, 1);
      expect(model.calls, 2, reason: '2 eligible tenders in total');
    });

    test('reuses a verdict while the notice text is unchanged', () async {
      await withAgent().run(company: company, profile: profile);
      final calls = model.calls;
      final r = await withAgent().run(company: company, profile: profile);
      expect(r.judged, 0);
      expect(model.calls, calls);
    });

    test('AI verdicts go to the audit store', () async {
      await withAgent().run(company: company, profile: profile);
      expect(
        store.verdicts.where((v) => v.status != VerdictStatus.rulesVeto),
        hasLength(2),
      );
    });

    test('an unavailable AI stops the loop and is reported', () async {
      model.fail = true;
      final r = await withAgent().run(company: company, profile: profile);
      expect(r.judged, 1, reason: 'stops after the first failure');
      expect(r.errors.single, startsWith('AI: AI unavailable'));
      // Failed verdicts are not reused: the next sync tries again.
      model.fail = false;
      final r2 = await withAgent().run(company: company, profile: profile);
      expect(r2.judged, 2);
    });

    test('editing the profile gets tenders judged again', () async {
      await withAgent().run(company: company, profile: profile);
      final calls = model.calls;
      const edited = CompanyProfile(
        companyId: 'c1',
        cpvCodes: ['72000000'],
        countries: ['LKA'],
        certifications: ['ISO 27001'],
      );
      final r = await withAgent().run(company: company, profile: edited);
      expect(r.judged, 2);
      expect(model.calls, calls + 2);
      // And then they are reused again.
      final r2 = await withAgent().run(company: company, profile: edited);
      expect(r2.judged, 0);
    });

    test('new tenders go before ones made with an older profile', () async {
      await withAgent(max: 1).run(company: company, profile: profile);
      model.asked.clear();
      const edited = CompanyProfile(
        companyId: 'c1',
        cpvCodes: ['72000000'],
        countries: ['LKA'],
        certifications: ['ISO 27001'],
      );
      await withAgent(max: 1).run(company: company, profile: edited);
      expect(model.asked, ['worldbank_wb1'], reason: 'never judged before');
    });

    test('one notice that fails does not stop the others', () async {
      // ted_ok closes first, so it is asked about first.
      model.failFor = {'ted_ok': const FormatException('bad json')};
      final r = await withAgent().run(company: company, profile: profile);
      expect(r.judged, 2, reason: 'the World Bank tender is still judged');
      expect(
        (await verdicts.reusable('c1', tender('wb1', source: wbType, cpv: []))),
        isNotNull,
      );
      expect(r.errors.single, contains('1 notice(s) could not be judged'));
    });

    test('a failing notice waits behind tenders never asked about', () async {
      model.failFor = {'ted_ok': const FormatException('bad json')};
      await withAgent(max: 1).run(company: company, profile: profile);
      expect(model.asked, ['ted_ok', 'ted_ok'], reason: 'one retry');
      model.asked.clear();
      // Next sync: the World Bank tender was never asked about, so it goes
      // first even though ted_ok closes sooner.
      await withAgent(max: 1).run(company: company, profile: profile);
      expect(model.asked, ['worldbank_wb1']);
    });

    test('a notice that keeps failing is left for a person', () async {
      model.failFor = {'ted_ok': const FormatException('bad json')};
      for (var i = 0; i < FeedSync.maxNoticeFailures + 2; i++) {
        await withAgent().run(company: company, profile: profile);
      }
      // 2 calls per attempt (one retry), and only maxNoticeFailures attempts.
      expect(
        model.asked.where((id) => id == 'ted_ok'),
        hasLength(2 * FeedSync.maxNoticeFailures),
      );
      final e = await verdicts.entry('c1', 'ted_ok');
      expect(e!.failed, isTrue);
      expect(e.failures, FeedSync.maxNoticeFailures);
    });

    test('a quota or connection problem stops the sync', () async {
      model.failFor = {
        'ted_ok': Exception('Quota exceeded for requests per minute'),
      };
      final r = await withAgent().run(company: company, profile: profile);
      expect(r.judged, 1);
      expect(r.errors.single, contains('AI request limit reached'));
      expect(r.errors.single, isNot(contains('daily')));
      // Not the notice's fault: its failure count does not grow.
      expect((await verdicts.entry('c1', 'ted_ok'))!.failures, 0);
    });
  });
}

const wbType = TenderSourceType.worldBank;

class CountingModel implements AiModel {
  int calls = 0;
  bool fail = false;

  /// Tender ID to the error this model throws for it.
  Map<String, Object> failFor = {};

  /// Tender IDs in the order they were asked about.
  final asked = <String>[];

  @override
  String get modelName => 'counting';

  @override
  Future<AiVerdictPayload> judgeTender({
    required Company company,
    required CompanyProfile profile,
    required Tender tender,
    List<String> rejectedQuotes = const [],
  }) async {
    calls++;
    asked.add(tender.id);
    if (fail) throw Exception('quota');
    final f = failFor[tender.id];
    if (f != null) throw f;
    return const AiVerdictPayload(
      verdict: VerdictKind.noBid,
      fitScore: 20,
      confidence: 0.9,
      criteria: [],
      missingDocs: [],
    );
  }
}
