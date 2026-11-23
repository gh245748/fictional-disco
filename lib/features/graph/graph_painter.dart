import 'dart:math' as math;

import 'package:flutter/semantics.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/views.dart';
import '../../domain/graph_layout.dart';
import '../../domain/level_curve.dart';
import '../../ui/theme.dart';
import 'graph_controller.dart';

/// Laid-out node labels (11 px Manrope), reused across frames.
class GraphLabels {
  final Map<String, TextPainter> _cache = {};

  static const TextStyle _style = TextStyle(
    fontFamily: MeskType.sans,
    fontSize: 11,
    height: graphLabelHeight / 11,
  );

  /// The label of [name] in its regular, highlighted or dimmed look.
  TextPainter label(
    String name, {
    required bool selected,
    required bool dimmed,
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    final key = '$name|$selected|$dimmed|${textScaler.scale(11)}';
    return _cache.putIfAbsent(
      key,
      () => TextPainter(
        text: TextSpan(
          text: name,
          style: _style.copyWith(
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: dimmed
                ? MeskColors.faint.withValues(alpha: 0.75)
                : MeskColors.text,
          ),
        ),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
        maxLines: 1,
      )..layout(),
    );
  }

  /// Half the regular label width of every node, for fitting the view.
  Map<String, double> halfWidths(
    Iterable<SkillView> nodes,
    TextScaler textScaler,
  ) => {
    for (final v in nodes)
      v.skill.id:
          label(
            v.skill.name,
            selected: true, // the widest weight
            dimmed: false,
            textScaler: textScaler,
          ).width /
          2,
  };

  void dispose() {
    for (final p in _cache.values) {
      p.dispose();
    }
    _cache.clear();
  }
}

/// Draws the skill graph of a [GraphController]: links first, then the
/// nodes in their stat colors with their labels underneath (§5.11).
class GraphPainter extends CustomPainter {
  GraphPainter({
    required this.controller,
    required this.pulse,
    required this.labels,
    required this.textScaler,
    required this.onNodeTap,
    required this.onNodeLongPress,
  }) : super(repaint: Listenable.merge([controller, pulse]));

  final GraphController controller;

  /// 0..1, the 2 s loop of the Efsane glow.
  final Animation<double> pulse;
  final GraphLabels labels;
  final TextScaler textScaler;
  final ValueChanged<String> onNodeTap;
  final ValueChanged<String> onNodeLongPress;

  static final double _selectionGlowSigma = Shadow.convertRadiusToSigma(24);

  @override
  void paint(Canvas canvas, Size size) {
    _paintEdges(canvas);
    final selected = controller.selectedId;
    for (final v in controller.nodes) {
      if (v.skill.id != selected) _paintNode(canvas, v);
    }
    // The selected node and its label on top.
    if (controller.selected case final v?) _paintNode(canvas, v);
  }

  void _paintEdges(Canvas canvas) {
    final faint = Paint()
      ..color = MeskColors.faint.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    final hot = Paint()
      ..color = MeskColors.accent.withValues(alpha: 0.95)
      ..strokeWidth = 1.5;
    final highlighted = <(String, String)>[];
    for (final (a, b) in controller.edges) {
      if (controller.isHighlighted(a, b)) {
        highlighted.add((a, b));
      } else {
        canvas.drawLine(controller.canvasOf(a), controller.canvasOf(b), faint);
      }
    }
    for (final (a, b) in highlighted) {
      canvas.drawLine(controller.canvasOf(a), controller.canvasOf(b), hot);
    }
  }

  void _paintNode(Canvas canvas, SkillView v) {
    final id = v.skill.id;
    final c = controller.canvasOf(id);
    final r = nodeDiameter(v.level) / 2;
    final opacity = controller.opacityOf(id);
    final isSelected = id == controller.selectedId;

    if (v.tier case final tier?) _paintTier(canvas, tier, c, r, opacity);
    if (isSelected) {
      // box-shadow: 0 0 0 3px bg, 0 0 0 4.5px accent, 0 0 24px accent@40%.
      canvas
        ..drawCircle(
          c,
          r,
          Paint()
            ..color = MeskColors.accent.withValues(alpha: 0.4)
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              _selectionGlowSigma,
            ),
        )
        ..drawCircle(c, r + 4.5, Paint()..color = MeskColors.accent)
        ..drawCircle(c, r + 3, Paint()..color = MeskColors.bg);
    }
    canvas.drawCircle(
      c,
      r,
      Paint()..color = statColor(v.skill.primary).withValues(alpha: opacity),
    );

    final label = labels.label(
      v.skill.name,
      selected: isSelected,
      dimmed: opacity < 1,
      textScaler: textScaler,
    );
    label.paint(
      canvas,
      Offset(c.dx - label.width / 2, c.dy + r + graphLabelGap),
    );
  }

  /// Çınar: a gold halo; Zümrüdüanka: a double ring; Efsane: a glow that
  /// slowly pulses (§5.3).
  void _paintTier(
    Canvas canvas,
    HiddenTier tier,
    Offset c,
    double r,
    double opacity,
  ) {
    Color gold(double alpha) =>
        MeskColors.accent.withValues(alpha: alpha * opacity);
    switch (tier) {
      case HiddenTier.cinar:
        canvas.drawCircle(
          c,
          r + 4,
          Paint()
            ..color = gold(0.55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
      case HiddenTier.zumruduanka:
        final ring = Paint()
          ..color = gold(0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;
        canvas
          ..drawCircle(c, r + 3.5, ring)
          ..drawCircle(c, r + 6.5, ring);
      case HiddenTier.efsane:
        // Smooth 0 → 1 → 0 over one loop.
        final t = 0.5 - 0.5 * math.cos(2 * math.pi * pulse.value);
        canvas.drawCircle(
          c,
          r + 3 + 3 * t,
          Paint()
            ..color = gold(0.25 + 0.35 * t)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 + 6 * t),
        );
    }
  }

  @override
  bool shouldRepaint(GraphPainter old) => true;

  /// One labelled button per node, so screen readers can reach them.
  @override
  SemanticsBuilderCallback get semanticsBuilder =>
      (size) => [
        for (final v in controller.nodes)
          CustomPainterSemantics(
            key: ValueKey(v.skill.id),
            rect: Rect.fromCircle(
              center: controller.canvasOf(v.skill.id),
              radius: math.max(nodeDiameter(v.level) / 2, 22),
            ),
            properties: SemanticsProperties(
              label: '${v.skill.name}, seviye ${v.level}',
              button: true,
              selected: v.skill.id == controller.selectedId,
              textDirection: TextDirection.ltr,
              onTap: () => onNodeTap(v.skill.id),
              onLongPress: () => onNodeLongPress(v.skill.id),
            ),
          ),
      ];
}
