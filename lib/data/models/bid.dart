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
///
/// Ticks are stored in a `taskDone` map (task ID to done) next to the
/// `tasks` list, so 2 people ticking different tasks write different
/// fields and neither tick is lost. The list's own `done` flags are kept
/// for bids written before the map existed.
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
    this.createdAt,
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

  /// When the bid was created. Never changes, so the rules can refuse a
  /// write that would replace an existing bid with a fresh one. Null on
  /// bids created before this field existed.
  final DateTime? createdAt;

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
    createdAt: createdAt,
  );

  factory Bid.fromJson(Map<String, dynamic> j) {
    final done = (j['taskDone'] as Map?) ?? const {};
    return Bid(
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
      tasks: [
        for (final e in j['tasks'] as List? ?? const [])
          _withTick(BidTask.fromJson(e as Map<String, dynamic>), done),
      ],
      lossReasons: List<String>.from(j['lossReasons'] as List? ?? const []),
      updatedAt: DateTime.parse(j['updatedAt'] as String),
      createdAt: j['createdAt'] == null
          ? null
          : DateTime.parse(j['createdAt'] as String),
    );
  }

  static BidTask _withTick(BidTask t, Map<dynamic, dynamic> done) =>
      switch (done[t.id]) {
        final bool d => t.copyWith(done: d),
        _ => t,
      };

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
    'taskDone': {for (final t in tasks) t.id: t.done},
    'lossReasons': lossReasons,
    'createdAt': createdAt?.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}

/// The part of a bid one action changes. Repositories write only this, so
/// what another phone changed meanwhile (other fields, other tasks) is
/// kept instead of being overwritten by the copy on this screen.
@immutable
class BidChange {
  const BidChange({
    this.fields = const {},
    this.addedTasks = const [],
    this.taskDone = const {},
  });

  /// Top-level fields by their Firestore name, with their new JSON values.
  final Map<String, Object?> fields;

  /// Tasks to append to the checklist.
  final List<BidTask> addedTasks;

  /// Task ID to its new done state.
  final Map<String, bool> taskDone;

  bool get isEmpty => fields.isEmpty && addedTasks.isEmpty && taskDone.isEmpty;

  /// What changed from [before] to [after]. Tasks can be added or ticked;
  /// removing one is not a field-level change and throws.
  factory BidChange.between(Bid before, Bid after) {
    if (before.id != after.id) {
      throw ArgumentError('${before.id} and ${after.id} are different bids');
    }
    final a = before.toJson()
      ..remove('tasks')
      ..remove('taskDone');
    final b = after.toJson()
      ..remove('tasks')
      ..remove('taskDone');
    final old = {for (final t in before.tasks) t.id: t};
    final added = <BidTask>[];
    final ticks = <String, bool>{};
    for (final t in after.tasks) {
      final o = old[t.id];
      if (o == null) {
        added.add(t);
      } else if (o.done != t.done) {
        ticks[t.id] = t.done;
      }
    }
    if (after.tasks.length - added.length != before.tasks.length) {
      throw ArgumentError('Tasks can only be added or ticked.');
    }
    return BidChange(
      fields: {
        for (final k in b.keys)
          if (!_same(a[k], b[k])) k: b[k],
      },
      addedTasks: added,
      taskDone: ticks,
    );
  }

  static bool _same(Object? x, Object? y) =>
      x is List && y is List ? listEquals(x, y) : x == y;
}

/// The bid changed on another phone (or was removed) so the action no
/// longer applies. [message] is shown as it is.
class BidConflict implements Exception {
  const BidConflict(this.message);
  final String message;

  @override
  String toString() => message;
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
