import 'package:bidradar/data/local/app_database.dart';
import 'package:bidradar/data/models/models.dart';
import 'package:bidradar/data/providers.dart';
import 'package:bidradar/data/repositories/bid_repository.dart';
import 'package:bidradar/domain/pipeline/bid_workflow.dart';
import 'package:bidradar/ui/auth/auth_providers.dart';
import 'package:bidradar/ui/pipeline/pipeline_view_model.dart';
import 'package:bidradar/ui/session/session_providers.dart';
import 'package:drift/native.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime.utc(2026, 11, 26, 9);

class FakeUser extends Fake implements User {
  @override
  String get uid => 'owner';
}

/// Stores bids in memory and runs decisions on the stored copy, like the
/// Firestore transaction does.
class FakeBidRepository extends Fake implements BidRepository {
  final bids = <String, Bid>{};
  final approvals = <Approval>[];
  Object? failWith;

  @override
  Future<void> decide(
    String bidId,
    ({Bid bid, Approval approval}) Function(Bid latest) decision,
  ) async {
    if (failWith case final e?) throw e;
    final r = decision(bids[bidId]!);
    bids[bidId] = r.bid;
    approvals.add(r.approval);
  }

  @override
  Future<void> update(String bidId, BidChange change) async {
    if (failWith case final e?) throw e;
  }
}

class FakeSharedRecords implements SharedRecords {
  FakeSharedRecords({this.tenders = const {}, this.verdicts = const {}});
  final Map<String, Tender> tenders;
  final Map<String, Verdict> verdicts;

  @override
  Future<Tender?> tender(String tenderId) async => tenders[tenderId];

  @override
  Future<Verdict?> latestVerdict(String companyId, String tenderId) async =>
      verdicts[tenderId];
}

final scanned = Tender(
  source: TenderSourceType.scan,
  sourceId: 'abcdef0123456789',
  title: 'Road repair',
  buyer: 'Council',
  country: 'LKA',
  cpvCodes: const ['45000000'],
  deadline: DateTime.utc(2026, 12, 20),
  noticeText: 'Scanned notice',
  textHash: 'abcdef0123456789ffff',
  fetchedAt: now,
);

final verdict = Verdict(
  id: 'ai_c1_scan_1',
  tenderId: scanned.id,
  companyId: 'c1',
  verdict: VerdictKind.bid,
  fitScore: 80,
  criteria: const [],
  missingDocs: const ['Road safety plan'],
  rulesResult: const RulesResult.pass(),
  status: VerdictStatus.accepted,
  model: 'm',
  at: now,
);

/// A bid the bid manager made from the scan and asked about.
Bid pending() => BidWorkflow.requestApproval(
  BidWorkflow.watch(companyId: 'c1', uid: 'bm', tender: scanned, now: now),
  'bm',
  now,
);

({ProviderContainer c, AppDatabase db}) ownerPhone(
  BidRepository bids,
  SharedRecords shared,
) {
  final db = AppDatabase(NativeDatabase.memory());
  final c = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      authStateProvider.overrideWith((ref) => Stream.value(FakeUser())),
      currentCompanyIdProvider.overrideWith((ref) => Stream.value('c1')),
      currentRoleProvider.overrideWithValue(UserRole.owner),
      bidRepositoryProvider.overrideWithValue(bids),
      sharedRecordsProvider.overrideWithValue(shared),
    ],
  );
  addTearDown(() async {
    c.dispose();
    await db.close();
  });
  return (c: c, db: db);
}

Future<void> signedIn(ProviderContainer c) async {
  c.listen(authStateProvider, (_, _) {});
  c.listen(currentCompanyIdProvider, (_, _) {});
  await c.read(authStateProvider.future);
  await c.read(currentCompanyIdProvider.future);
}

void main() {
  test('opening a tender scanned on the other phone fetches it', () async {
    final phone = ownerPhone(
      FakeBidRepository(),
      FakeSharedRecords(
        tenders: {scanned.id: scanned},
        verdicts: {scanned.id: verdict},
      ),
    );
    await signedIn(phone.c);

    await phone.c.read(bidActionsProvider.notifier).loadTender(pending());

    final cached = await phone.c.read(tenderCacheProvider).byId(scanned.id);
    expect(cached?.title, 'Road repair');
    final v = await phone.c
        .read(verdictCacheProvider)
        .watchOne('c1', scanned.id)
        .first;
    expect(v?.missingDocs, ['Road safety plan']);
  });

  test('the checklist uses the verdict from the other phone', () async {
    final bids = FakeBidRepository()..bids[pending().id] = pending();
    final phone = ownerPhone(
      bids,
      FakeSharedRecords(verdicts: {scanned.id: verdict}),
    );
    await signedIn(phone.c);

    final error = await phone.c
        .read(bidActionsProvider.notifier)
        .decide(pending(), ApprovalDecision.approved, 'Go');

    expect(error, isNull);
    final approved = bids.bids[pending().id]!;
    expect(approved.stage, BidStage.preparing);
    expect(approved.tasks.first.title, 'Prepare: Road safety plan');
  });

  test(
    'a bid already decided on the other phone is not decided again',
    () async {
      final bids = FakeBidRepository();
      final phone = ownerPhone(bids, FakeSharedRecords());
      await signedIn(phone.c);
      // The owner's other device approved it a moment ago.
      bids.bids[pending().id] = BidWorkflow.decide(
        bid: pending(),
        decision: ApprovalDecision.approved,
        ownerUid: 'owner',
        note: '',
        now: now,
      ).bid;

      final error = await phone.c
          .read(bidActionsProvider.notifier)
          .decide(pending(), ApprovalDecision.rejected, 'No');

      expect(error, contains('already decided on another phone'));
      expect(bids.approvals, isEmpty);
      expect(bids.bids[pending().id]!.approval, ApprovalState.approved);
    },
  );
}
