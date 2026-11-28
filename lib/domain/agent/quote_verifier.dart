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
/// AI may not paraphrase: after normalising case, punctuation and spacing,
/// the quote must appear in the notice as whole words, so "3 years" does
/// not match inside "13 years". Thousands separators are removed first, so
/// "500,000" is one word and does not match inside "1,500,000".
class QuoteVerifier {
  const QuoteVerifier({this.minLength = 8, this.minWords = 3});

  /// Shorter quotes ("yes", "EUR") prove nothing and are rejected.
  final int minLength;

  /// Quotes of fewer words ("ISO 9001", "the bidder") match almost any
  /// notice, so they prove nothing either.
  final int minWords;

  QuoteCheck check(List<Criterion> criteria, String noticeText) {
    final notice = normalise(noticeText);
    return QuoteCheck([
      for (final c in criteria)
        c.copyWith(quoteVerified: verify(c.quote, notice)),
    ]);
  }

  /// [normalisedNotice] must already be passed through [normalise].
  bool verify(String quote, String normalisedNotice) {
    final q = normalise(_stripEllipsis(quote));
    if (q.length < minLength) return false;
    if (q.split(' ').length < minWords) return false;
    // Pad with spaces so only whole words match.
    return ' $normalisedNotice '.contains(' $q ');
  }

  /// [TextUtils.normalise] after joining digit groups ("1,500,000",
  /// "1.500.000" and "1 500 000" all become "1500000"). Used for quotes
  /// only: the notice hash keeps the plain normalisation.
  static String normalise(String s) =>
      TextUtils.normalise(s.replaceAll(_digitGroupSeparator, ''));

  /// A separator between a digit and a group of exactly 3 digits: comma,
  /// dot, apostrophe, space, no-break space or narrow no-break space.
  static final _digitGroupSeparator = RegExp(
    r"(?<=\d)[.,'\u2019 \u00A0\u202F](?=\d{3}(?!\d))",
  );

  /// Models sometimes wrap quotes in quote marks or trailing "…"; those are
  /// not part of the evidence. Inner ellipses (skipped text) are not
  /// allowed and will fail.
  static String _stripEllipsis(String s) => s
      .trim()
      .replaceAll(RegExp(r'^["“”‘’\x27]+|["“”‘’\x27]+$'), '')
      .replaceAll(RegExp(r'^(\.\.\.|…)\s*|\s*(\.\.\.|…)$'), '');
}
