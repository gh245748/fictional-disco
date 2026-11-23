import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mesk/app/router.dart';
import 'package:mesk/app/views.dart';
import 'package:mesk/data/db.dart';
import 'package:mesk/data/entries_repo.dart';
import 'package:mesk/data/kv_repo.dart';
import 'package:mesk/data/log_pipeline.dart';
import 'package:mesk/data/skills_repo.dart';
import 'package:mesk/domain/graph_layout.dart';
import 'package:mesk/domain/level_curve.dart';
import 'package:mesk/domain/models.dart';
import 'package:mesk/domain/stats.dart';
import 'package:mesk/domain/titles.dart';
import 'package:mesk/domain/xp.dart';
import 'package:mesk/features/graph/graph_controller.dart';
import 'package:mesk/features/graph/graph_screen.dart';
import 'package:mesk/ui/widgets/mesk_card.dart';

import '../support/app_harness.dart';
import '../support/demo_data.dart';
import '../support/golden.dart';
import '../support/mockup.dart';

SkillView _view(Skill skill, int level, {HiddenTier? tier}) => SkillView(
  skill: skill,
  totals: SkillTotals.zero,
  level: level,
  title: titleForLevel(level),
  band: bandForLevel(level),
  progress: 0,
  secondsToNext: 0,
  tier: tier,
  nextTier: null,
  tierProgress: 0,
  activeGoal: null,
  goal: null,
  lastEntryAt: null,
);

/// The mockup's 13 skills as views, plus its 14 links.
(List<SkillView>, List<SkillLink>) _mockupData() {
  final (skills, levels) = mockupSkillsAndLevels();
  var i = 0;
  return (
    [for (final s in skills) _view(s, levels[s.id]!)],
    [
      for (final (x, y) in mockupLinks)
        SkillLink.normalized(
          id: 'l${i++}',
          x: x,
          y: y,
          createdAt: DateTime.utc(2026),
        ),
    ],
  );
}

const _frame = Rect.fromLTWH(0, 0, 390, 500);

GraphController _controller({List<Map<String, (double, double)>>? saves}) =>
    GraphController(savePositions: (p) async => saves?.add(p))
      ..setFrame(_frame);

GraphController _controllerFor(GraphScreen screen, WidgetTester t) =>
    t.state<GraphScreenState>(find.byWidget(screen)).controller;

GraphController _screenController(WidgetTester t) =>
    t.state<GraphScreenState>(find.byType(GraphScreen)).controller;

/// Global position of the centre of node [id] (no zoom or pan applied).
Offset _nodeCenter(WidgetTester t, String id) =>
    t.getTopLeft(find.byKey(GraphScreen.canvasKey)) +
    _screenController(t).canvasOf(id);

/// Opens the Ağ tab and waits until the settled layout is saved, so no
/// save is left to run while the test tears the database down.
Future<void> _openGraph(WidgetTester t, MeskDb db) async {
  await pumpMeskApp(t, db, '/ag');
  await t.pump(const Duration(seconds: 1));
}

/// One skill, "Ney", and nothing else.
Future<void> _oneSkill(MeskDb db) async {
  await SkillsRepo(db).put(
    Skill(
      id: 'ney',
      name: 'Ney',
      primary: Stat.yaraticilik,
      createdAt: DateTime.utc(2026),
    ),
  );
  await KvRepo(db).saveSettings(const AppSettings(onboarded: true));
}

