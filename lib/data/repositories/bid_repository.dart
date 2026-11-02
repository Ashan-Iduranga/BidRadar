import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';

/// Bids and approvals in Firestore. Queries always filter on companyId so
/// the security rules (members only) can be checked for the whole query.
abstract interface class BidRepository {
  Stream<List<Bid>> watchBids(String companyId);
  Stream<Bid?> watchBid(String bidId);
  Future<void> save(Bid bid);
  Future<void> delete(String bidId);

  /// Owner only: writes the append-only approval and the updated bid in one
  /// batch, so they never disagree.
  Future<void> decide(Bid bid, Approval approval);
  Stream<List<Approval>> watchApprovals(String companyId);
}

class FirestoreBidRepository implements BidRepository {
  FirestoreBidRepository(this._db);
  final FirebaseFirestore _db;

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
  Future<void> save(Bid bid) => _bids.doc(bid.id).set(bid.toJson());

  @override
  Future<void> delete(String bidId) => _bids.doc(bidId).delete();

  @override
  Future<void> decide(Bid bid, Approval approval) =>
      (_db.batch()
            ..set(_approvals.doc(approval.id), approval.toJson())
            ..set(_bids.doc(bid.id), bid.toJson()))
          .commit();

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
}
