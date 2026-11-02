import 'package:flutter/foundation.dart';

import 'enums.dart';

@immutable
class BidTask {
  const BidTask({
    required this.id,
    required this.title,
    this.assigneeUid,
    this.done = false,
  });

  final String id;
  final String title;
  final String? assigneeUid;
  final bool done;

  BidTask copyWith({bool? done}) => BidTask(
    id: id,
    title: title,
    assigneeUid: assigneeUid,
    done: done ?? this.done,
  );

  factory BidTask.fromJson(Map<String, dynamic> j) => BidTask(
    id: j['id'] as String,
    title: j['title'] as String,
    assigneeUid: j['assigneeUid'] as String?,
    done: j['done'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'assigneeUid': assigneeUid,
    'done': done,
  };
}

/// `bids/{companyId}_{tenderId}`: pipeline state for one tender. Key tender
/// facts are copied in, so the pipeline and deadlines work on every team
/// member's phone even when the tender is not in their local cache.
@immutable
class Bid {
  const Bid({
    required this.id,
    required this.tenderId,
    required this.companyId,
    required this.stage,
    required this.ownerUid,
    required this.updatedAt,
    required this.title,
    required this.buyer,
    this.deadline,
    this.verdict,
    this.fitScore,
    this.approval = ApprovalState.none,
    this.approvalNote = '',
    this.requestedBy,
    this.tasks = const [],
    this.lossReasons = const [],
  });

  static String idFor(String companyId, String tenderId) =>
      '${companyId}_$tenderId';

  final String id;
  final String tenderId;
  final String companyId;
  final BidStage stage;
  final String ownerUid;
  final String title;
  final String buyer;
  final DateTime? deadline;

  /// The AI verdict when the bid was created or last refreshed.
  final VerdictKind? verdict;
  final int? fitScore;

  final ApprovalState approval;

  /// The owner's note on the last decision.
  final String approvalNote;

  /// Who asked the owner for approval.
  final String? requestedBy;
  final List<BidTask> tasks;

  /// Filled when [stage] is [BidStage.lost]; feeds Insights.
  final List<String> lossReasons;
  final DateTime updatedAt;

  int get tasksDone => tasks.where((t) => t.done).length;

  Bid copyWith({
    BidStage? stage,
    ApprovalState? approval,
    String? approvalNote,
    String? Function()? requestedBy,
    List<BidTask>? tasks,
    List<String>? lossReasons,
    VerdictKind? verdict,
    int? fitScore,
    required DateTime updatedAt,
  }) => Bid(
    id: id,
    tenderId: tenderId,
    companyId: companyId,
    stage: stage ?? this.stage,
    ownerUid: ownerUid,
    title: title,
    buyer: buyer,
    deadline: deadline,
    verdict: verdict ?? this.verdict,
    fitScore: fitScore ?? this.fitScore,
    approval: approval ?? this.approval,
    approvalNote: approvalNote ?? this.approvalNote,
    requestedBy: requestedBy == null ? this.requestedBy : requestedBy(),
    tasks: tasks ?? this.tasks,
    lossReasons: lossReasons ?? this.lossReasons,
    updatedAt: updatedAt,
  );

  factory Bid.fromJson(Map<String, dynamic> j) => Bid(
    id: j['id'] as String,
    tenderId: j['tenderId'] as String,
    companyId: j['companyId'] as String,
    stage: BidStage.fromWire(j['stage'] as String),
    ownerUid: j['ownerUid'] as String,
    title: j['title'] as String? ?? 'Untitled tender',
    buyer: j['buyer'] as String? ?? '',
    deadline: j['deadline'] == null
        ? null
        : DateTime.parse(j['deadline'] as String),
    verdict: j['verdict'] == null
        ? null
        : VerdictKind.fromWire(j['verdict'] as String),
    fitScore: j['fitScore'] as int?,
    approval: ApprovalState.fromWire(j['approval'] as String? ?? 'none'),
    approvalNote: j['approvalNote'] as String? ?? '',
    requestedBy: j['requestedBy'] as String?,
    tasks: (j['tasks'] as List? ?? const [])
        .map((e) => BidTask.fromJson(e as Map<String, dynamic>))
        .toList(),
    lossReasons: List<String>.from(j['lossReasons'] as List? ?? const []),
    updatedAt: DateTime.parse(j['updatedAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'tenderId': tenderId,
    'companyId': companyId,
    'stage': stage.wire,
    'ownerUid': ownerUid,
    'title': title,
    'buyer': buyer,
    'deadline': deadline?.toUtc().toIso8601String(),
    'verdict': verdict?.wire,
    'fitScore': fitScore,
    'approval': approval.wire,
    'approvalNote': approvalNote,
    'requestedBy': requestedBy,
    'tasks': tasks.map((e) => e.toJson()).toList(),
    'lossReasons': lossReasons,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}

/// `approvals/{id}`: only the company owner may write these.
@immutable
class Approval {
  const Approval({
    required this.id,
    required this.bidId,
    required this.companyId,
    required this.decision,
    required this.byUid,
    required this.at,
    this.note = '',
  });

  final String id;
  final String bidId;
  final String companyId;
  final ApprovalDecision decision;
  final String byUid;
  final String note;
  final DateTime at;

  factory Approval.fromJson(Map<String, dynamic> j) => Approval(
    id: j['id'] as String,
    bidId: j['bidId'] as String,
    companyId: j['companyId'] as String,
    decision: ApprovalDecision.fromWire(j['decision'] as String),
    byUid: j['by'] as String,
    note: j['note'] as String? ?? '',
    at: DateTime.parse(j['at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'bidId': bidId,
    'companyId': companyId,
    'decision': decision.wire,
    'by': byUid,
    'note': note,
    'at': at.toUtc().toIso8601String(),
  };
}
