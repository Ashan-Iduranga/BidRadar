import 'dart:async';

import '../../core/logging/log.dart';
import '../../core/net/resilient_http.dart';
import '../../data/local/app_database.dart';
import '../../data/models/models.dart';
import '../../data/repositories/sync_store.dart';
import '../../data/sources/tender_source.dart';
import '../agent/ai_failure.dart';
import '../agent/bid_agent.dart';
import '../rules/eligibility_rules.dart';

/// The feed pipeline: fetch → drop closed → dedup → hard rules → store → AI.
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

  /// Tenders sent to Gemini per sync, to stay inside the free-tier quota.
  /// Tenders not judged this time are judged on later syncs, soonest
  /// deadline first.
  final int maxAiPerSync;

  /// After this many notice-specific AI failures in a row (malformed or
  /// blocked answers), a notice is left for a person. "Judge with AI" on the
  /// detail page can still try it.
  static const maxNoticeFailures = 3;
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

    // 2. Drop notices that have already closed, to the minute. Sources
    // filter by date, so a tender that closed earlier today would otherwise
    // come back after every prune and be counted (and vetoed) as new.
    final open = [
      for (final t in found)
        if (t.deadline == null || t.deadline!.toUtc().isAfter(now)) t,
    ];

    // 3. Dedup into the local cache.
    final written = await cache.upsertAll(open);

    // 4. Hard rules on new tenders only.
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

    // 5. Firestore, best effort: the local cache is already updated.
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

    // 6. Closed tenders cannot be bid on; keep the offline cache small.
    await cache.pruneClosedBefore(now);

    // 7. AI verdicts for eligible tenders that have none yet.
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

    // Tenders never asked about (or whose notice changed) go first; earlier
    // AI failures wait behind them, so one notice that keeps failing is not
    // first in line on every sync. cache.all() is soonest deadline first.
    final fresh = <_Pending>[];
    final retry = <_Pending>[];
    for (final t in await cache.all()) {
      final r = rules.check(
        company: company,
        profile: profile,
        tender: t,
        now: now,
      );
      if (!r.passed) continue;
      final cached = await vc.entry(company.id, t.id);
      if (cached == null || cached.textHash != t.textHash) {
        fresh.add(_Pending(t, r, 0, fresh.length + retry.length));
        continue;
      }
      if (!cached.failed) continue; // reusable verdict
      if (cached.failures >= maxNoticeFailures) continue; // for a person
      retry.add(_Pending(t, r, cached.failures, fresh.length + retry.length));
    }
    retry.sort(
      (x, y) => x.failures != y.failures
          ? x.failures.compareTo(y.failures)
          : x.order.compareTo(y.order),
    );
    final todo = [...fresh, ...retry].take(maxAiPerSync);

    final out = <Verdict>[];
    var noticeFailures = 0;
    for (final p in todo) {
      final o = await a.assess(
        company: company,
        profile: profile,
        tender: p.tender,
        rules: p.rules,
      );
      final failures = switch (o.failure) {
        null => 0,
        AiFailure.notice => p.failures + 1,
        // Not this notice's fault: keep its count.
        _ => p.failures,
      };
      await vc.put(o.verdict, textHash: p.tender.textHash, failures: failures);
      out.add(o.verdict);
      if (o.failure == AiFailure.notice) noticeFailures++;
      // Quota, connection, access or service problems will not clear up
      // within one sync. A problem with one notice does not stop the rest.
      if (o.failure?.stopsSync ?? false) {
        errors.add('AI: ${o.verdict.note}');
        break;
      }
    }
    if (noticeFailures > 0) {
      errors.add(
        'AI: $noticeFailures notice(s) could not be judged. Decide manually.',
      );
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

/// A tender waiting for an AI verdict in this sync.
class _Pending {
  const _Pending(this.tender, this.rules, this.failures, this.order);
  final Tender tender;
  final RulesResult rules;

  /// Notice-specific AI failures in a row so far.
  final int failures;

  /// Position in the deadline order, to keep sorting stable.
  final int order;
}
