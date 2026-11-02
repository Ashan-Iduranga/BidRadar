import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/log.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';
import '../../domain/insights/insights.dart';
import '../../domain/insights/profile_advisor.dart';
import '../feed/feed_view_model.dart';
import '../pipeline/pipeline_view_model.dart';
import '../profile/profile_view_model.dart' show ProfileInput;
import '../session/session_providers.dart';

final insightsProvider = Provider<InsightsStats>((ref) {
  final bids = ref.watch(bidsProvider).value ?? const [];
  final items = ref.watch(feedItemsProvider).value ?? const [];
  return InsightsStats.compute(
    bids: bids,
    judged: [
      for (final i in items)
        if (i.verdict != null) (i.tender, i.verdict!),
    ],
  );
});

final profileAdvisorProvider = Provider<ProfileAdvisor>(
  (ref) => GeminiProfileAdvisor(),
);

@immutable
class AdvisorState {
  const AdvisorState({
    this.loading = false,
    this.suggestions = const [],
    this.error,
    this.asked = false,
  });
  final bool loading;
  final List<ProfileSuggestion> suggestions;
  final String? error;
  final bool asked;
}

/// Gemini suggests profile changes from lost bids; only the owner can
/// accept one, and each is validated like a manual edit.
class AdvisorViewModel extends Notifier<AdvisorState> {
  @override
  AdvisorState build() => const AdvisorState();

  Future<void> suggest() async {
    final company = ref.read(currentCompanyProvider).value;
    final profile = ref.read(currentProfileProvider).value;
    final lost = (ref.read(bidsProvider).value ?? const <Bid>[])
        .where((b) => b.stage == BidStage.lost)
        .toList();
    if (company == null || profile == null || lost.isEmpty) return;
    state = const AdvisorState(loading: true);
    try {
      final s = await ref
          .read(profileAdvisorProvider)
          .suggest(company: company, profile: profile, lostBids: lost);
      state = AdvisorState(
        suggestions: [
          for (final x in s)
            if (!x.alreadyIn(profile)) x,
        ],
        asked: true,
      );
    } on Object catch (e) {
      Log.warn('advisor', 'suggestions failed: $e');
      state = const AdvisorState(
        asked: true,
        error: 'The AI could not make suggestions right now. Try later.',
      );
    }
  }

  void dismiss(ProfileSuggestion s) => state = AdvisorState(
    asked: true,
    suggestions: [...state.suggestions]..remove(s),
  );

  /// Returns an error message, or null when the profile was updated.
  Future<String?> accept(ProfileSuggestion s) async {
    if (ref.read(currentRoleProvider) != UserRole.owner) {
      return 'Only the owner can change the profile.';
    }
    final p = ref.read(currentProfileProvider).value;
    if (p == null) return 'No profile loaded.';
    final CompanyProfile next;
    switch (s.kind) {
      case SuggestionKind.addSector:
        final r = ProfileInput.cpv(s.value, p.cpvCodes);
        if (r.error != null) return r.error;
        next = p.copyWith(cpvCodes: [...p.cpvCodes, r.code!]);
      case SuggestionKind.addCountry:
        final r = ProfileInput.country(s.value, p.countries);
        if (r.error != null) return r.error;
        next = p.copyWith(countries: [...p.countries, r.code!]);
      case SuggestionKind.addCertification:
        final r = ProfileInput.certification(s.value, p.certifications);
        if (r.error != null) return r.error;
        next = p.copyWith(certifications: [...p.certifications, r.value!]);
      case SuggestionKind.other:
        return 'This is advice only; there is nothing to apply.';
    }
    try {
      await ref.read(profileRepositoryProvider).save(next);
      dismiss(s);
      return null;
    } on Object catch (e) {
      return 'Could not save: $e';
    }
  }
}

final advisorViewModelProvider =
    NotifierProvider<AdvisorViewModel, AdvisorState>(AdvisorViewModel.new);
