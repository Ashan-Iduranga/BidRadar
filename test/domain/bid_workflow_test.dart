import 'package:bidradar/data/models/models.dart';
import 'package:bidradar/domain/pipeline/bid_workflow.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime.utc(2026, 11, 2, 12);

final tender = Tender(
  source: TenderSourceType.ted,
  sourceId: '1-2026',
  title: 'Hospital system',
  buyer: 'Ministry',
  country: 'LKA',
  cpvCodes: const ['72200000'],
  deadline: DateTime.utc(2026, 11, 20),
  noticeText: 'n',
  textHash: 'h',
  fetchedAt: now,
);

final verdict = Verdict(
  id: 'v1',
  tenderId: 'ted_1-2026',
  companyId: 'c1',
  verdict: VerdictKind.bid,
  fitScore: 82,
  criteria: const [
    Criterion(criterion: 'ISO 9001', quote: 'q', met: CriterionMet.yes),
    Criterion(
      criterion: '3 years experience',
      quote: 'q',
      met: CriterionMet.unknown,
    ),
  ],
  missingDocs: const ['Tax clearance certificate', 'Tax clearance certificate'],
  rulesResult: const RulesResult.pass(),
  status: VerdictStatus.accepted,
  model: 'm',
  at: now,
);

Bid watched() => BidWorkflow.watch(
  companyId: 'c1',
  uid: 'manager',
  tender: tender,
  verdict: verdict,
  now: now,
);

void main() {
  test('watching copies tender facts and the verdict', () {
    final b = watched();
    expect(b.id, 'c1_ted_1-2026');
    expect(b.stage, BidStage.watching);
    expect(b.title, 'Hospital system');
    expect(b.deadline, DateTime.utc(2026, 11, 20));
    expect(b.verdict, VerdictKind.bid);
    expect(b.fitScore, 82);
    expect(Bid.fromJson(b.toJson()).toJson(), b.toJson());
  });

  test('a watched bid cannot move on without approval', () {
    expect(BidWorkflow.nextStages(watched()), isEmpty);
    expect(
      () => BidWorkflow.move(watched(), BidStage.preparing, now),
      throwsStateError,
    );
  });

  test('only the owner can decide', () {
    expect(BidWorkflow.canDecide(watched(), UserRole.owner), isTrue);
    expect(BidWorkflow.canDecide(watched(), UserRole.bidManager), isFalse);
    expect(BidWorkflow.canDecide(watched(), null), isFalse);
  });

  test('request → approve moves to Preparing with a checklist', () {
    final asked = BidWorkflow.requestApproval(watched(), 'manager', now);
    expect(asked.approval, ApprovalState.pending);
    expect(asked.requestedBy, 'manager');
    expect(BidWorkflow.canRequestApproval(asked), isFalse);

    final r = BidWorkflow.decide(
      bid: asked,
      decision: ApprovalDecision.approved,
      ownerUid: 'owner',
      note: ' Go ',
      now: now,
      verdict: verdict,
    );
    expect(r.bid.stage, BidStage.preparing);
    expect(r.bid.approval, ApprovalState.approved);
    expect(r.approval.byUid, 'owner');
    expect(r.approval.note, 'Go');
    expect(r.approval.bidId, asked.id);
    expect(r.bid.tasks.map((t) => t.title), [
      'Prepare: Tax clearance certificate', // deduplicated
      'Prove: 3 years experience', // met = unknown
      'Price the offer',
      'Final review and sign',
      'Submit before the deadline',
    ]);
  });

  test('reject keeps the bid in Watching', () {
    final r = BidWorkflow.decide(
      bid: watched(),
      decision: ApprovalDecision.rejected,
      ownerUid: 'owner',
      note: 'Too small',
      now: now,
    );
    expect(r.bid.stage, BidStage.watching);
    expect(r.bid.approval, ApprovalState.rejected);
    expect(r.bid.tasks, isEmpty);
    expect(
      BidWorkflow.canRequestApproval(r.bid),
      isTrue,
      reason: 'can ask again',
    );
  });

  test('preparing → submitted → lost with reasons', () {
    var b = BidWorkflow.decide(
      bid: watched(),
      decision: ApprovalDecision.approved,
      ownerUid: 'owner',
      note: '',
      now: now,
    ).bid;
    expect(BidWorkflow.nextStages(b), [BidStage.submitted]);
    b = BidWorkflow.move(b, BidStage.submitted, now);
    expect(BidWorkflow.nextStages(b), [BidStage.won, BidStage.lost]);
    b = BidWorkflow.move(b, BidStage.lost, now, reasons: ['Price too high']);
    expect(b.lossReasons, ['Price too high']);
    expect(BidWorkflow.nextStages(b), isEmpty);
  });

  test('tasks toggle and add', () {
    var b = BidWorkflow.decide(
      bid: watched(),
      decision: ApprovalDecision.approved,
      ownerUid: 'owner',
      note: '',
      now: now,
    ).bid;
    final first = b.tasks.first.id;
    b = BidWorkflow.toggleTask(b, first, now);
    expect(b.tasksDone, 1);
    b = BidWorkflow.addTask(b, '  Translate CVs ', now);
    expect(b.tasks.last.title, 'Translate CVs');
  });
}
