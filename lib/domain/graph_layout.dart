import 'dart:math' as math;

/// Diameter of a skill node for a given level.
double nodeDiameter(int level) => 2 * (4 + 1.9 * math.sqrt(level));

/// Fruchterman–Reingold style force-directed layout with a collision pass.
/// Deterministic for a given input and seed (only `math.Random(seed)`).
class GraphLayout {
  GraphLayout({
    required Map<String, double> radii,
    required List<(String, String)> edges,
    Map<String, (double, double)> initial = const {},
    int seed = 7,
  }) : _radii = Map.of(radii),
       _edges = [
         for (final (a, b) in edges)
           if (a != b && radii.containsKey(a) && radii.containsKey(b)) (a, b),
       ],
       _rng = math.Random(seed) {
    _place(initial);
  }

  static const double _k = 90;
  static const double _gravity = 0.02;
  static const double _startTemperature = 40;
  static const double _cooling = 0.98;
  static const double _gap = 8;
  static const double _settleThreshold = 0.5;
  static const int _settleStreakNeeded = 10;

  final Map<String, double> _radii;
  final List<(String, String)> _edges;
  final math.Random _rng;
  final Map<String, (double, double)> _pos = {};
  final Set<String> _pinned = {};
  double _temperature = _startTemperature;
  int _calmSteps = 0;

  Map<String, (double, double)> get positions => Map.unmodifiable(_pos);

  /// True once the largest displacement of free nodes stayed below 0.5 for
  /// 10 consecutive steps.
  bool get settled => _calmSteps >= _settleStreakNeeded;

  void _place(Map<String, (double, double)> initial) {
    final ids = _radii.keys.toList();
    for (final id in ids) {
      final p = initial[id];
      if (p != null) _pos[id] = p;
    }
    final neighbors = <String, List<String>>{};
    for (final (a, b) in _edges) {
      (neighbors[a] ??= []).add(b);
      (neighbors[b] ??= []).add(a);
    }
    final circleRadius = _k * math.max(1, math.sqrt(ids.length)) / 2;
    final phase = _rng.nextDouble() * 2 * math.pi;
    for (var i = 0; i < ids.length; i++) {
      final id = ids[i];
      if (_pos.containsKey(id)) continue;
      final placed = [
        for (final n in neighbors[id] ?? const <String>[])
          if (_pos[n] != null) _pos[n]!,
      ];
      if (placed.isNotEmpty) {
        _pos[id] = placeNear(placed, _rng);
      } else {
        final a = phase + 2 * math.pi * i / ids.length;
        _pos[id] = (circleRadius * math.cos(a), circleRadius * math.sin(a));
      }
    }
  }

  /// A point within 120 px of the neighbors' centroid.
  static (double, double) placeNear(
    List<(double, double)> neighbors,
    math.Random rng,
  ) {
    if (neighbors.isEmpty) return (0, 0);
    var cx = 0.0, cy = 0.0;
    for (final (x, y) in neighbors) {
      cx += x;
      cy += y;
    }
    cx /= neighbors.length;
    cy /= neighbors.length;
    final angle = rng.nextDouble() * 2 * math.pi;
    final dist = 40 + rng.nextDouble() * 40;
    return (cx + dist * math.cos(angle), cy + dist * math.sin(angle));
  }

  void pin(String id, double x, double y) {
    if (!_radii.containsKey(id)) return;
    _pinned.add(id);
    _pos[id] = (x, y);
    _calmSteps = 0;
  }

  void unpin(String id) {
    if (_pinned.remove(id)) _calmSteps = 0;
  }

