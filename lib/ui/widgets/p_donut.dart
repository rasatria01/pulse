import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../tokens.dart';

/// A ring split by [segments], with [center] inside. It is decoration to a
/// screen reader: the list next to it names every slice and its value.
class PDonut extends StatelessWidget {
  const PDonut({super.key, required this.segments, required this.center});

  /// Values above zero, drawn clockwise from the top.
  final List<({int value, Color color})> segments;
  final Widget center;

  static const double _size = 200;
  static const double _stroke = 28;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: _size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: ExcludeSemantics(
            child: CustomPaint(painter: _DonutPainter(segments)),
          ),
        ),
        SizedBox(
          width: _size - 2 * _stroke - 2 * MelaSpace.s3,
          child: FittedBox(fit: BoxFit.scaleDown, child: center),
        ),
      ],
    ),
  );
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter(this.segments);

  final List<({int value, Color color})> segments;

  @override
  void paint(Canvas canvas, Size size) {
    final total = segments.fold(0, (sum, s) => sum + s.value);
    if (total <= 0) return;
    final rect = (Offset.zero & size).deflate(PDonut._stroke / 2);
    // 2px of surface between slices.
    final gap = segments.length > 1 ? 2 / (rect.width / 2) : 0.0;
    var start = -math.pi / 2;
    for (final segment in segments) {
      final sweep = 2 * math.pi * segment.value / total;
      canvas.drawArc(
        rect,
        start + gap / 2,
        // A sliver still shows.
        math.max(sweep - gap, 0.01),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = PDonut._stroke
          ..color = segment.color,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.segments.length != segments.length ||
      segments.indexed.any((s) => old.segments[s.$1] != s.$2);
}
