import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/logging/log.dart';
import '../models/models.dart';

/// The Firestore side of a sync: shared tender docs and the verdict audit
/// trail. An interface so FeedSync can be tested without Firebase.
abstract interface class SyncStore {
  Future<void> saveTenders(List<Tender> tenders);

  /// Append-only audit records. A rules veto has a deterministic ID, so the
  /// same veto may come again (from another phone, or after a reinstall);
  /// recording it again is a no-op and never fails the other verdicts.
  Future<void> recordVerdicts(List<Verdict> verdicts);
}

class FirestoreSyncStore implements SyncStore {
  FirestoreSyncStore(this._db);

  final FirebaseFirestore _db;

  /// Firestore allows 500 writes per batch; stay below it.
  static const batchSize = 400;

  @override
  Future<void> saveTenders(List<Tender> tenders) => _write(
    tenders,
    (b, t) => b.set(_db.collection('tenders').doc(t.id), t.toJson()),
  );

  @override
  Future<void> recordVerdicts(List<Verdict> verdicts) async {
    final (:batched, :once) = splitAppendOnly(verdicts);
    final docs = _db.collection('verdicts');
    await Future.wait([
      _write(batched, (b, v) => b.set(docs.doc(v.id), v.toJson())),
      // One write each, so a refusal only affects that record.
      for (final v in once)
        recordOnce(v.id, () => docs.doc(v.id).set(v.toJson())),
    ]);
  }

  /// Rules vetoes have deterministic IDs and may already exist; every other
  /// verdict has a unique ID and can go in a batch.
  static ({List<Verdict> batched, List<Verdict> once}) splitAppendOnly(
    List<Verdict> verdicts,
  ) => (
    batched: [
      for (final v in verdicts)
        if (v.status != VerdictStatus.rulesVeto) v,
    ],
    once: [
      for (final v in verdicts)
        if (v.status == VerdictStatus.rulesVeto) v,
    ],
  );

  /// Writes an audit record whose ID is deterministic. Verdicts are
  /// append-only in the security rules, so writing one that already exists
  /// is an update and is refused with permission-denied. The record is
  /// already there, so that refusal is ignored; any other error is not.
  static Future<void> recordOnce(
    String id,
    Future<void> Function() write,
  ) async {
    try {
      await write();
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      Log.info('sync', 'audit record $id already exists, not rewritten');
    }
  }

  Future<void> _write<T>(
    List<T> items,
    void Function(WriteBatch, T) add,
  ) async {
    for (var i = 0; i < items.length; i += batchSize) {
      final batch = _db.batch();
      for (final item in items.skip(i).take(batchSize)) {
        add(batch, item);
      }
      await batch.commit();
    }
  }
}
