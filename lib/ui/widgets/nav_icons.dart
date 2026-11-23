import 'package:material_ui/material_ui.dart';

/// The five tab icons of the Klasik mockup, drawn from its SVG paths
/// (24-unit viewBox, 1.5 stroke).
enum NavGlyph { bugun, yetenekler, odak, ag, karakter }

class NavIcon extends StatelessWidget {
  const NavIcon(this.glyph, {super.key, required this.color, this.size = 22});

  final NavGlyph glyph;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _NavIconPainter(glyph, color)),
  );
}

class _NavIconPainter extends CustomPainter {
  const _NavIconPainter(this.glyph, this.color);

  final NavGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(_path(glyph), paint);
  }

  static Path _lines(List<(double, double, double, double)> segments) {
    final p = Path();
    for (final (x1, y1, x2, y2) in segments) {
      p
        ..moveTo(x1, y1)
        ..lineTo(x2, y2);
    }
    return p;
  }

  static Path _circle(double cx, double cy, double r) =>
      Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));

  static Path _path(NavGlyph glyph) => switch (glyph) {
    // Sun: circle r4 and eight rays.
    NavGlyph.bugun =>
      _circle(12, 12, 4)..addPath(
        _lines([
          (12, 3, 12, 5),
          (12, 19, 12, 21),
          (3, 12, 5, 12),
          (19, 12, 21, 12),
          (5.6, 5.6, 7, 7),
          (17, 17, 18.4, 18.4),
          (5.6, 18.4, 7, 17),
          (17, 7, 18.4, 5.6),
        ]),
        Offset.zero,
      ),
    // Three stacked layers.
    NavGlyph.yetenekler =>
      Path()
        ..moveTo(12, 4)
        ..lineTo(20, 8)
        ..lineTo(12, 12)
        ..lineTo(4, 8)
        ..close()
        ..moveTo(4, 12)
        ..lineTo(12, 16)
        ..lineTo(20, 12)
        ..moveTo(4, 16)
        ..lineTo(12, 20)
        ..lineTo(20, 16),
    // Stopwatch.
    NavGlyph.odak => _circle(
      12,
      13,
      7,
    )..addPath(_lines([(12, 13, 12, 9.5), (10, 3, 14, 3)]), Offset.zero),
    // Three linked nodes.
    NavGlyph.ag =>
      _circle(6, 7, 2.2)
        ..addPath(_circle(18, 6, 2.2), Offset.zero)
        ..addPath(_circle(12, 17, 2.6), Offset.zero)
        ..addPath(
          _lines([
            (7.4, 9, 10.8, 14.8),
            (16.8, 8, 13.2, 14.6),
            (8.2, 6.8, 15.8, 6.2),
          ]),
          Offset.zero,
        ),
    // Shield.
    NavGlyph.karakter =>
      Path()
        ..moveTo(12, 3)
        ..lineTo(19, 6)
        ..lineTo(19, 11)
        ..cubicTo(19, 15.5, 16, 19, 12, 21)
        ..cubicTo(8, 19, 5, 15.5, 5, 11)
        ..lineTo(5, 6)
        ..close(),
  };

  @override
  bool shouldRepaint(_NavIconPainter old) =>
      old.glyph != glyph || old.color != color;
}
