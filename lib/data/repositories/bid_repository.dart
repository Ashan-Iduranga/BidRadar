import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';

/// Bids and approvals in Firestore. Queries always filter on companyId so
/// the security rules (members only) can be checked for the whole query.
///
/// Writes never send the whole bid from the copy on screen: [update] sends
/// only the changed fields, and [decide] re-reads the bid in a transaction.
/// So a change made on the other phone a moment earlier is not undone.
abstract interface class BidRepository {
  Stream<List<Bid>> watchBids(String companyId);
  Stream<Bid?> watchBid(String bidId);

  /// Adds a new bid. It never replaces an existing one: the rules refuse a
  /// write that changes `createdAt`.
  Future<void> create(Bid bid);

  /// Writes only the fields in [change]. Works offline: Firestore keeps the
  /// write and sends it later.
  Future<void> update(String bidId, BidChange change);

  Future<void> delete(String bidId);

  /// Owner only. Runs [decision] on the latest copy of the bid inside a
  /// transaction, then writes the changed fields and the append-only
  /// approval record together. [decision] throws [BidConflict] when the
  /// latest copy can no longer be decided. Needs a connection.
  Future<void> decide(
    String bidId,
    ({Bid bid, Approval approval}) Function(Bid latest) decision,
  );

  Stream<List<Approval>> watchApprovals(String companyId);
}

class FirestoreBidRepository implements BidRepository {
  FirestoreBidRepository(this._db);
  final FirebaseFirestore _db;

  /// How long a decision may wait for the server before it gives up.
  static const decideTimeout = Duration(seconds: 10);

  CollectionReference<Map<String, dynamic>> get _bids => _db.collection('bids');
  CollectionReference<Map<String, dynamic>> get _approvals =>
      _db.collection('approvals');

  @override
  Stream<List<Bid>> watchBids(String companyId) => _bids
      .where('companyId', isEqualTo: companyId)
      .snapshots()
      .map((s) => [for (final d in s.docs) Bid.fromJson(d.data())]);

  @override
  Stream<Bid?> watchBid(String bidId) => _bids.doc(bidId).snapshots().map((s) {
    final d = s.data();
    return d == null ? null : Bid.fromJson(d);
  });

  @override
  Future<void> create(Bid bid) => _bids.doc(bid.id).set(bid.toJson());

  @override
  Future<void> update(String bidId, BidChange change) async {
    if (change.isEmpty) return;
    await _bids.doc(bidId).update(fieldsOf(change));
  }

  @override
  Future<void> delete(String bidId) => _bids.doc(bidId).delete();

  @override
  Future<void> decide(
    String bidId,
    ({Bid bid, Approval approval}) Function(Bid latest) decision,
  ) => _db.runTransaction((tx) async {
    final ref = _bids.doc(bidId);
    final data = (await tx.get(ref)).data();
    if (data == null) {
      throw const BidConflict('This bid was removed from the pipeline.');
    }
    final latest = Bid.fromJson(data);
    final r = decision(latest);
    tx
      ..update(ref, fieldsOf(BidChange.between(latest, r.bid)))
      ..set(_approvals.doc(r.approval.id), r.approval.toJson());
  }, timeout: decideTimeout);

  /// Newest first. Sorted here, not in the query, so no composite index is
  /// needed.
  @override
  Stream<List<Approval>> watchApprovals(String companyId) => _approvals
      .where('companyId', isEqualTo: companyId)
      .snapshots()
      .map(
        (s) =>
            [for (final d in s.docs) Approval.fromJson(d.data())]
              ..sort((a, b) => b.at.compareTo(a.at)),
      );

  /// The Firestore update for [change]: changed fields as they are, ticks
  /// as `taskDone.<id>` field paths and new tasks as an array union, so
  /// concurrent ticks and additions on 2 phones all survive.
  static Map<Object, Object?> fieldsOf(BidChange change) => {
    ...change.fields,
    for (final e in change.taskDone.entries)
      FieldPath(['taskDone', e.key]): e.value,
    if (change.addedTasks.isNotEmpty)
      'tasks': FieldValue.arrayUnion([
        for (final t in change.addedTasks) t.toJson(),
      ]),
  };
}
