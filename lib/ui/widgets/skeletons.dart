import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';

/// Shimmering placeholders shaped like the content that is loading, instead
/// of a bare spinner. Screen readers hear "Loading" once.
class _Zone extends StatelessWidget {
  const _Zone({required this.child, this.label = 'Loading'});

  final Widget child;
  final String label;

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final effect = reduceMotion(context)
        ? SolidColorEffect(color: b.surface2)
        : ShimmerEffect(
            baseColor: b.surface2,
            highlightColor: b.surface,
            duration: const Duration(milliseconds: 1200),
          );
    return Semantics(
      label: label,
      liveRegion: true,
      excludeSemantics: true,
      child: Skeletonizer.zone(effect: effect, child: child),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: b.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        boxShadow: b.cardShadow,
      ),
      child: child,
    );
  }
}

/// A list of tender- or bid-shaped cards.
class CardListSkeleton extends StatelessWidget {
  const CardListSkeleton({
    super.key,
    this.count = 4,
    this.padding = const EdgeInsets.fromLTRB(
      Space.gutter,
      Space.sm,
      Space.gutter,
      Space.xl,
    ),
    this.label = 'Loading',
  });

  final int count;
  final EdgeInsets padding;
  final String label;

  @override
  Widget build(BuildContext context) => _Zone(
    label: label,
    child: ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: Space.md),
      itemBuilder: (_, _) => const _CardShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Bone.square(size: 44, uniRadius: 14),
                SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Bone.multiText(lines: 2, fontSize: 15),
                      SizedBox(height: 6),
                      Bone.text(words: 3, fontSize: 13),
                    ],
                  ),
                ),
                SizedBox(width: Space.md),
                Bone.circle(size: 46),
              ],
            ),
            SizedBox(height: Space.md),
            Row(
              children: [
                Bone(width: 64, height: 24, uniRadius: 12),
                SizedBox(width: Space.md),
                Bone.text(words: 2, fontSize: 12),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// A detail page: a hero block, a row of fact cards and two sections.
class DetailSkeleton extends StatelessWidget {
  const DetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) => _Zone(
    child: ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.sm,
        Space.gutter,
        Space.xl,
      ),
      children: const [
        Bone.multiText(lines: 2, fontSize: 24),
        SizedBox(height: Space.sm),
        Bone.text(words: 4, fontSize: 14),
        SizedBox(height: Space.lg),
        Bone(height: 150, uniRadius: Radii.lg),
        SizedBox(height: Space.md),
        Row(
          children: [
            Expanded(child: Bone(height: 84, uniRadius: Radii.md)),
            SizedBox(width: Space.sm),
            Expanded(child: Bone(height: 84, uniRadius: Radii.md)),
          ],
        ),
        SizedBox(height: Space.lg),
        Bone(height: 140, uniRadius: Radii.md),
      ],
    ),
  );
}
