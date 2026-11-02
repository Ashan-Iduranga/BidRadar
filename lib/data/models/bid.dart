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

/// `bids/{id}`: pipeline state for one tender.
@immutable
class Bid {
  const Bid({
    required this.id,
    required this.tenderId,
    required this.companyId,
    required this.stage,
    required this.ownerUid,
    required this.updatedAt,
    this.tasks = const [],
    this.lossReasons = const [],
  });

  final String id;
  final String tenderId;
  final String companyId;
  final BidStage stage;
  final String ownerUid;
  final List<BidTask> tasks;

  /// Filled when [stage] is [BidStage.lost]; feeds Insights.
  final List<String> lossReasons;
  final DateTime updatedAt;

  factory Bid.fromJson(Map<String, dynamic> j) => Bid(
    id: j['id'] as String,
    tenderId: j['tenderId'] as String,
    companyId: j['companyId'] as String,
    stage: BidStage.fromWire(j['stage'] as String),
    ownerUid: j['ownerUid'] as String,
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
