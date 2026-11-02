import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';

/// The Firestore side of a sync: shared tender docs and the verdict audit
/// trail. An interface so FeedSync can be tested without Firebase.
abstract interface class SyncStore {
  Future<void> saveTenders(List<Tender> tenders);

  /// Append-only audit records. IDs are deterministic, so callers must only
  /// pass verdicts that were never written before.
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
  Future<void> recordVerdicts(List<Verdict> verdicts) => _write(
    verdicts,
    (b, v) => b.set(_db.collection('verdicts').doc(v.id), v.toJson()),
  );

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
