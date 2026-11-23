import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'package:flutter/foundation.dart';

import '../../app/views.dart';
import '../../domain/format.dart';
import '../../domain/graph_layout.dart';
import '../../domain/models.dart';
import '../../domain/stats.dart';

/// Writes graph positions (only those that changed) to storage.
typedef SavePositions = Future<void> Function(
  Map<String, (double, double)> positions,
);

/// Space between a node and its label, and the label's line height.
const double graphLabelGap = 5;
const double graphLabelHeight = 14;

/// Opacity of nodes that are not highlighted (§5.11).
const double graphDimmedOpacity = 0.3;

/// "+6 dk" style: minutes of bonus one hour earns each linked skill.
String bonusMinutesLabel(int rateBp) {
  final tenths = (rateBp * 6 / 100).round(); // bp·60/10000 min, in tenths
  final whole = tenths ~/ 10, frac = tenths % 10;
  // A no-break space keeps "+6 dk" on one line.
  return frac == 0 ? '$whole\u00a0dk' : '$whole,$frac\u00a0dk';
}

/// Maps layout coordinates onto the canvas: `canvas = origin + graph·scale`.
/// Only positions are scaled; nodes and labels keep their size.
@immutable
class GraphViewport {
  const GraphViewport(this.origin, this.scale);

  final Offset origin;
  final double scale;

  Offset toCanvas((double, double) p) =>
      origin + Offset(p.$1 * scale, p.$2 * scale);

  (double, double) toGraph(Offset canvas) {
    final g = (canvas - origin) / scale;
    return (g.dx, g.dy);
  }
}

/// The state of the skill graph, free of widgets: which skills and links
/// are shown, where they are, what is selected or filtered, the node being
/// dragged, and when positions are saved.
///
/// The simulation advances with [tick] (one call per frame) or all at once
/// with [settle]; positions are saved [saveDelay] after the layout comes to
/// rest, never while it moves.
class GraphController extends ChangeNotifier {
  GraphController({
    required this.savePositions,
    this.saveDelay = const Duration(milliseconds: 400),
    this.stepsPerTick = 3,
    this.maxSteps = 600,
  });

  final SavePositions savePositions;
  final Duration saveDelay;
  final int stepsPerTick;

  /// Step budget of one run (after opening, a data change or a drag).
  final int maxSteps;

  static const double _minFitScale = 0.5;
  static const double _defaultLabelHalfWidth = 40;

  List<SkillView> _nodes = const [];
  Map<String, SkillView> _byId = const {};
  List<(String, String)> _edges = const [];
  Map<String, Set<String>> _neighbors = const {};
  String _topology = '';
  String _sizes = '';
  GraphLayout? _layout;
  bool _simulating = false;
  int _stepsLeft = 0;

  Rect _frame = Rect.zero;
  Map<String, double> _labelHalfWidths = const {};
  GraphViewport? _viewport;

  // Caches refreshed only when positions, sizes, the frame or the view
  // change, so painting and hit-testing never copy the layout.
  Map<String, (double, double)> _positions = const {};
  Map<String, double> _radius = const {};
  Map<String, Offset> _canvas = const {};
  GraphViewport? _target;

  String? _selectedId;
  Stat? _filter;
  String? _draggingId;
  Offset _grabOffset = Offset.zero;
  Timer? _saveTimer;

  /// Shown skills: every skill that is not archived.
  List<SkillView> get nodes => _nodes;

  /// Links between shown skills, each once.
  List<(String, String)> get edges => _edges;

  Map<String, (double, double)> get positions => _positions;

  /// Whether [tick] still has work: the simulation runs or the view is
  /// still moving to fit the graph.
  bool get running =>
      _simulating || (_draggingId == null && !_viewportAtTarget());

  GraphViewport get viewport => _viewport ?? GraphViewport(_frame.center, 1);

  String? get selectedId => _selectedId;
  SkillView? get selected => _byId[_selectedId];
  Stat? get filter => _filter;
  String? get draggingId => _draggingId;

