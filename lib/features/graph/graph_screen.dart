import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../app/views.dart';
import '../../data/db.dart';
import '../../data/skills_repo.dart';
import '../../domain/format.dart';
import '../../domain/level_curve.dart';
import '../../domain/stats.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/buttons.dart';
import '../../ui/widgets/mesk_card.dart';
import '../../ui/widgets/stat_dot.dart';
import 'graph_controller.dart';
import 'graph_painter.dart';

/// "4,7 sa", or "18 dk" under an hour (as in the mockup's info card).
String _remaining(int seconds) =>
    seconds < 3600 ? formatDuration(seconds) : formatHours(seconds);

/// The Ağ tab (§5.11): every active skill as a node, links as edges, with
/// pan and pinch-zoom, stat filter chips, a tap-to-select info card, node
/// dragging and long-press quick actions.
class GraphScreen extends ConsumerStatefulWidget {
  const GraphScreen({super.key});

  /// The canvas inside the [InteractiveViewer] (canvas coordinates).
  static const canvasKey = ValueKey('graph-canvas');

  @override
  ConsumerState<GraphScreen> createState() => GraphScreenState();
}

class GraphScreenState extends ConsumerState<GraphScreen>
    with TickerProviderStateMixin {
  /// Space at the bottom of the canvas kept for the info card.
  static const double _cardReserve = 136;

  late final MeskDb _db;
  late final GraphController _controller;
  late final Ticker _ticker;

  /// The Efsane glow; runs only while such a skill is shown in the graph
  /// (and, through [TickerMode], only while this tab is on screen).
  late final AnimationController _pulse;
  final _transform = TransformationController();
  final _labels = GraphLabels();

  @visibleForTesting
  GraphController get controller => _controller;

  @visibleForTesting
  bool get pulseRunning => _pulse.isAnimating;

  @override
  void initState() {
    super.initState();
    // Read now: the last save may run while the screen is disposed.
    _db = ref.read(dbProvider);
    _controller = GraphController(savePositions: _savePositions);
    // Created here, not lazily: dispose must never create a ticker.
    _ticker = createTicker(_onTick);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  void _onTick(Duration _) {
    if (!_controller.tick()) {
      _ticker.stop();
      // Refresh the node semantics at their resting places.
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _pulse.dispose();
    _controller.dispose(); // writes a pending save
    _transform.dispose();
    _labels.dispose();
    super.dispose();
  }

  Future<void> _savePositions(Map<String, (double, double)> positions) async {
    final repo = SkillsRepo(_db);
    await _db.database.transaction((txn) async {
      for (final MapEntry(key: id, value: (x, y)) in positions.entries) {
        final skill = await repo.get(id, txn: txn);
        if (skill == null) continue;
        await repo.put(
          skill.copyWith(graphX: x, graphY: y),
          txn: txn,
        );
      }
    });
  }

  void _ensureTicking() {
    if (_controller.running && !_ticker.isActive) _ticker.start();
  }

  void _syncPulse({required bool hasGraph}) {
    final legend =
        hasGraph && _controller.nodes.any((v) => v.tier == HiddenTier.efsane);
    if (legend && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!legend && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  // -------------------------------------------------------------------------
  // Gestures (positions are canvas coordinates)

  double get _zoom => _transform.value.getMaxScaleOnAxis();

  /// The node under [p], with a touch target of at least 44 screen pixels.
  String? _hit(Offset p) => _controller.nodeAt(p, minRadius: 22 / _zoom);

  void _select(String? id) => setState(() => _controller.select(id));

  void _setFilter(Stat? stat) => setState(() => _controller.setFilter(stat));

  void _onDragStart(DragStartDetails d) {
    final id = _hit(d.localPosition);
    if (id != null) _controller.dragStart(id, d.localPosition);
  }

  void _onDragUpdate(DragUpdateDetails d) {
    _controller.dragTo(d.localPosition);
    _ensureTicking();
  }

  void _onDragEnd() {
    _controller.dragEnd();
    _ensureTicking();
  }

  Future<void> _openActions(String id) async {
    final view = _controller.viewOf(id);
    if (view == null) return;
    _select(id);
    final choice = await showModalBottomSheet<_Action>(
      context: context,
      useSafeArea: true,
      backgroundColor: MeskColors.surface,
      builder: (sheet) => _ActionsSheet(view),
    );
    if (!mounted) return;
    switch (choice) {
      case _Action.start:
        context.go('/odak?skill=$id');
      case _Action.open:
        context.push('/yetenekler/$id');
      case null:
        break;
    }
  }

  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final views = ref.watch(skillViewsProvider).value;
    final links = ref.watch(linksProvider).value;
    final settings = ref.watch(settingsProvider).value;
    if (views == null || links == null || settings == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    _controller.setData(views, links);
    final nodes = _controller.nodes;
    final hasGraph = nodes.length >= 2;
    if (hasGraph) _ensureTicking();
    _syncPulse(hasGraph: hasGraph);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              skills: nodes.length,
              links: _controller.edges.length,
              rate: settings.bonusRateBp / 10000,
            ),
            if (hasGraph) ...[
              _FilterChips(selected: _controller.filter, onSelect: _setFilter),
              Expanded(child: _canvas(settings.bonusRateBp)),
            ] else
              const _EmptyState(),
          ],
        ),
      ),
    );
  }

  Widget _canvas(int bonusRateBp) => LayoutBuilder(
    builder: (context, box) {
      final size = box.biggest;
      final textScaler = MediaQuery.textScalerOf(context);
      _controller.setFrame(
        Rect.fromLTRB(16, 12, size.width - 16, size.height - _cardReserve),
        labelHalfWidths: _labels.halfWidths(_controller.nodes, textScaler),
      );
      final selected = _controller.selected;
      return Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              transformationController: _transform,
              minScale: 0.5,
              maxScale: 3,
              boundaryMargin: const EdgeInsets.all(double.infinity),
              child: SizedBox(
                key: GraphScreen.canvasKey,
                width: size.width,
                height: size.height,
                child: RawGestureDetector(
                  behavior: HitTestBehavior.opaque,
                  // Order matters: an unmoved press resolves to the first
                  // (the tap) when the arena is swept.
                  gestures: {
                    TapGestureRecognizer:
                        GestureRecognizerFactoryWithHandlers<
                          TapGestureRecognizer
                        >(
                          () => TapGestureRecognizer(debugOwner: this),
                          (r) =>
                              r.onTapUp = (d) => _select(_hit(d.localPosition)),
                        ),
                    _NodeLongPressRecognizer:
                        GestureRecognizerFactoryWithHandlers<
                          _NodeLongPressRecognizer
                        >(
                          () => _NodeLongPressRecognizer(
                            hit: (p) => _hit(p) != null,
                            debugOwner: this,
                          ),
                          (r) => r.onLongPressStart = (d) {
                            final id = _hit(d.localPosition);
                            if (id != null) _openActions(id);
                          },
                        ),
                    _NodeDragRecognizer:
                        GestureRecognizerFactoryWithHandlers<
                          _NodeDragRecognizer
                        >(
                          () => _NodeDragRecognizer(
                            hit: (p) => _hit(p) != null,
                            debugOwner: this,
                          ),
                          (r) => r
                            ..dragStartBehavior = DragStartBehavior.down
                            ..onStart = _onDragStart
                            ..onUpdate = _onDragUpdate
                            ..onEnd = ((_) => _onDragEnd())
                            ..onCancel = _onDragEnd,
                        ),
                  },
                  // The graph repaints every frame while it moves or pulses;
                  // keep that off the rest of the screen.
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: GraphPainter(
                        controller: _controller,
                        pulse: _pulse,
                        labels: _labels,
                        textScaler: textScaler,
                        onNodeTap: _select,
                        onNodeLongPress: _openActions,
                      ),
                      size: size,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (selected != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 12,
              child: _InfoCard(
                view: selected,
                neighbors: _controller.neighborsOf(selected.skill.id),
                bonusRateBp: bonusRateBp,
                onTap: () => context.push('/yetenekler/${selected.skill.id}'),
              ),
            ),
        ],
      );
    },
  );
}

