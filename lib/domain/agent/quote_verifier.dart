import '../../core/text/text_utils.dart';
import '../../data/models/models.dart';

/// Result of checking every quote in a verdict against the notice text.
class QuoteCheck {
  const QuoteCheck(this.criteria);

  /// Criteria with [Criterion.quoteVerified] set.
  final List<Criterion> criteria;

  bool get allVerified => criteria.every((c) => c.quoteVerified);

  List<Criterion> get failed =>
      criteria.where((c) => !c.quoteVerified).toList();
}

/// Checks that each quote the AI gives really appears in the notice. The
/// AI may not paraphrase: after normalising case, punctuation and spacing
/// (the same normalisation as the notice hash), the quote must be an exact
/// substring of the notice text.
class QuoteVerifier {
  const QuoteVerifier({this.minLength = 8});

  /// Shorter quotes ("yes", "EUR") prove nothing and are rejected.
  final int minLength;

  QuoteCheck check(List<Criterion> criteria, String noticeText) {
    final notice = TextUtils.normalise(noticeText);
    return QuoteCheck([
      for (final c in criteria)
        c.copyWith(quoteVerified: verify(c.quote, notice)),
    ]);
  }

  /// [normalisedNotice] must already be passed through
  /// [TextUtils.normalise].
  bool verify(String quote, String normalisedNotice) {
    final q = TextUtils.normalise(_stripEllipsis(quote));
    if (q.length < minLength) return false;
    return normalisedNotice.contains(q);
  }

  /// Models sometimes wrap quotes in quote marks or trailing "…"; those are
  /// not part of the evidence. Inner ellipses (skipped text) are not
  /// allowed and will fail.
  static String _stripEllipsis(String s) => s
      .trim()
      .replaceAll(RegExp(r'^["“”‘’\x27]+|["“”‘’\x27]+$'), '')
      .replaceAll(RegExp(r'^(\.\.\.|…)\s*|\s*(\.\.\.|…)$'), '');
}
