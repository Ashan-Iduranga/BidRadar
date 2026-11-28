import 'dart:convert';

import 'package:bidradar/data/local/app_database.dart';
import 'package:bidradar/data/models/models.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// The tables exactly as schema version 3 created them.
const _v3 = [
  'CREATE TABLE "cached_tenders" ("id" TEXT NOT NULL, "source" TEXT NOT NULL, '
      '"source_id" TEXT NOT NULL, "text_hash" TEXT NOT NULL, "deadline" '
      'INTEGER NULL, "fetched_at" INTEGER NOT NULL, "json" TEXT NOT NULL, '
      'PRIMARY KEY ("id"))',
  'CREATE TABLE "sync_runs" ("id" INTEGER NOT NULL PRIMARY KEY '
      'AUTOINCREMENT, "ran_at" INTEGER NOT NULL, "added" INTEGER NOT NULL, '
      '"matched" INTEGER NOT NULL, "vetoed" INTEGER NOT NULL, "errors" TEXT '
      'NOT NULL, "background" INTEGER NOT NULL CHECK ("background" IN (0, 1)))',
  'CREATE TABLE "cached_verdicts" ("company_id" TEXT NOT NULL, "tender_id" '
      'TEXT NOT NULL, "text_hash" TEXT NOT NULL, "at" INTEGER NOT NULL, '
      '"json" TEXT NOT NULL, PRIMARY KEY ("company_id", "tender_id"))',
  'CREATE INDEX idx_cached_tenders_hash ON cached_tenders (text_hash)',
  'CREATE INDEX idx_cached_tenders_deadline ON cached_tenders (deadline)',
];

final _verdict = Verdict(
  id: 'ai_c1_ted_1_1',
  tenderId: 'ted_1',
  companyId: 'c1',
  verdict: VerdictKind.bid,
  fitScore: 80,
  confidence: 0.9,
  criteria: const [],
  missingDocs: const [],
  rulesResult: const RulesResult.pass(),
  status: VerdictStatus.accepted,
  model: 'm',
  at: DateTime.utc(2026, 11, 2),
);

/// Opens an in-memory database that starts as schema [version] (3 or 4)
/// with one cached verdict, then lets AppDatabase migrate it.
AppDatabase _oldDatabase(int version) => AppDatabase(
  NativeDatabase.memory(
    setup: (raw) {
      if (raw.userVersion != 0) return;
      for (final sql in _v3) {
        raw.execute(sql);
      }
      if (version >= 4) {
        raw.execute(
          'ALTER TABLE cached_verdicts ADD COLUMN '
          '"failures" INTEGER NOT NULL DEFAULT 0',
        );
      }
      raw.execute(
        'INSERT INTO cached_verdicts '
        '(company_id, tender_id, text_hash, at, json) VALUES (?, ?, ?, ?, ?)',
        [
          'c1',
          'ted_1',
          'hash-1',
          DateTime.utc(2026, 11, 2).millisecondsSinceEpoch ~/ 1000,
          jsonEncode(_verdict.toJson()),
        ],
      );
      raw.userVersion = version;
    },
  ),
);

void main() {
  for (final version in [3, 4]) {
    test(
      'a version $version cache keeps its verdicts after the upgrade',
      () async {
        final db = _oldDatabase(version);
        addTearDown(db.close);

        final e = await VerdictCache(db).entry('c1', 'ted_1');
        expect(e, isNotNull, reason: 'the row survives the migration');
        expect(e!.verdict.verdict, VerdictKind.bid);
        expect(e.textHash, 'hash-1');
        expect(e.failures, 0);
        expect(e.profileHash, isNull, reason: 'made before fingerprints');
      },
    );
  }
}
