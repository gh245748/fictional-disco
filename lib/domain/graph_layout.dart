import 'dart:math' as math;
import 'dart:typed_data';

/// Diameter of a skill node for a given level.
double nodeDiameter(int level) => 2 * (4 + 1.9 * math.sqrt(level));

/// Fruchterman–Reingold style force-directed layout with a collision pass.
/// Deterministic for a given input and seed (only `math.Random(seed)`).
///
/// State is held in index-addressed typed lists so a step does no map
/// lookups or allocations (smooth for ~150 nodes).
class GraphLayout {
  GraphLayout({
    required Map<String, double> radii,
    required List<(String, String)> edges,
    Map<String, (double, double)> initial = const {},
    int seed = 7,
  }) : _ids = radii.keys.toList(growable: false),
       _rng = math.Random(seed) {
    final n = _ids.length;
    final index = {for (var i = 0; i < n; i++) _ids[i]: i};
    _radius = Float64List(n);
    _x = Float64List(n);
    _y = Float64List(n);
    _dx = Float64List(n);
    _dy = Float64List(n);
    _sx = Float64List(n);
    _sy = Float64List(n);
    _pinned = List<bool>.filled(n, false);
    for (var i = 0; i < n; i++) {
      _radius[i] = radii[_ids[i]]!;
    }
    final seen = <int>{};
    final ea = <int>[], eb = <int>[];
    for (final (a, b) in edges) {
      final ia = index[a], ib = index[b];
      if (ia == null || ib == null || ia == ib) continue;
      final lo = math.min(ia, ib), hi = math.max(ia, ib);
      if (seen.add(lo * n + hi)) {
        ea.add(lo);
        eb.add(hi);
      }
    }
    _edgeA = Int32List.fromList(ea);
    _edgeB = Int32List.fromList(eb);
    _place(initial, index);
  }

  static const double _k = 90;

  /// Pairs farther apart than this do not repel (Fruchterman–Reingold's
  /// 2k cut-off). Without it, k²/d from every other node outweighs the
  /// gravity and pushes unlinked islands about 2000 px away.
  static const double _repulsionCutoff = 2 * _k;
  static const double _gravity = 0.02;
  static const double _startTemperature = 40;
  static const double _reheatTemperature = 10;
  static const double _cooling = 0.98;
  static const double _gap = 8;
  static const double _settleThreshold = 0.5;
  static const int _settleStreakNeeded = 10;

  final List<String> _ids;
  final math.Random _rng;
  late final Float64List _radius, _x, _y, _dx, _dy, _sx, _sy;
  late final List<bool> _pinned;
  late final Int32List _edgeA, _edgeB;
  double _temperature = _startTemperature;
  int _calmSteps = 0;

  Map<String, (double, double)> get positions => Map.unmodifiable({
    for (var i = 0; i < _ids.length; i++) _ids[i]: (_x[i], _y[i]),
  });

  /// True once the largest displacement of free nodes stayed below 0.5 for
  /// 10 consecutive steps.
  bool get settled => _calmSteps >= _settleStreakNeeded;

