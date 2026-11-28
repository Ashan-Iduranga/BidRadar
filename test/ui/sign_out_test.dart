import 'package:bidradar/data/local/app_database.dart';
import 'package:bidradar/data/models/models.dart';
import 'package:bidradar/ui/auth/auth_providers.dart';
import 'package:drift/native.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime.utc(2026, 11, 26, 9);

final tender = Tender(
  source: TenderSourceType.ted,
  sourceId: '1-2026',
  title: 'Hospital system',
  buyer: 'Ministry',
  country: 'LKA',
  cpvCodes: const ['72200000'],
  deadline: DateTime.utc(2026, 12, 20),
  noticeText: 'n',
  textHash: 'h',
  fetchedAt: now,
);

final verdict = Verdict(
  id: 'v1',
  tenderId: tender.id,
  companyId: 'c1',
  verdict: VerdictKind.bid,
  fitScore: 80,
  criteria: const [],
  missingDocs: const [],
  rulesResult: const RulesResult.pass(),
  status: VerdictStatus.accepted,
  model: 'm',
  at: now,
);

/// Records the order of calls.
class FakeFirebaseAuth extends Fake implements FirebaseAuth {
  FakeFirebaseAuth(this.calls);
  final List<String> calls;

  @override
  Future<void> signOut() async => calls.add('signOut');
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await TenderCache(db).upsertAll([tender]);
    await VerdictCache(db).put(verdict, textHash: tender.textHash);
    await SyncLog(db).insert(SyncReport(ranAt: now));
  });
  tearDown(() => db.close());

  test(
    "clearing removes the previous user's tenders, verdicts and log",
    () async {
      await clearLocalData(db);

      expect(await TenderCache(db).all(), isEmpty);
      expect(await VerdictCache(db).watchForCompany('c1').first, isEmpty);
      expect(await SyncLog(db).watchLatest().first, isNull);
    },
  );

  test('sign-out clears the phone first, then signs out', () async {
    final calls = <String>[];
    final auth = FirebaseAuthService(FakeFirebaseAuth(calls), () async {
      calls.add('clear');
      await clearLocalData(db);
    });

    await auth.signOut();

    expect(calls, ['clear', 'signOut']);
    expect(await TenderCache(db).all(), isEmpty);
  });

  test('sign-out still signs out when clearing fails', () async {
    final calls = <String>[];
    final auth = FirebaseAuthService(
      FakeFirebaseAuth(calls),
      () => Future.error(StateError('disk full')),
    );

    await auth.signOut();

    expect(calls, ['signOut']);
  });
}
