import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mesk/app/providers.dart';
import 'package:mesk/data/db.dart';
import 'package:mesk/data/goals_repo.dart';
import 'package:mesk/data/habits_repo.dart';
import 'package:mesk/data/log_pipeline.dart';
import 'package:mesk/data/skills_repo.dart';
import 'package:mesk/domain/stats.dart';
import 'package:mesk/domain/day.dart';
import 'package:mesk/domain/models.dart';
import 'package:mesk/features/celebrations/celebration_host.dart';
import 'package:mesk/features/goals/goal_card.dart';
import 'package:mesk/features/goals/goal_edit_screen.dart';
import 'package:mesk/features/goals/goals_controller.dart';
import 'package:mesk/features/habits/habits_controller.dart';
import 'package:mesk/services/notifications.dart';

import '../support/app_harness.dart';
import '../support/demo_data.dart';
import '../support/golden.dart';

GoalsController _controller(MeskDb db) {
  final clock = demoClock();
  final pipeline = LogPipeline(db, clock);
  return GoalsController(
    db,
    clock,
    pipeline,
    HabitsController(
      db,
      clock,
      pipeline,
      FakeNotificationService(permissionGranted: true),
    ),
  );
}

Goal _goal(
  String id,
  String skillId,
  int hours, {
  LocalDay? deadline,
  DateTime? createdAt,
}) => Goal(
  id: id,
  skillId: skillId,
  targetSeconds: hours * 3600,
  deadline: deadline,
  createdAt: createdAt ?? DateTime.utc(2026, 11, 20),
);

/// The goal card of [skillId] above a celebration host.
class _CardHost extends ConsumerWidget {
  const _CardHost(this.skillId);

  final String skillId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(skillViewProvider(skillId)).value;
    return CelebrationHost(
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [if (view != null) GoalCard(view)],
          ),
        ),
      ),
    );
  }
}

Future<void> _pumpCard(WidgetTester t, MeskDb db, String skillId) =>
    pumpPhone(t, _CardHost(skillId), overrides: appOverrides(db, demoClock()));

