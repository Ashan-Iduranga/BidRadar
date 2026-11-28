import '../../data/models/models.dart';

/// Pipeline rules in plain Dart, shared by the Pipeline, Bid and Approvals
/// pages and unit tested. Firestore rules enforce the security side (only
/// the owner writes approvals); this enforces the workflow.
abstract final class BidWorkflow {
  /// Reasons offered when a bid is marked lost. Insights groups by these.
  static const lossReasons = [
    'Price too high',
    'Did not meet a requirement',
    'Weaker technical offer',
    'Missed the deadline',
    'Buyer cancelled',
    'Other',
  ];

  /// A new bid from a tender, in Watching.
  static Bid watch({
    required String companyId,
    required String uid,
    required Tender tender,
    Verdict? verdict,
    required DateTime now,
  }) => Bid(
    id: Bid.idFor(companyId, tender.id),
    tenderId: tender.id,
    companyId: companyId,
    stage: BidStage.watching,
    ownerUid: uid,
    title: tender.title,
    buyer: tender.buyer,
    deadline: tender.deadline,
    verdict: verdict?.verdict,
    fitScore: verdict?.status == VerdictStatus.accepted
        ? verdict?.fitScore
        : null,
    updatedAt: now,
    createdAt: now,
  );

  /// Stages a bid can move to next, for [role]. Moving to Preparing needs
  /// the owner's approval, so it is not a plain move.
  static List<BidStage> nextStages(Bid b) => switch (b.stage) {
    BidStage.watching => const [],
    BidStage.preparing => const [BidStage.submitted],
    BidStage.submitted => const [BidStage.won, BidStage.lost],
    BidStage.won || BidStage.lost => const [],
  };

  /// A bid manager asks; the owner decides (or approves directly).
  static bool canRequestApproval(Bid b) =>
      b.stage == BidStage.watching && b.approval != ApprovalState.pending;

  static bool canDecide(Bid b, UserRole? role) =>
      role == UserRole.owner &&
      b.stage == BidStage.watching &&
      b.approval != ApprovalState.approved;

  static Bid requestApproval(Bid b, String uid, DateTime now) => b.copyWith(
    approval: ApprovalState.pending,
    requestedBy: () => uid,
    updatedAt: now,
  );

  /// The owner's decision. Approval moves the bid to Preparing with a
  /// checklist built from [verdict]; rejection keeps it in Watching.
  static ({Bid bid, Approval approval}) decide({
    required Bid bid,
    required ApprovalDecision decision,
    required String ownerUid,
    required String note,
    required DateTime now,
    Verdict? verdict,
  }) {
    final approved = decision == ApprovalDecision.approved;
    final updated = bid.copyWith(
      approval: approved ? ApprovalState.approved : ApprovalState.rejected,
      approvalNote: note.trim(),
      stage: approved ? BidStage.preparing : bid.stage,
      tasks: approved && bid.tasks.isEmpty ? checklist(verdict) : bid.tasks,
      updatedAt: now,
    );
    return (
      bid: updated,
      approval: Approval(
        id: '${bid.id}_${now.millisecondsSinceEpoch}',
        bidId: bid.id,
        companyId: bid.companyId,
        decision: decision,
        byUid: ownerUid,
        note: note.trim(),
        at: now,
      ),
    );
  }

  /// Document checklist: what the AI said is missing, plus proof for every
  /// criterion not clearly met, plus the always-needed final steps.
  static List<BidTask> checklist(Verdict? v) {
    final titles = <String>[
      ...?v?.missingDocs.map((d) => 'Prepare: $d'),
      ...?v?.criteria
          .where((c) => c.met != CriterionMet.yes)
          .map((c) => 'Prove: ${c.criterion}'),
      'Price the offer',
      'Final review and sign',
      'Submit before the deadline',
    ];
    final seen = <String>{};
    var i = 0;
    return [
      for (final t in titles)
        if (seen.add(t.toLowerCase())) BidTask(id: 't${i++}', title: t),
    ];
  }

  static Bid move(Bid b, BidStage to, DateTime now, {List<String>? reasons}) {
    if (!nextStages(b).contains(to)) {
      throw StateError('Cannot move ${b.stage.wire} to ${to.wire}');
    }
    return b.copyWith(
      stage: to,
      lossReasons: to == BidStage.lost ? (reasons ?? const []) : null,
      updatedAt: now,
    );
  }

  static Bid toggleTask(Bid b, String taskId, DateTime now) => b.copyWith(
    tasks: [
      for (final t in b.tasks) t.id == taskId ? t.copyWith(done: !t.done) : t,
    ],
    updatedAt: now,
  );

  static Bid addTask(Bid b, String title, DateTime now) => b.copyWith(
    tasks: [
      ...b.tasks,
      BidTask(id: 't${now.microsecondsSinceEpoch}', title: title.trim()),
    ],
    updatedAt: now,
  );

  static String stageLabel(BidStage s) => switch (s) {
    BidStage.watching => 'Watching',
    BidStage.preparing => 'Preparing',
    BidStage.submitted => 'Submitted',
    BidStage.won => 'Won',
    BidStage.lost => 'Lost',
  };
}