/// A pan that only starts on a node, and wins over the viewer's pan by
/// accepting after the (smaller) touch slop.
class _NodeDragRecognizer extends PanGestureRecognizer {
  _NodeDragRecognizer({required this.hit, super.debugOwner});

  final bool Function(Offset localPosition) hit;

  @override
  bool isPointerAllowed(PointerEvent event) =>
      hit(event.localPosition) && super.isPointerAllowed(event);

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) =>
      globalDistanceMoved.abs() >
      computeHitSlop(pointerDeviceKind, gestureSettings);
}

/// A long press that only starts on a node; elsewhere the press is left to
/// the viewer.
class _NodeLongPressRecognizer extends LongPressGestureRecognizer {
  _NodeLongPressRecognizer({required this.hit, super.debugOwner});

  final bool Function(Offset localPosition) hit;

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      hit(event.localPosition) && super.isPointerAllowed(event);
}

class _Header extends StatelessWidget {
  const _Header({
    required this.skills,
    required this.links,
    required this.rate,
  });

  final int skills;
  final int links;
  final double rate;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        const Text('Yetenek Ağı', style: MeskType.screenTitle),
        Text(
          '$skills yetenek · $links bağlantı · '
          'bağ bonusu ${formatPercent(rate)}',
          style: MeskType.caption,
        ),
      ],
    ),
  );
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelect});

  final Stat? selected;
  final ValueChanged<Stat?> onSelect;

  Widget _chip(String label, Stat? stat) {
    final on = selected == stat;
    return ChoiceChip(
      avatar: stat == null ? null : StatDot(stat, size: 7),
      label: Text(label),
      selected: on,
      side: on ? meskSelectedChipSide : null,
      onSelected: (_) => onSelect(stat),
    );
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(
      spacing: 6,
      children: [
        _chip('Tümü', null),
        for (final s in skillStats) _chip(s.label, s),
      ],
    ),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.view,
    required this.neighbors,
    required this.bonusRateBp,
    required this.onTap,
  });

  final SkillView view;
  final List<SkillView> neighbors;
  final int bonusRateBp;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final skill = view.skill;
    final next = view.level < maxLevel
        ? ' · sıradaki seviyeye ${_remaining(view.secondsToNext)}'
        : '';
    return MeskCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 5,
        children: [
          Row(
            spacing: 8,
            children: [
              StatDot(skill.primary, size: 10),
              Expanded(
                child: Text(
                  skill.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MeskType.body15,
                ),
              ),
              Text('Sv. ${view.level}', style: MeskType.levelNumber),
            ],
          ),
          Text.rich(
            TextSpan(
              style: MeskType.caption,
              children: [
                TextSpan(
                  text: view.title,
                  style: MeskType.titleItalic.copyWith(
                    fontSize: 14,
                    color: MeskColors.muted,
                  ),
                ),
                TextSpan(
                  text:
                      ' · ${skill.primary.label} · '
                      '${formatHours(view.totals.xpSeconds)}$next',
                ),
              ],
            ),
          ),
          Text(
            neighbors.isEmpty
                ? 'Henüz bağlantısı yok.'
                : 'Bağlı: ${neighbors.map((n) => n.skill.name).join(' · ')}',
            style: MeskType.body14.copyWith(fontWeight: FontWeight.w400),
          ),
          if (neighbors.isNotEmpty && bonusRateBp > 0)
            Text(
              'Burada geçen her saat, bağlı yeteneklerin her birine '
              '+${bonusMinutesLabel(bonusRateBp)} kazandırır.',
              style: MeskType.caption.copyWith(color: MeskColors.faint),
            ),
        ],
      ),
    );
  }
}

