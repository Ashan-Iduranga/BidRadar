import '../../data/models/models.dart';

/// Guards applied after the AI answers. They cannot be overridden by the
/// model: the code always has the last word.
class VerdictGuards {
  const VerdictGuards({this.minConfidence = 0.6, this.minBidScore = 50});

  /// Below this confidence a BID or NO_BID becomes REVIEW.
  final double minConfidence;

  /// A BID with a fit score below this becomes REVIEW.
  final int minBidScore;

  /// Returns the final verdict and, if a guard changed it, why.
  ({VerdictKind verdict, String? reason}) apply({
    required VerdictKind aiVerdict,
    required int fitScore,
    required double confidence,
    required List<Criterion> criteria,
    required RulesResult rules,
  }) {
    // 1. A hard-rule veto always wins, whatever the model said.
    if (!rules.passed) {
      return (verdict: VerdictKind.noBid, reason: rules.vetoes.first.message);
    }
    if (aiVerdict == VerdictKind.review) {
      return (verdict: VerdictKind.review, reason: null);
    }
    // 2. Unsure answers go to a person.
    if (confidence < minConfidence) {
      return (
        verdict: VerdictKind.review,
        reason: 'AI confidence is low (${(confidence * 100).round()}%).',
      );
    }
    if (aiVerdict == VerdictKind.bid) {
      // 3. A BID must be consistent with its own evidence.
      if (criteria.isEmpty) {
        return (
          verdict: VerdictKind.review,
          reason: 'The AI said BID without quoting any evidence.',
        );
      }
      final unmet = criteria.where((c) => c.met == CriterionMet.no);
      if (unmet.isNotEmpty) {
        return (
          verdict: VerdictKind.review,
          reason:
              'The AI said BID but marked "${unmet.first.criterion}" '
              'as not met.',
        );
      }
      if (fitScore < minBidScore) {
        return (
          verdict: VerdictKind.review,
          reason: 'Fit score $fitScore is too low for a BID.',
        );
      }
      // 4. Facts the rules could not check need a human look.
      if (rules.warnings.isNotEmpty) {
        return (verdict: VerdictKind.review, reason: rules.warnings.first);
      }
    }
    return (verdict: aiVerdict, reason: null);
  }
}