  /// The view of [id], or null when it is not shown.
  SkillView? viewOf(String id) => _byId[id];

  // -------------------------------------------------------------------------
  // Data

  /// Shows [views] (archived ones are left out) linked by [links]. The
  /// layout is rebuilt only when the shown skills, their sizes or the links
  /// change; current positions, then saved ones, are its starting point and
  /// new skills go next to their linked skills.
  void setData(List<SkillView> views, List<SkillLink> links) {
    final shown = [
      for (final v in views)
        if (!v.skill.archived) v,
    ];
    final byId = {for (final v in shown) v.skill.id: v};
    final edges = <(String, String)>[];
    final seen = <String>{};
    for (final l in links) {
      if (!byId.containsKey(l.a) || !byId.containsKey(l.b) || l.a == l.b) {
        continue;
      }
      final (a, b) = l.a.compareTo(l.b) < 0 ? (l.a, l.b) : (l.b, l.a);
      if (seen.add('$a|$b')) edges.add((a, b));
    }
    edges.sort((x, y) {
      final c = x.$1.compareTo(y.$1);
      return c != 0 ? c : x.$2.compareTo(y.$2);
    });
    final ids = byId.keys.toList()..sort();
    final topology = [...ids, for (final (a, b) in edges) '$a|$b'].join(',');
    final sizes = [for (final id in ids) byId[id]!.level].join(',');

    _nodes = shown;
    _byId = byId;
    _edges = edges;
    _neighbors = {for (final id in ids) id: <String>{}};
    for (final (a, b) in edges) {
      _neighbors[a]!.add(b);
      _neighbors[b]!.add(a);
    }
    if (!byId.containsKey(_selectedId)) _selectedId = null;
    if (!byId.containsKey(_draggingId)) _draggingId = null;
    _radius = {for (final v in shown) v.skill.id: nodeDiameter(v.level) / 2};
    final opening = _layout == null;
    final relink = topology != _topology;
    if (!relink && sizes == _sizes) return;

    _topology = topology;
    _sizes = sizes;
    final current = positions;
    final layout = _layout = GraphLayout(
      radii: _radius,
      edges: edges,
      initial: {
        for (final v in shown)
          if (current[v.skill.id] case final p?)
            v.skill.id: p
          else if ((v.skill.graphX, v.skill.graphY) case (
            final double x,
            final double y,
          ))
            v.skill.id: (x, y),
      },
    );
    final dragging = _draggingId;
    if (dragging != null) {
      final (x, y) = layout.positions[dragging]!;
      layout.pin(dragging, x, y);
    }
    final allPlaced = shown.every(
      (v) =>
          current.containsKey(v.skill.id) ||
          (v.skill.graphX != null && v.skill.graphY != null),
    );
    if (_simulating || (relink && !(opening && allPlaced))) {
      _restart();
    } else {
      // A saved picture is already at rest: re-running the simulation from
      // a cooled layout would shift it on every open. Size changes only
      // need overlaps pushed apart.
      _saveTimer?.cancel();
      layout.settle(maxSteps: 0);
      _simulating = false;
      if (_draggingId == null) _scheduleSave();
    }
    _syncPositions();
    if (opening) _viewport = _target;
    _syncCanvas();
  }

  /// The drawable area of the canvas and the half widths of node labels,
  /// which the view keeps clear when fitting the graph.
  void setFrame(Rect frame, {Map<String, double> labelHalfWidths = const {}}) {
    final first = _frame == Rect.zero;
    _frame = frame;
    _labelHalfWidths = labelHalfWidths;
    _target = _fit();
    if (first || !running) _viewport = _target;
    _syncCanvas();
  }

  void _syncPositions() {
    _positions = _layout?.positions ?? const {};
    _target = _fit();
  }

  void _syncCanvas() {
    final v = viewport;
    _canvas = {
      for (final MapEntry(key: id, value: p) in _positions.entries)
        id: v.toCanvas(p),
    };
  }

