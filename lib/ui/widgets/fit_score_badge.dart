import 'package:flutter/material.dart';

import '../../core/theme/status_colors.dart';
import '../../core/theme/tokens.dart';

/// Fit score 0 to 100 as a ring (coloured by band) plus the number (tabular figures so lists
/// don't jitter). `null` shows a dash for "not scored yet".
class FitScoreBadge extends StatelessWidget {
  const FitScoreBadge({super.key, required this.score, this.size = 44});

  final int? score;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final marks = context.statusColors;
    final value = score?.clamp(0, 100);
    // Ring colour follows the score band; the number is always shown too.
    final ring = value == null
        ? scheme.outline
        : value >= 70
        ? marks.bidMark
        : value >= 40
        ? marks.reviewMark
        : marks.noBidMark;

    return Semantics(
      label: value == null
          ? 'Fit score not available'
          : 'Fit score $value of 100',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: value == null ? 0 : value / 100,
              strokeWidth: 4,
              strokeCap: StrokeCap.round,
              backgroundColor: scheme.surfaceContainerHighest,
              color: ring,
              constraints: BoxConstraints.tight(Size.square(size)),
            ),
            Text(
              value?.toString() ?? '–',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Spacing helper kept here so the badge's sizing stays on the 4 dp grid.
const double kFitScoreGap = Space.md;
