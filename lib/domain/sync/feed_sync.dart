import 'dart:async';

import '../../core/logging/log.dart';
import '../../core/net/resilient_http.dart';
import '../../data/local/app_database.dart';
import '../../data/models/models.dart';
import '../../data/repositories/sync_store.dart';
import '../../data/sources/tender_source.dart';
import '../agent/bid_agent.dart';
import '../rules/eligibility_rules.dart';

/// The feed pipeline: fetch → dedup → hard rules → store.
/// Shared by "Sync now" in the UI and the workmanager background task.
/// Tenders vetoed by the rules are recorded as NO_BID and never reach the
/// AI (Phase 3 sends only the matched ones).
class FeedSync {
  FeedSync({
    required this.sources,
    required this.cache,
    required this.log,
    required this.store,
    this.agent,
    this.verdicts,
    this.maxAiPerSync = 5,
    this.rules = const EligibilityRules(),
    DateTime Function()? clock,
    this.limitPerSource = 30,
    this.storeTimeout = const Duration(seconds: 20),
  }) : _clock = clock ?? DateTime.now;

  final List<TenderSource> sources;
  final TenderCache cache;
  final SyncLog log;
  final SyncStore store;

  /// Optional: without an agent (or verdict cache) the sync stops after the
  /// hard rules.
  final BidAgent? agent;
  final VerdictCache? verdicts;

  /// Gemini calls per sync, to stay inside the free-tier quota. Tenders not
  /// judged this time are judged on later syncs, soonest deadline first.
  final int maxAiPerSync;
  final EligibilityRules rules;
  final int limitPerSource;
  final Duration storeTimeout;
  final DateTime Function() _clock;

  Future<SyncReport> run({
    required Company company,
    required CompanyProfile profile,
    bool background = false,
  }) async {
    final now = _clock().toUtc();
    final errors = <String>[];

    // 1. Fetch every source in parallel; one failing source is not fatal.
    final query = TenderQuery.fromProfile(profile, limit: limitPerSource);
    final found = <Tender>[];
    await Future.wait(
      sources.map((s) async {
        try {
          found.addAll(await s.search(query));
        } on Object catch (e) {
          Log.warn('sync', '${s.type.wire} failed: $e');
          errors.add('${sourceName(s.type)}: ${reasonOf(e)}');
        }
      }),
    );

    // 2. Dedup into the local cache.
    final written = await cache.upsertAll(found);

    // 3. Hard rules on new tenders only.
    final matched = <Tender>[];
    final vetoes = <Verdict>[];
    for (final t in written.added) {
      final r = rules.check(
        company: company,
        profile: profile,
        tender: t,
        now: now,
      );
      if (r.passed) {
        matched.add(t);
      } else {
        vetoes.add(BidAgent.rulesVerdict(company.id, t, r, now));
      }
    }

    // 4. Firestore, best effort: the local cache is already updated.
    // Offline, a commit only completes once the server confirms it; the
    // writes stay queued in Firestore's local cache, so a timeout loses
    // nothing.
    try {
      await Future.wait([
        store.saveTenders(written.added),
        store.recordVerdicts(vetoes),
      ]).timeout(storeTimeout);
    } on TimeoutException {
      errors.add('Cloud save: queued until online');
    } on Object catch (e) {
      Log.warn('sync', 'Firestore write failed: $e');
      errors.add('Cloud save: ${reasonOf(e)}');
    }

    // 5. Closed tenders cannot be bid on; keep the offline cache small.
    await cache.pruneClosedBefore(now);

    // 6. AI verdicts for eligible tenders that have none yet.
    final judged = await _judgePending(company, profile, now, errors);

    final report = SyncReport(
      ranAt: now,
      fetched: found.length,
      added: written.added.length,
      matched: matched.length,
      vetoed: vetoes.length,
      duplicates: written.duplicates.length,
      judged: judged.length,
      bids: judged.where((v) => v.verdict == VerdictKind.bid).length,
      errors: errors,
      background: background,
    );
    await log.insert(report);
    return report;
  }

  Future<List<Verdict>> _judgePending(
    Company company,
    CompanyProfile profile,
    DateTime now,
    List<String> errors,
  ) async {
    final a = agent;
    final vc = verdicts;
    if (a == null || vc == null || maxAiPerSync <= 0) return const [];

    final todo = <(Tender, RulesResult)>[];
    for (final t in await cache.all()) {
      // cache.all() is sorted by deadline, soonest first.
      if (todo.length >= maxAiPerSync) break;
      final r = rules.check(
        company: company,
        profile: profile,
        tender: t,
        now: now,
      );
      if (!r.passed) continue;
      if (await vc.reusable(company.id, t) != null) continue;
      todo.add((t, r));
    }

    final out = <Verdict>[];
    for (final (t, r) in todo) {
      final v = await a.judge(
        company: company,
        profile: profile,
        tender: t,
        rules: r,
      );
      await vc.put(v, textHash: t.textHash);
      out.add(v);
      // Quota or connection problems will not clear up within one sync.
      if (v.status == VerdictStatus.aiUnavailable) break;
    }
    final failed = out
        .where((v) => v.status == VerdictStatus.aiUnavailable)
        .toList();
    if (failed.isNotEmpty) {
      errors.add('AI: ${failed.first.note}');
    }
    try {
      await store.recordVerdicts(out).timeout(storeTimeout);
    } on Object catch (e) {
      Log.warn('sync', 'could not save AI verdicts: $e');
    }
    return out;
  }

  static String sourceName(TenderSourceType t) => switch (t) {
    TenderSourceType.ted => 'EU TED',
    TenderSourceType.worldBank => 'World Bank',
    TenderSourceType.scan => 'Scan',
  };

  static String reasonOf(Object e) => switch (e) {
    NetworkException(statusCode: final int code) => 'server error $code',
    NetworkException() => 'no connection',
    SourceFormatException() => 'unexpected response',
    _ when '$e'.contains('permission-denied') => 'permission denied',
    _ when '$e'.contains('unavailable') => 'offline',
    _ => 'failed',
  };
}
