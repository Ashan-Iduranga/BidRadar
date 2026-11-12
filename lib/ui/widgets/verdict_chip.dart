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
      VerdictKind.bid => (
        c.bid,
        c.onBid,
        Icons.check_circle_outline_rounded,
        'Bid',
      ),
      VerdictKind.noBid => (c.noBid, c.onNoBid, Icons.block_rounded, 'No bid'),
      VerdictKind.review => (
        c.review,
        c.onReview,
        Icons.manage_search_rounded,
        'Review',
      ),
      null => (
        c.neutral,
        c.onNeutral,
        Icons.hourglass_empty_rounded,
        'Pending',
      ),
    };

    return Semantics(
      label: 'Verdict: $label',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 10 : Space.md,
          vertical: dense ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: dense ? 14 : IconSizes.sm, color: fg),
            const SizedBox(width: 5),
            Text(
              label,
              style:
                  (dense
                          ? Theme.of(context).textTheme.labelMedium
                          : Theme.of(context).textTheme.labelLarge)
                      ?.copyWith(color: fg, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