  void step() {
    final ids = _pos.keys.toList();
    final dx = {for (final id in ids) id: 0.0};
    final dy = {for (final id in ids) id: 0.0};

    // Repulsion k²/d between every pair.
    for (var i = 0; i < ids.length; i++) {
      for (var j = i + 1; j < ids.length; j++) {
        final (ax, ay) = _pos[ids[i]]!;
        final (bx, by) = _pos[ids[j]]!;
        var vx = ax - bx, vy = ay - by;
        var d = math.sqrt(vx * vx + vy * vy);
        if (d < 1e-6) {
          final a = _rng.nextDouble() * 2 * math.pi;
          vx = math.cos(a);
          vy = math.sin(a);
          d = 1;
        }
        final f = _k * _k / d;
        final fx = vx / d * f, fy = vy / d * f;
        dx[ids[i]] = dx[ids[i]]! + fx;
        dy[ids[i]] = dy[ids[i]]! + fy;
        dx[ids[j]] = dx[ids[j]]! - fx;
        dy[ids[j]] = dy[ids[j]]! - fy;
      }
    }
    // Attraction d²/k along edges.
    for (final (a, b) in _edges) {
      final (ax, ay) = _pos[a]!;
      final (bx, by) = _pos[b]!;
      final vx = ax - bx, vy = ay - by;
      final d = math.sqrt(vx * vx + vy * vy);
      if (d < 1e-6) continue;
      final f = d * d / _k;
      final fx = vx / d * f, fy = vy / d * f;
      dx[a] = dx[a]! - fx;
      dy[a] = dy[a]! - fy;
      dx[b] = dx[b]! + fx;
      dy[b] = dy[b]! + fy;
    }

    final before = Map.of(_pos);
    for (final id in ids) {
      if (_pinned.contains(id)) continue;
      final (x, y) = _pos[id]!;
      final fx = dx[id]! - _gravity * x;
      final fy = dy[id]! - _gravity * y;
      final mag = math.sqrt(fx * fx + fy * fy);
      if (mag < 1e-9) continue;
      final move = math.min(mag, _temperature);
      _pos[id] = (x + fx / mag * move, y + fy / mag * move);
    }
    _collide();

    var maxMove = 0.0;
    for (final id in ids) {
      if (_pinned.contains(id)) continue;
      final (x0, y0) = before[id]!;
      final (x1, y1) = _pos[id]!;
      maxMove = math.max(
        maxMove,
        math.sqrt(math.pow(x1 - x0, 2) + math.pow(y1 - y0, 2)),
      );
    }
    _calmSteps = maxMove < _settleThreshold ? _calmSteps + 1 : 0;
    _temperature *= _cooling;
  }

  void settle({int maxSteps = 600}) {
    for (var i = 0; i < maxSteps && !settled; i++) {
      step();
    }
    // Guarantee no overlap even if cooling stopped the pushes early.
    for (var i = 0; i < 200 && _collide(); i++) {}
  }

  /// Pushes overlapping pairs apart to r1 + r2 + 8. Returns whether any pair
  /// was moved.
  bool _collide() {
    final ids = _pos.keys.toList();
    var moved = false;
    for (var i = 0; i < ids.length; i++) {
      for (var j = i + 1; j < ids.length; j++) {
        final a = ids[i], b = ids[j];
        final aPinned = _pinned.contains(a), bPinned = _pinned.contains(b);
        if (aPinned && bPinned) continue;
        final (ax, ay) = _pos[a]!;
        final (bx, by) = _pos[b]!;
        var vx = ax - bx, vy = ay - by;
        var d = math.sqrt(vx * vx + vy * vy);
        final minD = _radii[a]! + _radii[b]! + _gap;
        if (d >= minD) continue;
        if (d < 1e-6) {
          final ang = _rng.nextDouble() * 2 * math.pi;
          vx = math.cos(ang);
          vy = math.sin(ang);
          d = 1;
        }
        // Small epsilon so floating point rounding cannot leave d < minD.
        final push = (minD - d) + 1e-6;
        final ux = vx / d, uy = vy / d;
        final shareA = aPinned ? 0.0 : (bPinned ? 1.0 : 0.5);
        final shareB = 1 - shareA;
        _pos[a] = (ax + ux * push * shareA, ay + uy * push * shareA);
        _pos[b] = (bx - ux * push * shareB, by - uy * push * shareB);
        moved = true;
      }
    }
    return moved;
  }
}
