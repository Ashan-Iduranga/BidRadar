import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/log.dart';
import '../../core/net/resilient_http.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';
import '../../data/sources/tender_source.dart';
import '../../domain/rules/eligibility_rules.dart';
import '../session/session_providers.dart';

/// Cached tenders from drift, so the feed works offline.
final cachedTendersProvider = StreamProvider<List<Tender>>(
  (ref) => ref.watch(tenderCacheProvider).watchAll(),
);

final eligibilityRulesProvider = Provider((ref) => const EligibilityRules());

/// One tender with its hard-rule result, as the feed shows it.
@immutable
class FeedItem {
  const FeedItem(this.tender, this.rules);
  final Tender tender;
  final RulesResult? rules;
}

/// Feed rows: rules applied with the current profile; eligible tenders
/// first, then by deadline. Phase 2 moves this into FeedSync and adds AI
/// verdicts.
final feedItemsProvider = Provider<AsyncValue<List<FeedItem>>>((ref) {
  final tenders = ref.watch(cachedTendersProvider);
  final company = ref.watch(currentCompanyProvider).value;
  final profile = ref.watch(currentProfileProvider).value;
  final rules = ref.watch(eligibilityRulesProvider);
  final now = DateTime.now();
  return tenders.whenData((list) {
    final items = [
      for (final t in list)
        FeedItem(
          t,
          company == null || profile == null
              ? null
              : rules.check(
                  company: company,
                  profile: profile,
                  tender: t,
                  now: now,
                ),
        ),
    ];
    items.sort((a, b) {
      final pa = a.rules?.passed ?? true;
      final pb = b.rules?.passed ?? true;
      if (pa != pb) return pa ? -1 : 1;
      final da = a.tender.deadline;
      final db = b.tender.deadline;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });
    return items;
  });
});

@immutable
class FetchState {
  const FetchState({
    this.running = false,
    this.lastRun,
    this.added = 0,
    this.duplicates = 0,
    this.errors = const [],
  });

  final bool running;
  final DateTime? lastRun;
  final int added;
  final int duplicates;

  /// One line per source that failed, e.g. "World Bank: no connection".
  final List<String> errors;
}

/// "Fetch now": asks every source for the profile, then caches the result.
class FetchViewModel extends Notifier<FetchState> {
  @override
  FetchState build() => const FetchState();

  Future<void> fetch() async {
    if (state.running) return;
    final profile = ref.read(currentProfileProvider).value;
    if (profile == null) {
      state = const FetchState(errors: ['Set up your company profile first.']);
      return;
    }
    state = FetchState(running: true, lastRun: state.lastRun);
    final query = TenderQuery.fromProfile(profile, limit: 30);
    final errors = <String>[];
    final found = <Tender>[];
    await Future.wait(
      ref.read(tenderSourcesProvider).map((s) async {
        try {
          found.addAll(await s.search(query));
        } on Object catch (e) {
          Log.warn('feed', '${s.type.wire} failed: $e');
          errors.add('${_name(s.type)}: ${_reason(e)}');
        }
      }),
    );
    final cache = ref.read(tenderCacheProvider);
    final result = await cache.upsertAll(found);
    // Closed tenders cannot be bid on; keep the offline cache small.
    await cache.pruneClosedBefore(DateTime.now());
    state = FetchState(
      lastRun: DateTime.now(),
      added: result.added.length,
      duplicates: result.duplicates.length,
      errors: errors,
    );
  }

  static String _name(TenderSourceType t) => switch (t) {
    TenderSourceType.ted => 'EU TED',
    TenderSourceType.worldBank => 'World Bank',
    TenderSourceType.scan => 'Scan',
  };

  static String _reason(Object e) => switch (e) {
    NetworkException(statusCode: final int code) => 'server error $code',
    NetworkException() => 'no connection',
    SourceFormatException() => 'unexpected response',
    _ => 'failed',
  };
}

final fetchViewModelProvider = NotifierProvider<FetchViewModel, FetchState>(
  FetchViewModel.new,
);
