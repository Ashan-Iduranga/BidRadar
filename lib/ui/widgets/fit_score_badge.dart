import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/status_colors.dart';
import '../../core/theme/tokens.dart';

/// Fit score 0 to 100 as a ring (coloured by band) plus the number (tabular
/// figures so lists don't jitter). `null` shows a dash for "not scored yet".
/// The ring fills in when it first appears, unless animations are off.
class FitScoreBadge extends StatelessWidget {
  const FitScoreBadge({
    super.key,
    required this.score,
    this.size = 46,
    this.stroke,
    this.track,
    this.textColor,
    this.label,
  });

  final int? score;
  final double size;

  /// Ring width; defaults to about a tenth of [size].
  final double? stroke;

  /// Track colour behind the ring (use a hero-safe colour on hero cards).
  final Color? track;
  final Color? textColor;

  /// Small caption under the number, for big rings ("fit").
  final String? label;

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final marks = context.statusColors;
    final value = score?.clamp(0, 100);
    // Ring colour follows the score band; the number is always shown too.
    final ring = value == null
        ? Theme.of(context).colorScheme.outline
        : value >= 70
        ? marks.bidMark
        : value >= 40
        ? marks.reviewMark
        : marks.noBidMark;
    final target = value == null ? 0.0 : value / 100;
    final still = reduceMotion(context);
    final text = Theme.of(context).textTheme;
    final numberStyle = (size >= 80 ? text.headlineMedium : text.labelLarge)
        ?.copyWith(
          fontWeight: FontWeight.w800,
          color: textColor ?? b.ink,
          fontFeatures: const [FontFeature.tabularFigures()],
        );

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
            // Only the ring animates; the number is always the real score.
            TweenAnimationBuilder<double>(
              tween: Tween(begin: still ? target : 0, end: target),
              duration: const Duration(milliseconds: 900),
              curve: Motion.emphasized,
              builder: (context, v, _) => CircularProgressIndicator(
                value: v,
                strokeWidth: stroke ?? (size / 10).clamp(4, 12),
                strokeCap: StrokeCap.round,
                backgroundColor: track ?? b.surface2,
                color: ring,
                constraints: BoxConstraints.tight(Size.square(size)),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value?.toString() ?? '–', style: numberStyle),
                if (label != null)
                  Text(
                    label!,
                    style: text.labelSmall?.copyWith(
                      color: (textColor ?? b.ink).withValues(alpha: .8),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Spacing helper kept here so the badge's sizing stays on the 4 dp grid.
const double kFitScoreGap = Space.md;
