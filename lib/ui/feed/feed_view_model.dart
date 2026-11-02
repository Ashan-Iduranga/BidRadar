import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/app_database.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';
import '../../domain/rules/eligibility_rules.dart';
import '../session/session_providers.dart';

/// Cached tenders from drift, so the feed works offline.
final cachedTendersProvider = StreamProvider<List<Tender>>(
  (ref) => ref.watch(tenderCacheProvider).watchAll(),
);

/// The most recent sync run, for "Updated 5 min ago".
final lastSyncProvider = StreamProvider<SyncReport?>(
  (ref) => ref.watch(syncLogProvider).watchLatest(),
);

final eligibilityRulesProvider = Provider((ref) => const EligibilityRules());

/// One tender with its hard-rule result, as the feed shows it.
@immutable
class FeedItem {
  const FeedItem(this.tender, this.rules, [this.verdict]);
  final Tender tender;

  /// Null when there is no profile to check against.
  final RulesResult? rules;

  /// The latest AI verdict, if the agent has judged this tender.
  final Verdict? verdict;

  /// Removed by a hard rule (always wins) or judged NO_BID.
  bool get removed =>
      rules?.passed == false || verdict?.verdict == VerdictKind.noBid;

  bool get isBid => !removed && verdict?.verdict == VerdictKind.bid;

  bool get needsReview =>
      !removed &&
      (verdict?.verdict == VerdictKind.review ||
          (verdict == null && (rules?.warnings.isNotEmpty ?? false)));
}

enum FeedStatus {
  /// Not removed by the rules or the AI.
  eligible('Eligible'),

  /// The AI says BID.
  bid('Bid'),

  /// Passed, but something could not be checked.
  review('Needs review'),

  /// Vetoed by a hard rule.
  removed('Removed'),
  all('All');

  const FeedStatus(this.label);
  final String label;
}

@immutable
class FeedFilter {
  const FeedFilter({
    this.sources = const {},
    this.status = FeedStatus.eligible,
    this.sector,
  });

  /// Empty means every source.
  final Set<TenderSourceType> sources;
  final FeedStatus status;

  /// A profile CPV code, or null for any sector.
  final String? sector;

  bool get isDefault =>
      sources.isEmpty && status == FeedStatus.eligible && sector == null;

  FeedFilter copyWith({
    Set<TenderSourceType>? sources,
    FeedStatus? status,
    String? Function()? sector,
  }) => FeedFilter(
    sources: sources ?? this.sources,
    status: status ?? this.status,
    sector: sector == null ? this.sector : sector(),
  );
}

class FeedFilterNotifier extends Notifier<FeedFilter> {
  @override
  FeedFilter build() => const FeedFilter();

  void toggleSource(TenderSourceType s) {
    final next = {...state.sources};
    next.contains(s) ? next.remove(s) : next.add(s);
    state = state.copyWith(sources: next);
  }

  void setStatus(FeedStatus s) => state = state.copyWith(status: s);
  void setSector(String? cpv) => state = state.copyWith(sector: () => cpv);
  void clear() => state = const FeedFilter();
}

final feedFilterProvider = NotifierProvider<FeedFilterNotifier, FeedFilter>(
  FeedFilterNotifier.new,
);

/// Ranking: BID, then not yet judged, then REVIEW, then removed. Within a
/// group, higher fit score first, then soonest deadline; unknown deadlines
/// last.
int compareFeedItems(FeedItem a, FeedItem b) {
  int group(FeedItem i) => i.removed
      ? 3
      : i.isBid
      ? 0
      : i.needsReview
      ? 2
      : 1;
  final g = group(a).compareTo(group(b));
  if (g != 0) return g;
  final fa = a.verdict?.fitScore ?? -1;
  final fb = b.verdict?.fitScore ?? -1;
  if (fa != fb) return fb.compareTo(fa);
  final da = a.tender.deadline;
  final db = b.tender.deadline;
  if (da == null && db == null) return 0;
  if (da == null) return 1;
  if (db == null) return -1;
  return da.compareTo(db);
}

