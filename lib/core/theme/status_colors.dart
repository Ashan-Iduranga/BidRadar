import 'package:flutter/material.dart';

/// Semantic colours for verdicts and deadlines, with light and dark variants.
///
/// Each pair is a container colour plus the text/icon colour drawn on it, so
/// contrast stays at or above 4.5:1. Widgets always pair these colours with an
/// icon and a text label, never colour alone.
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.bid,
    required this.onBid,
    required this.noBid,
    required this.onNoBid,
    required this.review,
    required this.onReview,
    required this.neutral,
    required this.onNeutral,
    required this.bidMark,
    required this.reviewMark,
    required this.noBidMark,
  });

  final Color bid;
  final Color onBid;
  final Color noBid;
  final Color onNoBid;
  final Color review;
  final Color onReview;
  final Color neutral;
  final Color onNeutral;

  /// Data-mark colours for charts and fit rings: green, violet and red differ
  /// in lightness as well as hue, and marks always come with gaps, icons and
  /// labels, so colour is never the only cue.
  final Color bidMark;
  final Color reviewMark;
  final Color noBidMark;

  static const light = StatusColors(
    bid: Color(0xFFDCF2E8),
    onBid: Color(0xFF0B5A3A),
    noBid: Color(0xFFF9DEDC),
    onNoBid: Color(0xFF8C1D18),
    // Review is violet so it never reads as the orange action colour.
    review: Color(0xFFE6E3FA),
    onReview: Color(0xFF3F2F9E),
    neutral: Color(0xFFE9ECEF),
    onNeutral: Color(0xFF3D464D),
    bidMark: Color(0xFF1F8A70),
    reviewMark: Color(0xFF5B4BC4),
    noBidMark: Color(0xFFC2362B),
  );

  static const dark = StatusColors(
    bid: Color(0xFF163D2E),
    onBid: Color(0xFFA6E3C8),
    noBid: Color(0xFF4E1A16),
    onNoBid: Color(0xFFFFB4AB),
    review: Color(0xFF2E2860),
    onReview: Color(0xFFCFC7FF),
    neutral: Color(0xFF2A3036),
    onNeutral: Color(0xFFC7CED4),
    bidMark: Color(0xFF3FB58F),
    reviewMark: Color(0xFF9F92F0),
    noBidMark: Color(0xFFE0675C),
  );

  @override
  StatusColors copyWith({
    Color? bid,
    Color? onBid,
    Color? noBid,
    Color? onNoBid,
    Color? review,
    Color? onReview,
    Color? neutral,
    Color? onNeutral,
    Color? bidMark,
    Color? reviewMark,
    Color? noBidMark,
  }) {
    return StatusColors(
      bid: bid ?? this.bid,
      onBid: onBid ?? this.onBid,
      noBid: noBid ?? this.noBid,
      onNoBid: onNoBid ?? this.onNoBid,
      review: review ?? this.review,
      onReview: onReview ?? this.onReview,
      neutral: neutral ?? this.neutral,
      onNeutral: onNeutral ?? this.onNeutral,
      bidMark: bidMark ?? this.bidMark,
      reviewMark: reviewMark ?? this.reviewMark,
      noBidMark: noBidMark ?? this.noBidMark,
    );
  }

  @override
  StatusColors lerp(StatusColors? other, double t) {
    if (other == null) return this;
    return StatusColors(
      bid: Color.lerp(bid, other.bid, t)!,
      onBid: Color.lerp(onBid, other.onBid, t)!,
      noBid: Color.lerp(noBid, other.noBid, t)!,
      onNoBid: Color.lerp(onNoBid, other.onNoBid, t)!,
      review: Color.lerp(review, other.review, t)!,
      onReview: Color.lerp(onReview, other.onReview, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
      onNeutral: Color.lerp(onNeutral, other.onNeutral, t)!,
      bidMark: Color.lerp(bidMark, other.bidMark, t)!,
      reviewMark: Color.lerp(reviewMark, other.reviewMark, t)!,
      noBidMark: Color.lerp(noBidMark, other.noBidMark, t)!,
    );
  }
}

extension StatusColorsX on BuildContext {
  StatusColors get statusColors =>
      Theme.of(this).extension<StatusColors>() ?? StatusColors.light;
}