void main() {
  group('GraphController', () {
    test('archived skills are excluded with their links', () {
      final (views, links) = _mockupData();
      final archived = [
        for (final v in views)
          v.skill.id == 'satranc'
              ? _view(
                  v.skill.copyWith(archivedAt: DateTime.utc(2026, 5)),
                  v.level,
                )
              : v,
      ];
      final c = _controller()..setData(archived, links);
      expect(c.nodes.map((v) => v.skill.id), isNot(contains('satranc')));
      expect(c.nodes, hasLength(12));
      expect(c.edges, hasLength(13));
      expect(c.positions.keys, isNot(contains('satranc')));
    });

    test('selection highlights the node, its neighbours and their edges', () {
      final (views, links) = _mockupData();
      final c = _controller()..setData(views, links);
      c.select('yazilim');
      expect(c.selected?.skill.name, 'Yazılım');
      expect(
        [for (final v in c.neighborsOf('yazilim')) v.skill.name],
        ['İngilizce', 'Okuma', 'Satranç'],
      );
      expect(c.opacityOf('yazilim'), 1);
      expect(c.opacityOf('okuma'), 1);
      expect(c.opacityOf('fitness'), 0.3);
      expect(c.isHighlighted('okuma', 'yazilim'), isTrue);
      expect(c.isHighlighted('okuma', 'hitabet'), isFalse);
      c.select(null);
      expect(c.opacityOf('fitness'), 1);
    });

    test('filter matches the primary or the secondary stat', () {
      final (views, links) = _mockupData();
      final c = _controller()..setData(views, links);
      c.setFilter(Stat.beden);
      expect(c.opacityOf('fitness'), 1);
      expect(c.opacityOf('yoga'), 1); // Denge, secondary Beden
      expect(c.opacityOf('yazilim'), 0.3);
      c.setFilter(null);
      expect(c.opacityOf('yazilim'), 1);
    });

    test('settle saves positions once, after the debounce', () {
      fakeAsync((async) {
        final (views, links) = _mockupData();
        final saves = <Map<String, (double, double)>>[];
        final c = _controller(saves: saves)..setData(views, links);
        expect(c.running, isTrue);
        var ticks = 0;
        while (c.tick()) {
          ticks++;
          async.elapse(const Duration(milliseconds: 16));
        }
        expect(ticks, greaterThan(10)); // animated over many frames
        expect(saves, isEmpty); // never during the animation
        async.elapse(const Duration(seconds: 1));
        expect(saves, hasLength(1));
        expect(saves.single, c.positions);
        expect(saves.single.keys, hasLength(13));
      });
    });

    test('incremental ticks end where a synchronous settle ends', () {
      final (views, links) = _mockupData();
      final a = _controller()..setData(views, links);
      while (a.tick()) {}
      final b = _controller()..setData(views, links);
      b.settle();
      expect(a.positions, b.positions);
      expect(b.running, isFalse);
    });

    test('a fully saved graph opens unchanged and saves nothing', () {
      fakeAsync((async) {
        final (views, links) = _mockupData();
        final saved =
            (_controller()
                  ..setData(views, links)
                  ..settle())
                .positions;
        final placed = [
          for (final v in views)
            _view(
              v.skill.copyWith(
                graphX: saved[v.skill.id]!.$1,
                graphY: saved[v.skill.id]!.$2,
              ),
              v.level,
            ),
        ];
        final saves = <Map<String, (double, double)>>[];
        final c = _controller(saves: saves)..setData(placed, links);
        // Re-running the simulation from a cooled layout would shift it by
        // 20–35 px on every open; the saved picture is already at rest.
        expect(c.running, isFalse);
        c.settle();
        expect(c.positions, saved);
        async.elapse(const Duration(seconds: 1));
        expect(saves, isEmpty);
      });
    });

    test('a level change only pushes overlapping nodes apart', () {
      fakeAsync((async) {
        final (views, links) = _mockupData();
        final saves = <Map<String, (double, double)>>[];
        final c = _controller(saves: saves)..setData(views, links);
        c.settle();
        async.elapse(const Duration(seconds: 1));
        saves.clear();
        final before = c.positions;

        // Hitabet jumps from level 5 to 99: a much larger node.
        c.setData([
          for (final v in views)
            v.skill.id == 'hitabet' ? _view(v.skill, 99) : v,
        ], links);
        expect(c.running, isFalse);
        final after = c.positions;
        final ids = after.keys.toList();
        for (var i = 0; i < ids.length; i++) {
          for (var j = i + 1; j < ids.length; j++) {
            final a = after[ids[i]]!, b = after[ids[j]]!;
            final ra = nodeDiameter(c.viewOf(ids[i])!.level) / 2;
            final rb = nodeDiameter(c.viewOf(ids[j])!.level) / 2;
            expect(
              Offset(a.$1 - b.$1, a.$2 - b.$2).distance,
              greaterThanOrEqualTo(ra + rb + 8 - 1e-6),
            );
          }
        }
        // Nodes far from Hitabet stay where they were.
        expect(after['fitness'], before['fitness']);
        async.elapse(const Duration(seconds: 1));
        expect(saves.length, lessThanOrEqualTo(1));
      });
    });

    test('a level change mid-animation keeps the simulation going', () {
      final (views, links) = _mockupData();
      final c = _controller()..setData(views, links);
      for (var i = 0; i < 5; i++) {
        c.tick();
      }
      c.setData([
        for (final v in views) v.skill.id == 'okuma' ? _view(v.skill, 32) : v,
      ], links);
      // The layout itself keeps moving (not just the view easing in).
      final before = c.positions;
      for (var i = 0; i < 5; i++) {
        c.tick();
      }
      expect(c.positions, isNot(before));
      while (c.tick()) {}
    });

    test('a new skill is placed near its linked skill', () {
      final (views, links) = _mockupData();
      final c = _controller()..setData(views, links);
      c.settle();
      final yazilim = c.positions['yazilim']!;
      final ney = _view(
        Skill(
          id: 'ney',
          name: 'Ney',
          primary: Stat.yaraticilik,
          createdAt: DateTime.utc(2026, 6),
        ),
        1,
      );
      c.setData(
        [...views, ney],
        [
          ...links,
          SkillLink.normalized(
            id: 'new',
            x: 'ney',
            y: 'yazilim',
            createdAt: DateTime.utc(2026, 6),
          ),
        ],
      );
      final p = c.positions['ney']!;
      final d = Offset(p.$1 - yazilim.$1, p.$2 - yazilim.$2).distance;
      expect(d, lessThanOrEqualTo(120));
      expect(c.running, isTrue);
    });

    test('nodeAt uses at least a 44 px target and picks the nearest', () {
      final (views, links) = _mockupData();
      final c = _controller()..setData(views, links);
      c.settle();
      final hitabet = c.canvasOf('hitabet'); // level 5: 16,5 px node
      expect(nodeDiameter(5) / 2, lessThan(10));
      expect(c.nodeAt(hitabet + const Offset(20, 0)), 'hitabet');
      expect(c.nodeAt(hitabet + const Offset(0, 21)), 'hitabet');
      expect(c.nodeAt(hitabet + const Offset(30, 30)), isNull);
      // At half zoom the target doubles in canvas pixels.
      expect(c.nodeAt(hitabet + const Offset(30, 0), minRadius: 44), 'hitabet');
    });

    test('drag pins the node; release re-settles and saves', () {
      fakeAsync((async) {
        final (views, links) = _mockupData();
        final saves = <Map<String, (double, double)>>[];
        final c = _controller(saves: saves)..setData(views, links);
        c.settle();
        async.elapse(const Duration(seconds: 1));
        saves.clear();

        final start = c.canvasOf('okuma');
        c.dragStart('okuma', start);
        c.dragTo(start + const Offset(60, 40));
        expect(c.running, isTrue);
        for (var i = 0; i < 20; i++) {
          c.tick();
        }
        // Pinned under the finger while held.
        final held = c.canvasOf('okuma');
        expect(held.dx, closeTo(start.dx + 60, 1e-6));
        expect(held.dy, closeTo(start.dy + 40, 1e-6));
        async.elapse(const Duration(seconds: 1));
        expect(saves, isEmpty);

        c.dragEnd();
        expect(c.draggingId, isNull);
        while (c.tick()) {}
        async.elapse(const Duration(seconds: 1));
        expect(saves, hasLength(1));
        expect(saves.single, contains('okuma'));
      });
    });

    test('dispose writes a pending save', () {
      fakeAsync((async) {
        final (views, links) = _mockupData();
        final saves = <Map<String, (double, double)>>[];
        final c = _controller(saves: saves)..setData(views, links);
        c.settle();
        c.dispose();
        expect(saves, hasLength(1));
        async.elapse(const Duration(seconds: 1));
        expect(saves, hasLength(1));
      });
    });

    test('the view fits the graph into the frame', () {
      final (views, links) = _mockupData();
      final c = _controller()..setData(views, links);
      c.settle();
      for (final v in c.nodes) {
        final p = c.canvasOf(v.skill.id);
        expect(_frame.contains(p), isTrue, reason: v.skill.id);
      }
    });

    test('bonus minutes per hour', () {
      expect(bonusMinutesLabel(1000), '6 dk');
      expect(bonusMinutesLabel(1100), '6,6 dk');
      expect(bonusMinutesLabel(2500), '15 dk');
      expect(bonusMinutesLabel(0), '0 dk');
    });
  });

  group('GraphScreen', () {
    testWidgets('tap selects and shows card', (t) async {
      final db = await openTestDb(t);
      await _openGraph(t, db);
      expect(find.text('Yetenek Ağı'), findsOneWidget);
      expect(
        find.text('13 yetenek · 14 bağlantı · bağ bonusu %10'),
        findsOneWidget,
      );
      expect(find.textContaining('Bağlı:'), findsNothing);

      await t.tapAt(_nodeCenter(t, 'yazilim'));
      await t.pumpAndSettle();
      expect(_screenController(t).selectedId, 'yazilim');
      expect(find.text('Yazılım'), findsOneWidget);
      expect(find.text('Sv. 47'), findsOneWidget);
      expect(
        find.text(
          'Rehber · Zihin · 161 sa · sıradaki seviyeye 4,7 sa',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(find.text('Bağlı: İngilizce · Okuma · Satranç'), findsOneWidget);
      expect(
        find.text(
          'Burada geçen her saat, bağlı yeteneklerin her birine +6 dk '
          'kazandırır.',
        ),
        findsOneWidget,
      );

      // Tapping the card opens the skill.
      await t.tap(find.text('Bağlı: İngilizce · Okuma · Satranç'));
      await t.pumpAndSettle();
      expect(currentLocation(t), '/yetenekler/yazilim');
    });

    testWidgets('tap on empty space clears the selection', (t) async {
      final db = await openTestDb(t);
      await _openGraph(t, db);
      await t.tapAt(_nodeCenter(t, 'yazilim'));
      await t.pumpAndSettle();
      expect(find.textContaining('Bağlı:'), findsOneWidget);
      final canvas = t.getRect(find.byKey(GraphScreen.canvasKey));
      await t.tapAt(canvas.topLeft + const Offset(4, 4));
      await t.pumpAndSettle();
      expect(_screenController(t).selectedId, isNull);
      expect(find.textContaining('Bağlı:'), findsNothing);
    });

    testWidgets('filter dims non-matching', (t) async {
      final db = await openTestDb(t);
      await _openGraph(t, db);
      for (final label in ['Tümü', ...skillStats.map((s) => s.label)]) {
        expect(find.widgetWithText(ChoiceChip, label), findsOneWidget);
      }
      await t.tap(find.widgetWithText(ChoiceChip, 'Beden'));
      await t.pumpAndSettle();
      final c = _screenController(t);
      expect(c.filter, Stat.beden);
      expect(c.opacityOf('fitness'), 1);
      expect(c.opacityOf('kosu'), 1);
      expect(c.opacityOf('yazilim'), 0.3);
      expect(c.opacityOf('gitar'), 0.3);

      await t.tap(find.widgetWithText(ChoiceChip, 'Tümü'));
      await t.pumpAndSettle();
      expect(c.filter, isNull);
      expect(c.opacityOf('yazilim'), 1);
    });

    testWidgets('positions saved after settle', (t) async {
      final db = await openTestDb(t);
      final before = (await t.runAsync(() => SkillsRepo(db).all()))!;
      expect(before.every((s) => s.graphX == null), isTrue);

      await _openGraph(t, db);
      final c = _screenController(t);
      expect(c.running, isFalse);
      final saved = (await t.runAsync(() => SkillsRepo(db).all()))!;
      expect(saved, hasLength(13));
      for (final s in saved) {
        expect(s.graphX, c.positions[s.id]!.$1, reason: s.id);
        expect(s.graphY, c.positions[s.id]!.$2, reason: s.id);
        expect(s.name, isNotEmpty); // the rest of the skill is kept
      }
    });

    testWidgets('dragging a node moves it and saves on release', (t) async {
      final db = await openTestDb(t);
      await _openGraph(t, db);
      final c = _screenController(t);
      final before = c.positions['okuma']!;

      await t.dragFrom(_nodeCenter(t, 'okuma'), const Offset(40, 60));
      await t.pumpAndSettle();
      await t.pump(const Duration(seconds: 1));
      final after = c.positions['okuma']!;
      expect(
        Offset(after.$1 - before.$1, after.$2 - before.$2).distance,
        greaterThan(10),
      );
      final okuma = (await t.runAsync(() => SkillsRepo(db).get('okuma')))!;
      expect(okuma.graphX, after.$1);
      expect(okuma.graphY, after.$2);
    });

    testWidgets('long press offers Başlat and Aç', (t) async {
      final db = await openTestDb(t);
      await _openGraph(t, db);
      await t.longPressAt(_nodeCenter(t, 'gitar'));
      await t.pumpAndSettle();
      expect(find.text('Başlat'), findsOneWidget);
      expect(find.text('Aç'), findsOneWidget);
      await t.tap(find.text('Aç'));
      await t.pumpAndSettle();
      expect(currentLocation(t), '/yetenekler/gitar');

      t.container().read(routerProvider).go('/ag');
      await t.pumpAndSettle();
      await t.longPressAt(_nodeCenter(t, 'gitar'));
      await t.pumpAndSettle();
      await t.tap(find.text('Başlat'));
      await t.pumpAndSettle();
      expect(currentLocation(t), '/odak?skill=gitar');
    });

    testWidgets('bonus copy follows the bonus rate', (t) async {
      final db = await openTestDb(
        t,
        seed: (db) async {
          await seedDemo(db);
          final kv = KvRepo(db);
          await kv.saveSettings(
            (await kv.settings()).copyWith(bonusRateBp: 1500),
          );
        },
      );
      await _openGraph(t, db);
      expect(find.textContaining('bağ bonusu %15'), findsOneWidget);
      await t.tapAt(_nodeCenter(t, 'okuma'));
      await t.pumpAndSettle();
      expect(find.textContaining('+9 dk kazandırır.'), findsOneWidget);
    });

    testWidgets('header, chips and card fit at text scale 1.3', (t) async {
      t.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      final db = await openTestDb(t);
      await _openGraph(t, db);
      await t.tapAt(_nodeCenter(t, 'gunluk-yazma'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      final card = t.getRect(
        find.ancestor(
          of: find.textContaining('Bağlı:'),
          matching: find.byType(MeskCard),
        ),
      );
      final canvas = t.getRect(find.byKey(GraphScreen.canvasKey));
      expect(card.bottom, lessThanOrEqualTo(canvas.bottom));
      expect(card.top, greaterThan(canvas.top));
    });

    testWidgets('empty state', (t) async {
      final db = await openTestDb(t, seed: _oneSkill);
      await _openGraph(t, db);
      expect(
        find.text('Ağ, en az iki yetenek ve bir bağlantıyla anlam kazanır.'),
        findsOneWidget,
      );
      expect(find.byKey(GraphScreen.canvasKey), findsNothing);
      await t.tap(find.text('Yetenek ekle'));
      await t.pumpAndSettle();
      expect(currentLocation(t), '/yetenekler/yeni');
    });

    testWidgets('Efsane pulses; other graphs come to rest', (t) async {
      Future<void> withLegend(MeskDb db) async {
        await seedDemo(db);
        await EntriesRepo(db).put(
          TimeEntry(
            id: 'legend',
            skillId: 'yazilim',
            startedAt: DateTime.utc(2020),
            endedAt: DateTime.utc(2020).add(const Duration(hours: 10000)),
            offsetMinutes: 180,
            seconds: 10000 * 3600,
            source: EntrySource.prior,
            pomodoros: 0,
          ),
        );
        await LogPipeline(db, demoClock()).recomputeAll();
      }

      final db = await openTestDb(t, seed: withLegend);
      await pumpMeskApp(t, db, '/bugun');
      t.container().read(routerProvider).go('/ag');
      for (var i = 0; i < 300; i++) {
        await t.pump(const Duration(milliseconds: 16));
      }
      final state = t.state<GraphScreenState>(find.byType(GraphScreen));
      expect(state.controller.running, isFalse);
      expect(state.pulseRunning, isTrue);

      // Another tab: the pulse is muted, so nothing keeps scheduling frames.
      t.container().read(routerProvider).go('/bugun');
      await t.pumpAndSettle();
    });

    testWidgets('graph', (t) async {
      final db = await openTestDb(t);
      const screen = GraphScreen();
      await pumpPhone(t, screen, overrides: appOverrides(db, demoClock()));
      final c = _controllerFor(screen, t);
      expect(c.running, isFalse);
      await t.tapAt(
        t.getTopLeft(find.byKey(GraphScreen.canvasKey)) + c.canvasOf('yazilim'),
      );
      await t.pumpAndSettle();
      expect(c.selectedId, 'yazilim');
      await expectGolden(t, 'graph');
      await t.pump(const Duration(seconds: 1));
    }, tags: 'golden');
  });
}