/// Pure filter + ranking, unit tested in test/ui/feed_filter_test.dart.
List<FeedItem> applyFeedFilter(List<FeedItem> items, FeedFilter f) {
  final out = items.where((i) {
    if (f.sources.isNotEmpty && !f.sources.contains(i.tender.source)) {
      return false;
    }
    final statusOk = switch (f.status) {
      FeedStatus.eligible => !i.removed,
      FeedStatus.bid => i.isBid,
      FeedStatus.review => i.needsReview,
      FeedStatus.removed => i.removed,
      FeedStatus.all => true,
    };
    if (!statusOk) return false;
    final sector = f.sector;
    if (sector != null &&
        !i.tender.cpvCodes.any((c) => EligibilityRules.cpvOverlap(c, sector))) {
      return false;
    }
    return true;
  }).toList()..sort(compareFeedItems);
  return out;
}

/// tenderId → latest AI verdict for the current company.
final verdictsProvider = StreamProvider<Map<String, Verdict>>((ref) {
  final companyId = ref.watch(currentCompanyIdProvider).value;
  if (companyId == null) return Stream.value(const {});
  return ref.watch(verdictCacheProvider).watchForCompany(companyId);
});

/// Every cached tender with live rule results and its AI verdict.
final feedItemsProvider = Provider<AsyncValue<List<FeedItem>>>((ref) {
  final tenders = ref.watch(cachedTendersProvider);
  final verdicts = ref.watch(verdictsProvider).value ?? const {};
  final company = ref.watch(currentCompanyProvider).value;
  final profile = ref.watch(currentProfileProvider).value;
  final rules = ref.watch(eligibilityRulesProvider);
  final now = DateTime.now();
  return tenders.whenData(
    (list) => [
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
          verdicts[t.id],
        ),
    ],
  );
});

/// The items the feed shows after filtering and ranking.
final filteredFeedProvider = Provider<AsyncValue<List<FeedItem>>>((ref) {
  final filter = ref.watch(feedFilterProvider);
  return ref
      .watch(feedItemsProvider)
      .whenData((items) => applyFeedFilter(items, filter));
});

@immutable
class SyncState {
  const SyncState({this.running = false, this.last});
  final bool running;

  /// Result of the last sync started from the UI in this session.
  final SyncReport? last;
}

/// "Sync now" and pull to refresh: runs the same FeedSync as the
/// background job.
class SyncViewModel extends Notifier<SyncState> {
  bool _askedPermission = false;

  @override
  SyncState build() => const SyncState();

  /// Returns the report, or null when a sync was already running or there
  /// is no profile yet.
  Future<SyncReport?> syncNow() async {
    if (state.running) return null;
    final company = ref.read(currentCompanyProvider).value;
    final profile = ref.read(currentProfileProvider).value;
    if (company == null || profile == null) return null;
    state = SyncState(running: true, last: state.last);
    try {
      final report = await ref
          .read(feedSyncProvider)
          .run(company: company, profile: profile);
      state = SyncState(last: report);
      if (!_askedPermission) {
        // Ask once, after the user has seen what a sync does.
        _askedPermission = true;
        await ref.read(notifierProvider).requestPermission();
      }
      return report;
    } on Object {
      state = SyncState(last: state.last);
      rethrow;
    }
  }
}

final syncViewModelProvider = NotifierProvider<SyncViewModel, SyncState>(
  SyncViewModel.new,
);

/// "12 new · 9 match · 3 removed by rules · 5 judged by AI (2 BID) ·
/// World Bank: no connection".
String syncSummary(SyncReport r) => [
  r.added == 0 ? 'No new tenders' : '${r.added} new',
  if (r.matched > 0) '${r.matched} match',
  if (r.vetoed > 0) '${r.vetoed} removed by rules',
  if (r.judged > 0) '${r.judged} judged by AI (${r.bids} BID)',
  ...r.errors,
].join(' · ');

/// "Updated just now", "Updated 5 min ago", "Updated 3 h ago",
/// "Updated yesterday", "Updated 4 days ago", or "Never synced".
String updatedLabel(DateTime? ranAt, DateTime now) {
  if (ranAt == null) return 'Never synced';
  final d = now.difference(ranAt);
  if (d.inMinutes < 1) return 'Updated just now';
  if (d.inHours < 1) return 'Updated ${d.inMinutes} min ago';
  if (d.inDays < 1) return 'Updated ${d.inHours} h ago';
  return d.inDays == 1 ? 'Updated yesterday' : 'Updated ${d.inDays} days ago';
}
