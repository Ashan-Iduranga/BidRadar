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

/// One row per FeedSync run, foreground or background. Drives the feed's
/// "Updated 5 min ago" line and helps debug background runs.
class SyncRuns extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get ranAt => dateTime()();
  IntColumn get added => integer()();
  IntColumn get matched => integer()();
  IntColumn get vetoed => integer()();

  /// JSON list of error lines.
  TextColumn get errors => text()();
  BoolColumn get background => boolean()();
}

@DriftDatabase(tables: [CachedTenders, SyncRuns])
class AppDatabase extends _$AppDatabase {
  /// Shared across isolates so the workmanager isolate and the UI use one
  /// sqlite file safely.
  AppDatabase([QueryExecutor? executor])
    : super(
        executor ??
            driftDatabase(
              name: 'bidradar',
              native: const DriftNativeOptions(shareAcrossIsolates: true),
            ),
      );

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createTable(syncRuns);
    },
  );
}

/// What one FeedSync run did.
class SyncReport {
  const SyncReport({
    required this.ranAt,
    this.fetched = 0,
    this.added = 0,
    this.matched = 0,
    this.vetoed = 0,
    this.duplicates = 0,
    this.errors = const [],
    this.background = false,
  });

  final DateTime ranAt;
  final int fetched;

  /// New tenders stored in the cache.
  final int added;

  /// New tenders that passed every hard rule.
  final int matched;

  /// New tenders vetoed by the rules (recorded as NO_BID).
  final int vetoed;
  final int duplicates;

  /// One line per failure, e.g. "World Bank: no connection".
  final List<String> errors;
  final bool background;
}

/// Reads and writes [SyncRuns].
class SyncLog {
  SyncLog(this._db);
  final AppDatabase _db;

  Future<void> insert(SyncReport r) => _db
      .into(_db.syncRuns)
      .insert(
        SyncRunsCompanion.insert(
          ranAt: r.ranAt.toUtc(),
          added: r.added,
          matched: r.matched,
          vetoed: r.vetoed,
          errors: jsonEncode(r.errors),
          background: r.background,
        ),
      );

  /// The most recent run, or null if sync never ran.
  Stream<SyncReport?> watchLatest() {
    final q = _db.select(_db.syncRuns)
      ..orderBy([(r) => OrderingTerm.desc(r.ranAt)])
      ..limit(1);
    return q.watchSingleOrNull().map(
      (row) => row == null
          ? null
          : SyncReport(
              ranAt: row.ranAt.toUtc(),
              added: row.added,
              matched: row.matched,
              vetoed: row.vetoed,
              errors: List<String>.from(jsonDecode(row.errors) as List),
              background: row.background,
            ),
    );
  }
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

  Stream<Tender?> watchById(String id) =>
      (_db.select(_db.cachedTenders)..where((r) => r.id.equals(id)))
          .watchSingleOrNull()
          .map((row) => row == null ? null : _decode(row));

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
