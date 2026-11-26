import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/models.dart';
import '../../data/providers.dart';
import '../../domain/pipeline/bid_workflow.dart';
import '../auth/auth_providers.dart';
import '../session/session_providers.dart';

/// Every bid of the current company.
final bidsProvider = StreamProvider<List<Bid>>((ref) {
  final companyId = ref.watch(currentCompanyIdProvider).value;
  if (companyId == null) return Stream.value(const []);
  return ref.watch(bidRepositoryProvider).watchBids(companyId);
});

final bidProvider = StreamProvider.family<Bid?, String>(
  (ref, id) => ref.watch(bidRepositoryProvider).watchBid(id),
);

/// The bid for a tender, if the company is tracking it.
final bidForTenderProvider = Provider.family<Bid?, String>((ref, tenderId) {
  final bids = ref.watch(bidsProvider).value ?? const [];
  return bids.where((b) => b.tenderId == tenderId).firstOrNull;
});

final approvalsProvider = StreamProvider<List<Approval>>((ref) {
  final companyId = ref.watch(currentCompanyIdProvider).value;
  if (companyId == null) return Stream.value(const []);
  return ref.watch(bidRepositoryProvider).watchApprovals(companyId);
});

/// Bids waiting for the owner.
final pendingApprovalsProvider = Provider<List<Bid>>((ref) {
  final bids = ref.watch(bidsProvider).value ?? const [];
  return bids.where((b) => b.approval == ApprovalState.pending).toList()
    ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
});

/// All pipeline actions. Each returns an error message, or null on success.
class BidActions extends Notifier<void> {
  @override
  void build() {}

  String? get _uid => ref.read(authStateProvider).value?.uid;
  DateTime get _now => DateTime.now().toUtc();

  Future<String?> watch(Tender t, Verdict? v) {
    final companyId = ref.read(currentCompanyIdProvider).value;
    final uid = _uid;
    if (companyId == null || uid == null) {
      return Future.value('Sign in first.');
    }
    final bid = BidWorkflow.watch(
      companyId: companyId,
      uid: uid,
      tender: t,
      verdict: v,
      now: _now,
    );
    return _run(() => ref.read(bidRepositoryProvider).create(bid));
  }

  Future<String?> requestApproval(Bid b) {
    final uid = _uid;
    if (uid == null) return Future.value('Sign in first.');
    return _change(b, BidWorkflow.requestApproval(b, uid, _now));
  }

  Future<String?> decide(
    Bid b,
    ApprovalDecision decision,
    String note, {
    Verdict? verdict,
  }) async {
    final uid = _uid;
    if (uid == null) return 'Sign in first.';
    if (!BidWorkflow.canDecide(b, ref.read(currentRoleProvider))) {
      return 'Only the owner can approve bids.';
    }
    final v = verdict ?? await _verdictFor(b);
    final now = _now;
    // Decided on the latest copy, inside a transaction: if the other phone
    // changed the bid since this screen loaded, the decision still applies
    // to what is really there, or it is refused.
    return _run(
      () => ref.read(bidRepositoryProvider).decide(b.id, (latest) {
        if (!BidWorkflow.canDecide(latest, UserRole.owner)) {
          throw BidConflict(
            'This bid was already decided on another phone. It is now in '
            '${BidWorkflow.stageLabel(latest.stage)}.',
          );
        }
        return BidWorkflow.decide(
          bid: latest,
          decision: decision,
          ownerUid: uid,
          note: note,
          now: now,
          verdict: v,
        );
      }),
    );
  }

  Future<String?> move(Bid b, BidStage to, {List<String>? reasons}) =>
      _change(b, BidWorkflow.move(b, to, _now, reasons: reasons));

  Future<String?> toggleTask(Bid b, String taskId) =>
      _change(b, BidWorkflow.toggleTask(b, taskId, _now));

  Future<String?> addTask(Bid b, String title) => title.trim().isEmpty
      ? Future.value('Enter a task.')
      : _change(b, BidWorkflow.addTask(b, title, _now));

  Future<String?> remove(Bid b) =>
      _run(() => ref.read(bidRepositoryProvider).delete(b.id));

  Future<Verdict?> _verdictFor(Bid b) async {
    final companyId = ref.read(currentCompanyIdProvider).value;
    if (companyId == null) return null;
    return ref.read(verdictCacheProvider).watchOne(companyId, b.tenderId).first;
  }

  /// Writes only what changed from [before] to [after].
  Future<String?> _change(Bid before, Bid after) => _run(
    () => ref
        .read(bidRepositoryProvider)
        .update(before.id, BidChange.between(before, after)),
  );

  Future<String?> _run(Future<void> Function() f) async {
    try {
      await f().timeout(const Duration(seconds: 15));
      return null;
    } on BidConflict catch (e) {
      return e.message;
    } on FirebaseException catch (e) {
      return e.code == 'permission-denied'
          ? 'You do not have permission to do that.'
          : 'Could not save (${e.code}).';
    } on Object {
      // Offline: Firestore keeps the write and sends it later.
      return null;
    }
  }
}

final bidActionsProvider = NotifierProvider<BidActions, void>(BidActions.new);