  // -------------------------------------------------------------------------
  // Simulation

  void _restart() {
    _simulating = true;
    _stepsLeft = maxSteps;
    _saveTimer?.cancel();
    _saveTimer = null;
  }

  /// Advances one frame. Returns whether more frames are needed.
  bool tick() {
    if (_simulating) {
      _step(stepsPerTick);
      _syncPositions();
    }
    if (_draggingId == null) _moveViewport();
    _syncCanvas();
    notifyListeners();
    return running;
  }

  /// Runs the simulation to rest synchronously.
  void settle() {
    while (_simulating) {
      _step(maxSteps);
    }
    _syncPositions();
    if (_draggingId == null) _viewport = _target;
    _syncCanvas();
    notifyListeners();
  }

  void _step(int steps) {
    final layout = _layout!;
    for (var i = 0; i < steps && !layout.settled && _stepsLeft > 0; i++) {
      layout.step();
      _stepsLeft--;
    }
    if (layout.settled || _stepsLeft == 0) {
      layout.settle(maxSteps: 0); // final overlap clean-up only
      _simulating = false;
      if (_draggingId == null) _scheduleSave();
    }
  }

  // -------------------------------------------------------------------------
  // Selection and filter

  void select(String? id) {
    final next = _byId.containsKey(id) ? id : null;
    if (next == _selectedId) return;
    _selectedId = next;
    notifyListeners();
  }

  void setFilter(Stat? stat) {
    if (stat == _filter) return;
    _filter = stat;
    notifyListeners();
  }

  /// Linked shown skills of [id], sorted by name.
  List<SkillView> neighborsOf(String id) =>
      [for (final n in _neighbors[id] ?? const <String>{}) _byId[n]!]
        ..sort((a, b) => trCompare(a.skill.name, b.skill.name));

  bool matchesFilter(SkillView v) {
    final f = _filter;
    return f == null || v.skill.primary == f || v.skill.secondary == f;
  }

  /// 1, or [graphDimmedOpacity] when the filter or the selection leaves the
  /// node out.
  double opacityOf(String id) {
    final v = _byId[id];
    if (v == null || !matchesFilter(v)) return graphDimmedOpacity;
    final sel = _selectedId;
    if (sel == null || sel == id || _neighbors[sel]!.contains(id)) return 1;
    return graphDimmedOpacity;
  }

  /// Whether the link a–b touches the selected node.
  bool isHighlighted(String a, String b) =>
      _selectedId != null && (a == _selectedId || b == _selectedId);

  // -------------------------------------------------------------------------
  // Canvas geometry

  Offset canvasOf(String id) => _canvas[id] ?? viewport.origin;

  /// Radius of the node of [id] (0 when it is not shown).
  double radiusOf(String id) => _radius[id] ?? 0;

  /// The node under [canvasPoint]: the nearest one whose touch target, at
  /// least [minRadius] (22 px = a 44 px target at zoom 1), contains it.
  String? nodeAt(Offset canvasPoint, {double minRadius = 22}) {
    String? best;
    var bestDistance = double.infinity;
    for (final MapEntry(key: id, value: c) in _canvas.entries) {
      final d = (c - canvasPoint).distance;
      final reach = math.max(_radius[id] ?? 0, minRadius);
      if (d <= reach && d < bestDistance) {
        best = id;
        bestDistance = d;
      }
    }
    return best;
  }

