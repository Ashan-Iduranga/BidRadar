import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../models/models.dart';

part 'app_database.g.dart';

/// Local tender cache for offline reading and dedup. The full [Tender] is
/// stored as JSON; the columns we filter or sort on are copied out.
@TableIndex(name: 'idx_cached_tenders_hash', columns: {#textHash})
@TableIndex(name: 'idx_cached_tenders_deadline', columns: {#deadline})
class CachedTenders extends Table {
  /// `source_sourceId`, same as the Firestore document ID.
  TextColumn get id => text()();
  TextColumn get source => text()();
  TextColumn get sourceId => text()();
  TextColumn get textHash => text()();
  DateTimeColumn get deadline => dateTime().nullable()();
  DateTimeColumn get fetchedAt => dateTime()();
  TextColumn get json => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [CachedTenders])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'bidradar'));

  @override
  int get schemaVersion => 1;
}

/// Result of writing a batch of fetched tenders into the cache.
class CacheWriteResult {
  const CacheWriteResult({
    required this.added,
    required this.updated,
    required this.duplicates,
  });

  /// Never seen before, by ID or by text.
  final List<Tender> added;

  /// Same ID seen before; the cached copy was refreshed.
  final List<Tender> updated;

  /// A different ID with identical notice text (for example the same tender
  /// on two sources). Not stored.
  final List<Tender> duplicates;
}

/// Repository over [AppDatabase]. Dedup key: `source+sourceId`, then
/// `textHash`.
class TenderCache {
  TenderCache(this._db);

  final AppDatabase _db;

  Future<CacheWriteResult> upsertAll(Iterable<Tender> tenders) {
    return _db.transaction(() async {
      final added = <Tender>[];
      final updated = <Tender>[];
      final duplicates = <Tender>[];
      final seenHashes = <String, String>{}; // hash -> id, within this batch

      for (final t in tenders) {
        final existing = await (_db.select(
          _db.cachedTenders,
        )..where((r) => r.id.equals(t.id))).getSingleOrNull();

        if (existing == null) {
          final batchTwin = seenHashes[t.textHash];
          final storedTwin =
              await (_db.select(_db.cachedTenders)
                    ..where((r) => r.textHash.equals(t.textHash))
                    ..limit(1))
                  .getSingleOrNull();
          if (batchTwin != null || storedTwin != null) {
            duplicates.add(t);
            continue;
          }
          added.add(t);
        } else {
          updated.add(t);
        }
        seenHashes[t.textHash] = t.id;
        await _db.into(_db.cachedTenders).insertOnConflictUpdate(_companion(t));
      }
      return CacheWriteResult(
        added: added,
        updated: updated,
        duplicates: duplicates,
      );
    });
  }

  /// Cached tenders, soonest deadline first; unknown deadlines last.
  Stream<List<Tender>> watchAll() {
    final q = _db.select(_db.cachedTenders)
      ..orderBy([
        (r) => OrderingTerm(expression: r.deadline, nulls: NullsOrder.last),
      ]);
    return q.watch().map((rows) => rows.map(_decode).toList());
  }

  Future<List<Tender>> all() => watchAll().first;

  Future<Tender?> byId(String id) async {
    final row = await (_db.select(
      _db.cachedTenders,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
    return row == null ? null : _decode(row);
  }

  /// Removes tenders whose deadline passed before [cutoff].
  Future<int> pruneClosedBefore(DateTime cutoff) => (_db.delete(
    _db.cachedTenders,
  )..where((r) => r.deadline.isSmallerThanValue(cutoff.toUtc()))).go();

  static CachedTendersCompanion _companion(Tender t) => CachedTendersCompanion(
    id: Value(t.id),
    source: Value(t.source.wire),
    sourceId: Value(t.sourceId),
    textHash: Value(t.textHash),
    deadline: Value(t.deadline?.toUtc()),
    fetchedAt: Value(t.fetchedAt.toUtc()),
    json: Value(jsonEncode(t.toJson())),
  );

  static Tender _decode(CachedTender row) =>
      Tender.fromJson(jsonDecode(row.json) as Map<String, dynamic>);
}
