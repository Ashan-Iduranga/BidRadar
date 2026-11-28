import 'package:bidradar/data/models/models.dart';
import 'package:bidradar/domain/pipeline/bid_workflow.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime.utc(2026, 11, 26, 9);
final later = now.add(const Duration(minutes: 1));

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

Bid watched() => BidWorkflow.watch(
  companyId: 'c1',
  uid: 'manager',
  tender: tender,
  now: now,
);

Bid approved() => BidWorkflow.decide(
  bid: watched(),
  decision: ApprovalDecision.approved,
  ownerUid: 'owner',
  note: 'Go',
  now: now,
).bid;

/// Applies [c] to a stored bid the way Firestore's update() does: fields
/// replaced, `taskDone.<id>` paths set, new tasks appended.
Map<String, dynamic> apply(Map<String, dynamic> stored, BidChange c) => {
  ...stored,
  ...c.fields,
  'taskDone': {...?stored['taskDone'] as Map?, ...c.taskDone},
  'tasks': [
    ...stored['tasks'] as List,
    for (final t in c.addedTasks) t.toJson(),
  ],
};

void main() {
  test('asking for approval writes only the approval fields', () {
    final b = watched();
    final c = BidChange.between(
      b,
      BidWorkflow.requestApproval(b, 'manager', later),
    );
    expect(
      c.fields.keys,
      unorderedEquals(['approval', 'requestedBy', 'updatedAt']),
    );
    expect(c.fields['approval'], 'pending');
    expect(c.addedTasks, isEmpty);
    expect(c.taskDone, isEmpty);
  });

  test('a tick writes only that task, not the list', () {
    final b = approved();
    final c = BidChange.between(b, BidWorkflow.toggleTask(b, 't1', later));
    expect(c.taskDone, {'t1': true});
    expect(c.addedTasks, isEmpty);
    expect(c.fields.keys, ['updatedAt']);
  });

  test('2 people ticking different tasks keep both ticks', () {
    final onScreen = approved();
    var stored = onScreen.toJson();
    // Both phones tick from the same copy, one after the other.
    stored = apply(
      stored,
      BidChange.between(
        onScreen,
        BidWorkflow.toggleTask(onScreen, 't0', later),
      ),
    );
    stored = apply(
      stored,
      BidChange.between(
        onScreen,
        BidWorkflow.toggleTask(onScreen, 't2', later),
      ),
    );
    final merged = Bid.fromJson(stored);
    expect(
      [
        for (final t in merged.tasks)
          if (t.done) t.id,
      ],
      ['t0', 't2'],
    );
  });

  test('adding a task appends it', () {
    final b = approved();
    final c = BidChange.between(
      b,
      BidWorkflow.addTask(b, 'Translate CVs', later),
    );
    expect(c.addedTasks.single.title, 'Translate CVs');
    expect(c.taskDone, isEmpty);
    expect(c.fields.keys, ['updatedAt']);
  });

  test('an approval moves the stage and adds the checklist', () {
    final b = watched();
    final c = BidChange.between(b, approved());
    expect(
      c.fields.keys,
      unorderedEquals(['stage', 'approval', 'approvalNote']),
      reason: 'decide() keeps updatedAt from the same clock here',
    );
    expect(c.fields['stage'], 'preparing');
    expect(c.addedTasks, isNotEmpty);
    expect(c.fields.containsKey('createdAt'), isFalse);
  });

  test('moving to Lost sends the stage and the reasons', () {
    var b = BidWorkflow.move(approved(), BidStage.submitted, now);
    final c = BidChange.between(
      b,
      BidWorkflow.move(b, BidStage.lost, later, reasons: ['Other']),
    );
    expect(
      c.fields.keys,
      unorderedEquals(['stage', 'lossReasons', 'updatedAt']),
    );
    b = Bid.fromJson(apply(b.toJson(), c));
    expect(b.lossReasons, ['Other']);
  });

  test('removing a task is not a field-level change', () {
    final b = approved();
    final fewer = Bid.fromJson({
      ...b.toJson(),
      'tasks': [for (final t in b.tasks.skip(1)) t.toJson()],
    });
    expect(() => BidChange.between(b, fewer), throwsArgumentError);
  });

  test('ticks override the flags of bids written before taskDone', () {
    final legacy = approved().toJson()
      ..remove('taskDone')
      ..remove('createdAt');
    (legacy['tasks'] as List).first['done'] = true;
    expect(Bid.fromJson(legacy).tasks.first.done, isTrue);
    expect(Bid.fromJson(legacy).createdAt, isNull);
    final unticked = Bid.fromJson({
      ...legacy,
      'taskDone': {'t0': false},
    });
    expect(unticked.tasks.first.done, isFalse);
  });

  test('a new bid records when it was created', () {
    expect(watched().createdAt, now);
    expect(Bid.fromJson(watched().toJson()).createdAt, now);
  });
}
