import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// The BidRadar logo: three radar arcs spreading from a corner dot, with a
/// mustard blip, on a black rounded tile. Same artwork as the launcher icon.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 48, this.tile = true});

  final double size;

  /// Draw the black rounded tile behind the arcs. Turn off when the mark sits
  /// on a dark surface already (splash, hero card).
  final bool tile;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'BidRadar logo',
    image: true,
    child: CustomPaint(
      size: Size.square(size),
      painter: _BrandMarkPainter(tile: tile),
    ),
  );
}

class _BrandMarkPainter extends CustomPainter {
  const _BrandMarkPainter({required this.tile});

  final bool tile;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 108; // the artwork is drawn on a 108 grid
    if (tile) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(30 * s)),
        Paint()..color = Brand.ink,
      );
    }
    // Each arc starts at the corner dot and bends up to the right, like a
    // signal spreading out (centre one radius to the right of the dot).
    final origin = Offset(30 * s, 78 * s);
    for (final (r, alpha) in [(48.0, .45), (32.0, .75), (16.0, 1.0)]) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset((30 + r) * s, 78 * s), radius: r * s),
        math.pi,
        math.pi / 2,
        false,
        Paint()
          ..color = Brand.ember.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7 * s
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawCircle(origin, 6 * s, Paint()..color = Brand.ember);
    canvas.drawCircle(
      Offset(76 * s, 62 * s),
      6.5 * s,
      Paint()..color = Brand.mustard,
    );
  }

  @override
  bool shouldRepaint(covariant _BrandMarkPainter oldDelegate) =>
      oldDelegate.tile != tile;
}
