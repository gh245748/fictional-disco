import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../domain/stat_calc.dart';
import '../../domain/stats.dart';
import '../theme.dart';

/// Hexagonal stat radar (spec §5.6): axes clockwise from Zihin at the top,
/// each value drawn at `√(value / scale)` of the radius.
class RadarChart extends StatelessWidget {
  const RadarChart({super.key, required this.values, required this.size});

  /// Raw stat values; missing stats count as 0.
  final Map<Stat, double> values;
  final double size;

  /// The highest stat, or null when every value is 0. Ties go to the stat
  /// that comes first in [radarOrder].
  Stat? get highest {
    Stat? best;
    var max = 0.0;
    for (final s in radarOrder) {
      final v = values[s] ?? 0;
      if (v > max) {
        max = v;
        best = s;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final top = highest;
    return Semantics(
      image: true,
      label: top == null
          ? 'Stat dağılımı'
          : 'Stat dağılımı, en yüksek stat ${top.label}',
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _RadarPainter(values, top)),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.values, this.highest);

  final Map<Stat, double> values;
  final Stat? highest;

  /// Geometry of the mockup's 110-unit viewBox.
  static const double _box = 110;
  static const double _radius = 46;
  static const Color _outerGrid = Color(0xFF302D29);

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.shortestSide / _box;
    final center = size.center(Offset.zero);
    final r = _radius * k;

    Offset vertex(int i, double fraction) {
      final angle = -math.pi / 2 + i * math.pi / 3;
      return center + Offset(math.cos(angle), math.sin(angle)) * (r * fraction);
    }

    Path polygon(double Function(int i) fraction) {
      final path = Path()
        ..moveTo(vertex(0, fraction(0)).dx, vertex(0, fraction(0)).dy);
      for (var i = 1; i < radarOrder.length; i++) {
        final p = vertex(i, fraction(i));
        path.lineTo(p.dx, p.dy);
      }
      return path..close();
    }

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = k;
    canvas
      ..drawPath(polygon((_) => 1), line..color = _outerGrid)
      ..drawPath(polygon((_) => 0.5), line..color = MeskColors.surfaceBorder);
    for (var i = 0; i < radarOrder.length; i++) {
      canvas.drawLine(center, vertex(i, 1), line);
    }

    final scale = radarScale([for (final s in radarOrder) values[s] ?? 0]);
    double fraction(int i) => radarRadius(values[radarOrder[i]] ?? 0, scale);
    final shape = polygon(fraction);
    canvas
      ..drawPath(
        shape,
        Paint()..color = MeskColors.accent.withValues(alpha: 0.15),
      )
      ..drawPath(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4 * k
          ..strokeJoin = StrokeJoin.round
          ..color = MeskColors.accent,
      );

    final top = highest;
    if (top != null) {
      final i = radarOrder.indexOf(top);
      canvas.drawCircle(
        vertex(i, fraction(i)),
        2.5 * k,
        Paint()..color = MeskColors.accent,
      );
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.highest != highest || !_sameValues(old.values, values);

  static bool _sameValues(Map<Stat, double> a, Map<Stat, double> b) =>
      radarOrder.every((s) => (a[s] ?? 0) == (b[s] ?? 0));
}