  /// The view that fits every node, its label included, into the frame at
  /// a position scale of at most 1.
  GraphViewport _fit() {
    final p = _positions;
    if (p.isEmpty || _frame.isEmpty) return GraphViewport(_frame.center, 1);
    final items = [
      for (final MapEntry(key: id, value: pos) in p.entries)
        (
          pos: pos,
          half: math.max(
            _radius[id] ?? 0,
            _labelHalfWidths[id] ?? _defaultLabelHalfWidth,
          ),
          r: _radius[id] ?? 0,
        ),
    ];
    (double, double, double, double) box(double s) {
      var l = double.infinity, t = double.infinity;
      var r = -double.infinity, b = -double.infinity;
      for (final i in items) {
        final x = i.pos.$1 * s, y = i.pos.$2 * s;
        l = math.min(l, x - i.half);
        r = math.max(r, x + i.half);
        t = math.min(t, y - i.r);
        b = math.max(b, y + i.r + graphLabelGap + graphLabelHeight);
      }
      return (l, t, r, b);
    }

    bool fits(double s) {
      final (l, t, r, b) = box(s);
      return r - l <= _frame.width && b - t <= _frame.height;
    }

    var scale = 1.0;
    if (!fits(1)) {
      var lo = _minFitScale, hi = 1.0;
      for (var i = 0; i < 24; i++) {
        final mid = (lo + hi) / 2;
        if (fits(mid)) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      scale = lo;
    }
    final (l, t, r, b) = box(scale);
    return GraphViewport(
      _frame.center - Offset((l + r) / 2, (t + b) / 2),
      scale,
    );
  }

  bool _viewportAtTarget() {
    final v = _viewport, target = _target;
    if (v == null || target == null) return true;
    return (v.origin - target.origin).distance < 0.5 &&
        (v.scale - target.scale).abs() < 0.001;
  }

  /// Eases the view toward the fit, so it follows the moving graph without
  /// jumps.
  void _moveViewport() {
    final v = _viewport, target = _target;
    if (target == null) return;
    if (v == null || _viewportAtTarget()) {
      _viewport = target;
      return;
    }
    const t = 0.25;
    _viewport = GraphViewport(
      Offset.lerp(v.origin, target.origin, t)!,
      v.scale + (target.scale - v.scale) * t,
    );
  }

  // -------------------------------------------------------------------------
  // Dragging

  /// Starts dragging [id], grabbed at [canvasPoint].
  void dragStart(String id, Offset canvasPoint) {
    if (!_byId.containsKey(id)) return;
    _draggingId = id;
    _grabOffset = canvasOf(id) - canvasPoint;
    _saveTimer?.cancel();
    _saveTimer = null;
  }

  /// Pins the dragged node under [canvasPoint]; the others respond.
  void dragTo(Offset canvasPoint) {
    final id = _draggingId;
    if (id == null) return;
    final (x, y) = viewport.toGraph(canvasPoint + _grabOffset);
    _layout!.pin(id, x, y);
    _restart();
    _syncPositions();
    _syncCanvas();
    notifyListeners();
  }

  /// Releases the dragged node; the layout settles again and is saved.
  void dragEnd() {
    final id = _draggingId;
    if (id == null) return;
    _draggingId = null;
    final before = positions[id];
    _layout!.unpin(id);
    // unpin() only reheats a pinned node: a drag that never moved changes
    // nothing.
    if (before != null && !_layout!.settled) _restart();
    if (!_simulating) _scheduleSave();
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // Saving

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(saveDelay, _save);
  }

  void _save() {
    _saveTimer = null;
    final changed = <String, (double, double)>{};
    for (final MapEntry(key: id, value: (x, y)) in positions.entries) {
      final s = _byId[id]?.skill;
      if (s == null) continue;
      final sx = s.graphX, sy = s.graphY;
      if (sx == null || sy == null || (sx - x).abs() + (sy - y).abs() > 0.5) {
        changed[id] = (x, y);
      }
    }
    if (changed.isEmpty) return;
    // Best effort: unsaved positions are recomputed on the next open, but
    // the failure is reported so it does not go unnoticed.
    unawaited(
      savePositions(changed).catchError((Object error, StackTrace stack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'mesk graph',
            context: ErrorDescription('while saving graph positions'),
          ),
        );
      }),
    );
  }

  @override
  void dispose() {
    if (_saveTimer != null) {
      _saveTimer!.cancel();
      _save();
    }
    super.dispose();
  }
}
