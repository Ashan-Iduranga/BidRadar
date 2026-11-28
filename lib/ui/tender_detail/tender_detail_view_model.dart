import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/models.dart';
import '../../data/providers.dart';
import '../../domain/agent/profile_fingerprint.dart';
import '../feed/feed_view_model.dart';
import '../session/session_providers.dart';

/// What the Tender detail page shows. [tender] is null when it is no longer
/// in the local cache (closed and pruned, or never synced on this device).
@immutable
class TenderDetail {
  const TenderDetail({required this.tender, required this.rules, this.verdict});
  final Tender? tender;
  final RulesResult? rules;
  final Verdict? verdict;
}

final cachedTenderProvider = StreamProvider.family<Tender?, String>(
  (ref, id) => ref.watch(tenderCacheProvider).watchById(id),
);

final cachedVerdictProvider = StreamProvider.family<Verdict?, String>((
  ref,
  tenderId,
) {
  final companyId = ref.watch(currentCompanyIdProvider).value;
  if (companyId == null) return Stream.value(null);
  return ref.watch(verdictCacheProvider).watchOne(companyId, tenderId);
});

/// "Judge with AI" on the detail page: runs the same BidAgent as the sync.
class JudgeViewModel extends Notifier<bool> {
  JudgeViewModel(this.tenderId);
  final String tenderId;

  @override
  bool build() => false; // running?

  /// Returns an error message, or null when a verdict was stored.
  Future<String?> judge() async {
    if (state) return null;
    final company = ref.read(currentCompanyProvider).value;
    final profile = ref.read(currentProfileProvider).value;
    final detail = ref.read(tenderDetailProvider(tenderId)).value;
    final tender = detail?.tender;
    final rules = detail?.rules;
    if (company == null || profile == null || tender == null || rules == null) {
      return 'Set up your company profile first.';
    }
    state = true;
    try {
      final v = await ref
          .read(bidAgentProvider)
          .judge(
            company: company,
            profile: profile,
            tender: tender,
            rules: rules,
          );
      // With the profile fingerprint, so the next sync reuses this verdict
      // instead of judging the tender again.
      await ref
          .read(verdictCacheProvider)
          .put(
            v,
            textHash: tender.textHash,
            profileHash: ProfileFingerprint.of(company, profile),
          );
      try {
        await ref
            .read(syncStoreProvider)
            .recordVerdicts([v])
            .timeout(const Duration(seconds: 20));
      } on Object {
        // Queued by Firestore offline; the local verdict is what we show.
      }
      return v.status == VerdictStatus.aiUnavailable ? v.note : null;
    } finally {
      state = false;
    }
  }
}

final judgeViewModelProvider =
    NotifierProvider.family<JudgeViewModel, bool, String>(JudgeViewModel.new);

final tenderDetailProvider = Provider.family<AsyncValue<TenderDetail>, String>((
  ref,
  id,
) {
  final company = ref.watch(currentCompanyProvider).value;
  final profile = ref.watch(currentProfileProvider).value;
  final rules = ref.watch(eligibilityRulesProvider);
  final verdict = ref.watch(cachedVerdictProvider(id)).value;
  return ref.watch(cachedTenderProvider(id)).whenData((t) {
    final result = t == null || company == null || profile == null
        ? null
        : rules.check(
            company: company,
            profile: profile,
            tender: t,
            now: DateTime.now(),
          );
    return TenderDetail(tender: t, rules: result, verdict: verdict);
  });
});

/// Text for the share sheet: what, who, when, where to read it.
String shareText(Tender t) {
  final deadline = t.deadline == null
      ? 'deadline unknown'
      : 'closes ${DateFormat.yMMMd().add_jm().format(t.deadline!.toLocal())}';
  return [
    t.title,
    '${t.buyer} · $deadline',
    ?t.url,
    '(shared from BidRadar)',
  ].join('\n');
}
