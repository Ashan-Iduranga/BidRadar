import 'package:flutter/foundation.dart';

import '../../data/models/models.dart';

/// One labelled count or average, for ranked bar rows.
@immutable
class Ranked {
  const Ranked(this.label, this.value, {this.count = 0});
  final String label;

  /// The bar value: a count, or an average fit score.
  final double value;

  /// How many items the value is based on.
  final int count;
}

/// Everything the Insights page shows, computed in plain Dart.
@immutable
class InsightsStats {
  const InsightsStats({
    required this.won,
    required this.lost,
    required this.open,
    required this.lossReasons,
    required this.agreed,
    required this.judgedDecided,
    required this.verdictMix,
    required this.fitBands,
    required this.topBuyers,
    required this.topSectors,
  });

  final int won;
  final int lost;

  /// Bids not yet decided (watching, preparing, submitted).
  final int open;

  /// Reason → how many lost bids gave it, most common first.
  final List<Ranked> lossReasons;

  /// Decided bids where the AI verdict matched the outcome (BID and won,
  /// or not BID and lost), out of [judgedDecided].
  final int agreed;
  final int judgedDecided;

  /// AI verdicts by kind, over every judged tender.
  final Map<VerdictKind, int> verdictMix;

  /// Accepted AI fit scores in bands 0-19, 20-39, 40-59, 60-79, 80-100.
  final List<int> fitBands;

  /// Highest average fit score, at least one judged tender each.
  final List<Ranked> topBuyers;
  final List<Ranked> topSectors;

  int get decided => won + lost;
  double? get winRate => decided == 0 ? null : won / decided;
  double? get agreement => judgedDecided == 0 ? null : agreed / judgedDecided;
  int get judged => verdictMix.values.fold(0, (a, b) => a + b);

  static const bandLabels = ['0-19', '20-39', '40-59', '60-79', '80-100'];

  static InsightsStats compute({
    required List<Bid> bids,
    required List<(Tender, Verdict)> judged,
    int top = 5,
  }) {
    final won = bids.where((b) => b.stage == BidStage.won).length;
    final lost = bids.where((b) => b.stage == BidStage.lost).toList();

    final reasons = <String, int>{};
    for (final b in lost) {
      for (final r in b.lossReasons) {
        reasons[r] = (reasons[r] ?? 0) + 1;
      }
    }

    var agreed = 0;
    var judgedDecided = 0;
    for (final b in bids) {
      final decided = b.stage == BidStage.won || b.stage == BidStage.lost;
      if (!decided || b.verdict == null) continue;
      judgedDecided++;
      final saidBid = b.verdict == VerdictKind.bid;
      if (saidBid == (b.stage == BidStage.won)) agreed++;
    }

    final mix = {for (final k in VerdictKind.values) k: 0};
    final bands = List<int>.filled(5, 0);
    final byBuyer = <String, List<int>>{};
    final bySector = <String, List<int>>{};
    for (final (t, v) in judged) {
      if (v.status == VerdictStatus.aiUnavailable) continue;
      mix[v.verdict] = mix[v.verdict]! + 1;
      if (v.status != VerdictStatus.accepted) continue;
      bands[(v.fitScore.clamp(0, 100) ~/ 20).clamp(0, 4)]++;
      byBuyer.putIfAbsent(t.buyer, () => []).add(v.fitScore);
      for (final d in {for (final c in t.cpvCodes) c.substring(0, 2)}) {
        bySector.putIfAbsent(d, () => []).add(v.fitScore);
      }
    }

    List<Ranked> rank(Map<String, List<int>> m, String Function(String) l) => [
      for (final e in m.entries)
        Ranked(
          l(e.key),
          e.value.reduce((a, b) => a + b) / e.value.length,
          count: e.value.length,
        ),
    ]..sort((a, b) => b.value.compareTo(a.value));

    return InsightsStats(
      won: won,
      lost: lost.length,
      open: bids.length - won - lost.length,
      lossReasons: [
        for (final e in reasons.entries)
          Ranked(e.key, e.value.toDouble(), count: e.value),
      ]..sort((a, b) => b.value.compareTo(a.value)),
      agreed: agreed,
      judgedDecided: judgedDecided,
      verdictMix: mix,
      fitBands: bands,
      topBuyers: rank(byBuyer, (k) => k).take(top).toList(),
      topSectors: rank(bySector, sectorName).take(top).toList(),
    );
  }

  /// Plain names for common CPV divisions (first 2 digits).
  static String sectorName(String division) => switch (division) {
    '30' => 'Office and computing equipment',
    '32' => 'Telecoms equipment',
    '33' => 'Medical equipment',
    '34' => 'Transport equipment',
    '45' => 'Construction work',
    '48' => 'Software packages',
    '50' => 'Repair and maintenance',
    '71' => 'Architecture and engineering',
    '72' => 'IT services',
    '73' => 'Research and development',
    '79' => 'Business services',
    '80' => 'Education and training',
    '85' => 'Health and social work',
    '90' => 'Environmental services',
    _ => 'CPV $division',
  };
}
