import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// A circular progress ring that starts at 12 o'clock and runs clockwise.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    required this.size,
    required this.color,
    this.strokeWidth = 2.5,
    this.trackColor = MeskColors.track,
    this.child,
  });

  /// 0..1; values outside are clamped.
  final double value;
  final double size;
  final Color color;
  final double strokeWidth;
  final Color trackColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _RingPainter(
        value: value.clamp(0.0, 1.0),
        color: color,
        trackColor: trackColor,
        strokeWidth: strokeWidth,
      ),
      child: child == null ? null : Center(child: child),
    ),
  );
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.value,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double value;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (size.shortestSide - strokeWidth) / 2,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawArc(rect, 0, 2 * math.pi, false, paint);
    if (value <= 0) return;
    paint
      ..color = color
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * value, false, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}