  void _place(Map<String, (double, double)> initial, Map<String, int> index) {
    final n = _ids.length;
    final placed = List<bool>.filled(n, false);
    for (var i = 0; i < n; i++) {
      final p = initial[_ids[i]];
      if (p != null) {
        _x[i] = p.$1;
        _y[i] = p.$2;
        placed[i] = true;
      }
    }
    final neighbors = List.generate(n, (_) => <int>[]);
    for (var e = 0; e < _edgeA.length; e++) {
      neighbors[_edgeA[e]].add(_edgeB[e]);
      neighbors[_edgeB[e]].add(_edgeA[e]);
    }
    final circleRadius = _k * math.max(1, math.sqrt(n)) / 2;
    final phase = _rng.nextDouble() * 2 * math.pi;
    for (var i = 0; i < n; i++) {
      if (placed[i]) continue;
      final near = [
        for (final j in neighbors[i])
          if (placed[j]) (_x[j], _y[j]),
      ];
      if (near.isNotEmpty) {
        final p = placeNear(near, _rng);
        _x[i] = p.$1;
        _y[i] = p.$2;
      } else {
        final a = phase + 2 * math.pi * i / n;
        _x[i] = circleRadius * math.cos(a);
        _y[i] = circleRadius * math.sin(a);
      }
      placed[i] = true;
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
    final i = _ids.indexOf(id);
    if (i < 0) return;
    _pinned[i] = true;
    _x[i] = x;
    _y[i] = y;
    _reheat();
  }

  void unpin(String id) {
    final i = _ids.indexOf(id);
    if (i < 0 || !_pinned[i]) return;
    _pinned[i] = false;
    _reheat();
  }

  void _reheat() {
    _temperature = math.max(_temperature, _reheatTemperature);
    _calmSteps = 0;
  }

  void step() {
    final n = _ids.length;
    _sx.setAll(0, _x);
    _sy.setAll(0, _y);
    _dx.fillRange(0, n, 0);
    _dy.fillRange(0, n, 0);

    // Repulsion k²/d between every pair closer than the cut-off.
    const k2 = _k * _k;
    const cutoff2 = _repulsionCutoff * _repulsionCutoff;
    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        var vx = _x[i] - _x[j], vy = _y[i] - _y[j];
        var d2 = vx * vx + vy * vy;
        if (d2 < 1e-12) {
          final a = _rng.nextDouble() * 2 * math.pi;
          vx = math.cos(a);
          vy = math.sin(a);
          d2 = 1;
        }
        if (d2 > cutoff2) continue;
        // force k²/d along unit vector (vx/d, vy/d) = k² * v / d².
        final f = k2 / d2;
        final fx = vx * f, fy = vy * f;
        _dx[i] += fx;
        _dy[i] += fy;
        _dx[j] -= fx;
        _dy[j] -= fy;
      }
    }
    // Attraction d²/k along edges.
    for (var e = 0; e < _edgeA.length; e++) {
      final a = _edgeA[e], b = _edgeB[e];
      final vx = _x[a] - _x[b], vy = _y[a] - _y[b];
      final d = math.sqrt(vx * vx + vy * vy);
      if (d < 1e-6) continue;
      final f = d / _k; // d²/k times unit vector v/d
      final fx = vx * f, fy = vy * f;
      _dx[a] -= fx;
      _dy[a] -= fy;
      _dx[b] += fx;
      _dy[b] += fy;
    }

    for (var i = 0; i < n; i++) {
      if (_pinned[i]) continue;
      final fx = _dx[i] - _gravity * _x[i];
      final fy = _dy[i] - _gravity * _y[i];
      final mag = math.sqrt(fx * fx + fy * fy);
      if (mag < 1e-9) continue;
      final move = math.min(mag, _temperature) / mag;
      _x[i] += fx * move;
      _y[i] += fy * move;
    }
    _collide();

    var maxMove = 0.0;
    for (var i = 0; i < n; i++) {
      if (_pinned[i]) continue;
      final mx = _x[i] - _sx[i], my = _y[i] - _sy[i];
      maxMove = math.max(maxMove, math.sqrt(mx * mx + my * my));
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
    final n = _ids.length;
    var moved = false;
    for (var a = 0; a < n; a++) {
      for (var b = a + 1; b < n; b++) {
        final aPinned = _pinned[a], bPinned = _pinned[b];
        if (aPinned && bPinned) continue;
        var vx = _x[a] - _x[b], vy = _y[a] - _y[b];
        var d = math.sqrt(vx * vx + vy * vy);
        final minD = _radius[a] + _radius[b] + _gap;
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
        _x[a] += ux * push * shareA;
        _y[a] += uy * push * shareA;
        _x[b] -= ux * push * shareB;
        _y[b] -= uy * push * shareB;
        moved = true;
      }
    }
    return moved;
  }
}