void main() {
  group('GoalsController', () {
    late MeskDb db;
    late GoalsController controller;

    setUp(() async {
      db = await MeskDb.openMemory();
      await seedDemo(db);
      controller = _controller(db);
    });
    tearDown(() => db.close());

    test('toHabit creates 34-minute daily timed habit', () async {
      final id = await controller.toHabit('g-ingilizce');

      final habit = (await HabitsRepo(db).get(id))!;
      expect(habit.name, 'İngilizce · 34 dk');
      expect(habit.kind, HabitKind.timed);
      expect(habit.skillId, 'ingilizce');
      expect(habit.targetMinutes, 34);
      expect(habit.schedule, const DailySchedule());
    });

    test('toHabit without a deadline throws', () async {
      await controller.save(_goal('g-open', 'okuma', 100));
      expect(() => controller.toHabit('g-open'), throwsStateError);
    });

    test('new goal closes previous', () async {
      await controller.save(
        _goal('g-new', 'ingilizce', 150, deadline: const LocalDay(2027, 6, 1)),
      );

      final repo = GoalsRepo(db);
      final old = (await repo.get('g-ingilizce'))!;
      expect(old.closedAt, isNotNull);
      expect(old.active, isFalse);
      expect((await repo.get('g-new'))!.active, isTrue);
      final active = [
        for (final g in await repo.all())
          if (g.skillId == 'ingilizce' && g.active) g.id,
      ];
      expect(active, ['g-new']);
    });

    test('editing the active goal keeps it active', () async {
      final g = (await GoalsRepo(db).get('g-ingilizce'))!;
      await controller.save(g.copyWith(targetSeconds: 200 * 3600));
      final back = (await GoalsRepo(db).get('g-ingilizce'))!;
      expect(back.active, isTrue);
      expect(back.targetSeconds, 200 * 3600);
    });

    test('saving a goal that is already met completes it', () async {
      final result = await controller.save(_goal('g-met', 'okuma', 10));
      final g = (await GoalsRepo(db).get('g-met'))!;
      expect(g.completedAt, isNotNull);
      expect(result.celebrations.map((c) => c.goalId), contains('g-met'));
    });

    test('close and extend', () async {
      await controller.extend('g-ingilizce', const LocalDay(2027, 5, 1));
      expect(
        (await GoalsRepo(db).get('g-ingilizce'))!.deadline,
        const LocalDay(2027, 5, 1),
      );
      await controller.close('g-ingilizce');
      expect((await GoalsRepo(db).get('g-ingilizce'))!.closedAt, isNotNull);
    });
  });

  group('GoalCard', () {
    testWidgets('mockup goal card text', (t) async {
      final db = await openTestDb(t);
      await _pumpCard(t, db, 'ingilizce');

      expect(find.text('Hedef 100 sa · %27'), findsOneWidget);
      expect(find.text('31 Mart için günde 34 dk'), findsOneWidget);
      expect(find.textContaining('Bu hızla '), findsOneWidget);
      expect(find.text('Günlük alışkanlığa çevir'), findsOneWidget);
      expect(find.text('Süre doldu'), findsNothing);
    });

    testWidgets('no deadline and no pace', (t) async {
      final db = await openTestDb(
        t,
        seed: (db) async {
          await seedDemo(db);
          await SkillsRepo(db).put(
            Skill(
              id: 'bos',
              name: 'Boş',
              primary: Stat.zihin,
              createdAt: DateTime.utc(2026, 11),
            ),
          );
          await GoalsRepo(db).put(_goal('g-bos', 'bos', 10));
        },
      );
      await _pumpCard(t, db, 'bos');
      expect(find.text('Hedef 10 sa · %0'), findsOneWidget);
      expect(find.text('Bu hızla tahmin yok'), findsOneWidget);
      expect(find.textContaining('için günde'), findsNothing);
      expect(find.text('Günlük alışkanlığa çevir'), findsNothing);
    });

    testWidgets('expired actions', (t) async {
      final db = await openTestDb(
        t,
        seed: (db) async {
          await seedDemo(db);
          await GoalsRepo(db).put(
            _goal(
              'g-ingilizce',
              'ingilizce',
              100,
              deadline: const LocalDay(2026, 11, 10),
              createdAt: DateTime.utc(2026, 11, 1),
            ),
          );
        },
      );
      await _pumpCard(t, db, 'ingilizce');

      expect(find.text('Süre doldu'), findsOneWidget);
      expect(find.textContaining('için günde'), findsNothing);
      expect(find.text('Günlük alışkanlığa çevir'), findsNothing);

      await t.tap(find.text('Tarihi uzat'));
      await t.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await t.tap(find.text('Tamam'));
      await t.pumpAndSettle();
      final extended = (await t.runAsync(
        () => GoalsRepo(db).get('g-ingilizce'),
      ))!;
      expect(extended.deadline, const LocalDay(2026, 11, 28));
      expect(find.text('Süre doldu'), findsNothing);

      // Back to expired, then close.
      await t.runAsync(
        () =>
            GoalsRepo(db)
                .put(extended.copyWith(deadline: const LocalDay(2026, 11, 10))),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Hedefi kapat'));
      await t.pumpAndSettle();
      final closed = (await t.runAsync(
        () => GoalsRepo(db).get('g-ingilizce'),
      ))!;
      expect(closed.closedAt, isNotNull);
      expect(find.textContaining('Hedef '), findsNothing);
    });

    testWidgets('convert button creates the habit', (t) async {
      final db = await openTestDb(t);
      await _pumpCard(t, db, 'ingilizce');

      await t.tap(find.text('Günlük alışkanlığa çevir'));
      await t.pumpAndSettle();

      final habits = (await t.runAsync(() => HabitsRepo(db).all()))!;
      expect(habits.where((h) => h.name == 'İngilizce · 34 dk'), hasLength(1));
      expect(find.text('Alışkanlık eklendi.'), findsOneWidget);
    });
  });

  group('GoalEditScreen', () {
    testWidgets('saves target hours and a deadline', (t) async {
      final db = await openTestDb(t);
      await pumpPhone(
        t,
        const GoalEditScreen(skillId: 'okuma'),
        overrides: appOverrides(db, demoClock()),
      );

      // Save needs a target.
      expect(
        t
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Kaydet'))
            .onPressed,
        isNull,
      );
      await t.enterText(find.byKey(const ValueKey('goal-hours')), '120');
      await t.pump();
      await t.tap(find.byKey(const ValueKey('goal-deadline')));
      await t.pumpAndSettle();
      // The picker opens on today; earlier days are disabled.
      await t.tap(find.text('Tamam'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Kaydet'));
      await t.pumpAndSettle();

      final goals = (await t.runAsync(() => GoalsRepo(db).all()))!;
      final g = goals.firstWhere((g) => g.skillId == 'okuma' && g.active);
      expect(g.targetSeconds, 120 * 3600);
      expect(g.deadline, const LocalDay(2026, 11, 21));
    });

    testWidgets('editing prefills the active goal and keeps its id', (t) async {
      final db = await openTestDb(t);
      await pumpPhone(
        t,
        const GoalEditScreen(skillId: 'ingilizce'),
        overrides: appOverrides(db, demoClock()),
      );
      expect(find.text('100'), findsOneWidget);
      await t.enterText(find.byKey(const ValueKey('goal-hours')), '150');
      await t.pump();
      await t.tap(find.widgetWithText(FilledButton, 'Kaydet'));
      await t.pumpAndSettle();

      final goals = (await t.runAsync(() => GoalsRepo(db).all()))!;
      final mine = goals.where((g) => g.skillId == 'ingilizce').toList();
      expect(mine, hasLength(1));
      expect(mine.single.targetSeconds, 150 * 3600);
      expect(mine.single.deadline, const LocalDay(2027, 3, 31));
    });
  });

  group('skill detail', () {
    testWidgets('completed goals listed on skill detail', (t) async {
      final db = await openTestDb(
        t,
        seed: (db) async {
          await seedDemo(db);
          await GoalsRepo(db).put(
            _goal(
              'g-done',
              'ingilizce',
              20,
            ).copyWith(completedAt: DateTime.utc(2026, 10, 5, 12)),
          );
        },
      );
      await pumpMeskApp(t, db, '/yetenekler/ingilizce');

      await t.scrollUntilVisible(
        find.text('Tamamlanan hedefler'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Tamamlanan hedefler'), findsOneWidget);
      expect(find.text('20 sa · 5 Ekim 2026'), findsOneWidget);
      // The active goal is not in that list.
      expect(find.text('100 sa · '), findsNothing);
    });

    testWidgets('without an active goal the detail offers Hedef koy', (
      t,
    ) async {
      final db = await openTestDb(t);
      await pumpMeskApp(t, db, '/yetenekler/okuma');
      await tapVisible(t, find.text('Hedef koy'));
      expect(currentLocation(t), '/hedef/okuma');
      expect(find.text('Hedef koy'), findsWidgets);
      expect(find.byKey(const ValueKey('goal-hours')), findsOneWidget);
    });
  });

  group('goldens', () {
    testWidgets('goal card', (t) async {
      final db = await openTestDb(t);
      await _pumpCard(t, db, 'ingilizce');
      await expectGolden(t, 'goal_card');
    }, tags: 'golden');

    testWidgets('goal edit', (t) async {
      final db = await openTestDb(t);
      await pumpPhone(
        t,
        const GoalEditScreen(skillId: 'ingilizce'),
        overrides: appOverrides(db, demoClock()),
      );
      await expectGolden(t, 'goal_edit');
    }, tags: 'golden');
  });
}