enum _Action { start, open }

class _ActionsSheet extends StatelessWidget {
  const _ActionsSheet(this.view);

  final SkillView view;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        Row(
          spacing: 10,
          children: [
            StatDot(view.skill.primary, size: 10),
            Expanded(
              child: Text(view.skill.name, style: MeskType.sectionTitle),
            ),
            Text('Sv. ${view.level}', style: MeskType.levelNumber),
          ],
        ),
        Row(
          spacing: 12,
          children: [
            Expanded(
              child: MeskPrimaryButton(
                label: 'Başlat',
                icon: Icons.play_arrow_rounded,
                onPressed: () => Navigator.pop(context, _Action.start),
              ),
            ),
            Expanded(
              child: MeskSecondaryButton(
                label: 'Aç',
                onPressed: () => Navigator.pop(context, _Action.open),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
    child: MeskCard(
      child: Column(
        spacing: 12,
        children: [
          const Text(
            'Ağ, en az iki yetenek ve bir bağlantıyla anlam kazanır.',
            textAlign: TextAlign.center,
            style: MeskType.caption,
          ),
          MeskPrimaryButton(
            label: 'Yetenek ekle',
            icon: Icons.add,
            onPressed: () => context.push('/yetenekler/yeni'),
          ),
        ],
      ),
    ),
  );
}
