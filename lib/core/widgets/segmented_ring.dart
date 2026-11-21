import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Story ring split into one arc per status; seen arcs are muted.
class SegmentedRing extends StatelessWidget {
  const SegmentedRing({
    super.key,
    required this.child,
    required this.segments,
    required this.seenSegments,
    this.size = 60,
    this.strokeWidth = 2.6,
  });

  final Widget child;
  final int segments;
  final int seenSegments;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          segments: segments,
          seen: seenSegments,
          seenColor: context.palette.stroke,
          strokeWidth: strokeWidth,
        ),
        child: Padding(padding: EdgeInsets.all(strokeWidth + 2.5), child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.segments, required this.seen, required this.seenColor, required this.strokeWidth});

  final int segments;
  final int seen;
  final Color seenColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (segments <= 0) return;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(strokeWidth / 2);
    final gap = segments == 1 ? 0.0 : 0.12;
    final sweep = (2 * math.pi - gap * segments) / segments;
    final unseenPaint =
        Paint()
          ..shader = AppColors.storyRingGradient.createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;
    final seenPaint =
        Paint()
          ..color = seenColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;

    for (var i = 0; i < segments; i++) {
      final start = -math.pi / 2 + i * (sweep + gap) + gap / 2;
      canvas.drawArc(arcRect, start, sweep, false, i < seen ? seenPaint : unseenPaint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.segments != segments || old.seen != seen || old.seenColor != seenColor;
}
