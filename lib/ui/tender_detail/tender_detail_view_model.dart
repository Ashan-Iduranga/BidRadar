import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/models.dart';
import '../../data/providers.dart';
import '../feed/feed_view_model.dart';
import '../session/session_providers.dart';

/// What the Tender detail page shows. [tender] is null when it is no longer
/// in the local cache (closed and pruned, or never synced on this device).
@immutable
class TenderDetail {
  const TenderDetail({required this.tender, required this.rules});
  final Tender? tender;
  final RulesResult? rules;
}

final cachedTenderProvider = StreamProvider.family<Tender?, String>(
  (ref, id) => ref.watch(tenderCacheProvider).watchById(id),
);

final tenderDetailProvider = Provider.family<AsyncValue<TenderDetail>, String>((
  ref,
  id,
) {
  final company = ref.watch(currentCompanyProvider).value;
  final profile = ref.watch(currentProfileProvider).value;
  final rules = ref.watch(eligibilityRulesProvider);
  return ref.watch(cachedTenderProvider(id)).whenData((t) {
    final result = t == null || company == null || profile == null
        ? null
        : rules.check(
            company: company,
            profile: profile,
            tender: t,
            now: DateTime.now(),
          );
    return TenderDetail(tender: t, rules: result);
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
