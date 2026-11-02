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
  });

  final Color bid;
  final Color onBid;
  final Color noBid;
  final Color onNoBid;
  final Color review;
  final Color onReview;
  final Color neutral;
  final Color onNeutral;

  static const light = StatusColors(
    bid: Color(0xFFD5EFE4),
    onBid: Color(0xFF0E4F3A),
    noBid: Color(0xFFF9DEDC),
    onNoBid: Color(0xFF8C1D18),
    review: Color(0xFFFBEBC2),
    onReview: Color(0xFF6B4A00),
    neutral: Color(0xFFE4E9E6),
    onNeutral: Color(0xFF34464A),
  );

  static const dark = StatusColors(
    bid: Color(0xFF15402F),
    onBid: Color(0xFFA6E3C8),
    noBid: Color(0xFF5C1712),
    onNoBid: Color(0xFFFFB4AB),
    review: Color(0xFF4D3800),
    onReview: Color(0xFFF7D77E),
    neutral: Color(0xFF2B3437),
    onNeutral: Color(0xFFC3CDCF),
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
    );
  }
}

extension StatusColorsX on BuildContext {
  StatusColors get statusColors =>
      Theme.of(this).extension<StatusColors>() ?? StatusColors.light;
}
