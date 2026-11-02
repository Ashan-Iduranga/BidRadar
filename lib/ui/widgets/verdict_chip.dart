import 'package:flutter/material.dart';

import '../../core/theme/status_colors.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/enums.dart';

/// Shows a verdict with colour, icon and text. Never colour alone.
/// Pass `null` for a tender the agent has not judged yet.
class VerdictChip extends StatelessWidget {
  const VerdictChip({super.key, required this.verdict, this.dense = false});

  final VerdictKind? verdict;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = context.statusColors;
    final (bg, fg, icon, label) = switch (verdict) {
      VerdictKind.bid => (c.bid, c.onBid, Icons.check_circle_outline, 'Bid'),
      VerdictKind.noBid => (c.noBid, c.onNoBid, Icons.block, 'No bid'),
      VerdictKind.review => (
        c.review,
        c.onReview,
        Icons.rate_review_outlined,
        'Review',
      ),
      null => (c.neutral, c.onNeutral, Icons.hourglass_empty, 'Pending'),
    };

    return Semantics(
      label: 'Verdict: $label',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: dense ? Space.sm : Space.md,
          vertical: dense ? 2 : Space.xs,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(Radii.xs),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: dense ? 14 : IconSizes.sm, color: fg),
            const SizedBox(width: Space.xs),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: fg, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
