import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mesk/app/app.dart';
import 'package:mesk/app/providers.dart';
import 'package:mesk/data/db.dart';
import 'package:mesk/data/habits_repo.dart';
import 'package:mesk/data/log_pipeline.dart';
import 'package:mesk/domain/day.dart';
import 'package:mesk/domain/habits.dart';
import 'package:mesk/domain/models.dart';
import 'package:mesk/features/celebrations/celebration_host.dart';
import 'package:mesk/features/habits/habit_calendar.dart';
import 'package:mesk/features/habits/habit_edit_screen.dart';
import 'package:mesk/features/habits/habit_row.dart';
import 'package:mesk/features/habits/habits_controller.dart';
import 'package:mesk/features/skills/skills_controller.dart';
import 'package:mesk/services/notifications.dart';

import '../support/app_harness.dart';
import '../support/demo_data.dart';
import '../support/golden.dart';

/// Remembers what the controller scheduled.
class _Recorder extends FakeNotificationService {
  List<Habit> habits = const [];
  LocalDay? today;

  @override
  Future<void> scheduleHabitReminders(
    List<Habit> habits,
    LocalDay today,
    HabitDayData data,
  ) async {
    this.habits = habits;
    this.today = today;
    await super.scheduleHabitReminders(habits, today, data);
  }
}

int _reminderCalls(_Recorder r) =>
    r.calls.where((c) => c == 'scheduleHabitReminders').length;

/// Today's habits as [HabitRow]s, above a celebration host.
class _HabitList extends ConsumerWidget {
  const _HabitList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(todayHabitsProvider).value ?? const [];
    return CelebrationHost(
      child: Scaffold(
        body: SafeArea(
          child: ListView(children: [for (final h in habits) HabitRow(h)]),
        ),
      ),
    );
  }
}

Future<void> _pumpList(WidgetTester t, MeskDb db, _Recorder rec) => pumpPhone(
  t,
  const _HabitList(),
  overrides: appOverrides(db, demoClock(), notifications: rec),
);

Habit _simple(
  String id,
  String name, {
  HabitSchedule schedule = const DailySchedule(),
  DateTime? createdAt,
  int? reminder,
}) => Habit(
  id: id,
  name: name,
  kind: HabitKind.simple,
  schedule: schedule,
  reminderMinuteOfDay: reminder,
  createdAt: createdAt ?? DateTime.utc(2026, 11, 1),
);

/// The Kaydet button, scrolled into view.
Future<Finder> _saveButton(WidgetTester t) async {
  final save = find.widgetWithText(FilledButton, 'Kaydet');
  await t.scrollUntilVisible(
    save,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  return save;
}

Future<List<HabitCheck>> _checks(WidgetTester t, MeskDb db) =>
    t.runAsync(() => HabitsRepo(db).allChecks()).then((v) => v!);

Future<List<Habit>> _allHabits(WidgetTester t, MeskDb db) =>
    t.runAsync(() => HabitsRepo(db).all()).then((v) => v!);

void main() {
  group('HabitsController', () {
    late MeskDb db;
    late _Recorder rec;
    late HabitsController controller;

    setUp(() async {
      db = await MeskDb.openMemory();
      await seedDemo(db);
      rec = _Recorder();
      controller = HabitsController(
        db,
        demoClock(),
        LogPipeline(db, demoClock()),
        rec,
      );
    });
    tearDown(() => db.close());

    test('save stores the habit and reschedules active reminders', () async {
      final h = _simple('h-new', 'Su iç', reminder: 8 * 60);
      await controller.save(h);

      expect(await HabitsRepo(db).get('h-new'), h);
      expect(rec.calls, contains('scheduleHabitReminders'));
      expect(rec.habits.map((x) => x.id), contains('h-new'));
      expect(rec.today, const LocalDay(2026, 11, 21));
    });

    test('toggle flips a simple habit check and reschedules', () async {
      const day = LocalDay(2026, 11, 20);
      await controller.toggle('h-sekersiz', day);
      expect(
        (await HabitsRepo(
          db,
        ).allChecks()).where((c) => c.habitId == 'h-sekersiz' && c.day == day),
        hasLength(1),
      );
      expect(_reminderCalls(rec), 1);
      await controller.toggle('h-sekersiz', day);
      final checks = await HabitsRepo(db).allChecks();
      expect(
        checks.where((c) => c.day == day && c.habitId == 'h-sekersiz'),
        [],
      );
      expect(_reminderCalls(rec), 2);
    });

    test(
      'toggle ignores timed habits, future days and days before creation',
      () async {
        final before = await HabitsRepo(db).allChecks();
        await controller.toggle('h-ingilizce', const LocalDay(2026, 11, 20));
        await controller.toggle('h-erken', const LocalDay(2026, 11, 22));
        await controller.toggle('h-erken', const LocalDay(2026, 10, 31));
        await controller.toggle('yok', const LocalDay(2026, 11, 20));
        expect((await HabitsRepo(db).allChecks()).length, before.length);
      },
    );

    test('archive keeps the habit with archivedAt and reschedules', () async {
      await controller.archive('h-erken');
      final h = (await HabitsRepo(db).get('h-erken'))!;
      expect(h.archivedAt, demoClock().nowUtc());
      expect(rec.habits.map((x) => x.id), isNot(contains('h-erken')));
      expect(_reminderCalls(rec), 1);
    });

    test('delete removes the habit and its checks', () async {
      await controller.delete('h-erken');
      expect(await HabitsRepo(db).get('h-erken'), isNull);
      final checks = await HabitsRepo(db).allChecks();
      expect(checks.where((c) => c.habitId == 'h-erken'), isEmpty);
      expect(checks.where((c) => c.habitId == 'h-sekersiz'), isNotEmpty);
      expect(_reminderCalls(rec), 1);
    });

    test('a failing notification service does not fail the change', () async {
      final failing = HabitsController(
        db,
        demoClock(),
        LogPipeline(db, demoClock()),
        _Throwing(),
      );
      await failing.toggle('h-sekersiz', const LocalDay(2026, 11, 20));
      expect(
        (await HabitsRepo(db).allChecks()).where(
          (c) =>
              c.habitId == 'h-sekersiz' &&
              c.day == const LocalDay(2026, 11, 20),
        ),
        hasLength(1),
      );
    });
  });

  group('HabitRow', () {
    testWidgets('toggle simple habit and undo same day', (t) async {
      final db = await openTestDb(t);
      final rec = _Recorder();
      await _pumpList(t, db, rec);

      expect(find.text('Şekersiz gün'), findsOneWidget);
      expect(find.text('Basit · bekliyor'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('habit-check-h-sekersiz')));
      await t.pumpAndSettle();
      expect(find.text('Basit · tamamlandı'), findsNWidgets(2)); // + Erken kalk
      expect(
        (await _checks(t, db)).where(
          (c) =>
              c.habitId == 'h-sekersiz' &&
              c.day == const LocalDay(2026, 11, 21),
        ),
        hasLength(1),
      );
      expect(_reminderCalls(rec), greaterThan(0));

      await t.tap(find.byKey(const ValueKey('habit-check-h-sekersiz')));
      await t.pumpAndSettle();
      expect(find.text('Basit · bekliyor'), findsOneWidget);
      expect(
        (await _checks(t, db)).where(
          (c) =>
              c.habitId == 'h-sekersiz' &&
              c.day == const LocalDay(2026, 11, 21),
        ),
        isEmpty,
      );
    });

    testWidgets('timed habit not toggleable, shows progress', (t) async {
      final db = await openTestDb(t);
      await _pumpList(t, db, _Recorder());

      expect(find.text('Süreli · 20 / 30 dk'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('habit-ring-h-ingilizce')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('habit-check-h-ingilizce')),
        findsNothing,
      );

      final before = await _checks(t, db);
      await t.tap(find.byKey(const ValueKey('habit-ring-h-ingilizce')));
      await t.pumpAndSettle();
      expect((await _checks(t, db)).length, before.length);
      expect(find.text('Süreli · 20 / 30 dk'), findsOneWidget);
    });

    testWidgets('weekly habit label', (t) async {
      final db = await openTestDb(
        t,
        seed: (db) async {
          await seedDemo(db);
          final repo = HabitsRepo(db);
          await repo.put(
            _simple(
              'h-hafta',
              'Yüzme',
              schedule: const TimesPerWeekSchedule(3),
              createdAt: DateTime.utc(2026, 11, 9),
            ),
          );
          for (final d in [9, 10, 11, 16, 17]) {
            await repo.toggleCheck('h-hafta', LocalDay(2026, 11, d));
          }
        },
      );
      await _pumpList(t, db, _Recorder());

      expect(find.textContaining('bu hafta 2 / 3'), findsOneWidget);
      expect(find.text('1 hafta'), findsOneWidget);
      // Daily habits count days.
      expect(find.text('12 gün'), findsOneWidget);
    });

    testWidgets('7-day streak triggers Yedi Gün celebration', (t) async {
      final db = await openTestDb(
        t,
        seed: (db) async {
          // No demo data: its 12-day streak already unlocked the card.
          final repo = HabitsRepo(db);
          await repo.put(
            _simple('h-kitap', 'Kitap', createdAt: DateTime.utc(2026, 11, 15)),
          );
          for (var d = 15; d <= 20; d++) {
            await repo.toggleCheck('h-kitap', LocalDay(2026, 11, d));
          }
        },
      );
      await _pumpList(t, db, _Recorder());
      expect(find.text('6 gün'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('habit-check-h-kitap')));
      // The toast fades out by itself, so do not settle.
      for (var i = 0; i < 10; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Yedi Gün'), findsOneWidget);
    });

    testWidgets('deleting skill removes its timed habit', (t) async {
      final db = await openTestDb(t);
      await _pumpList(t, db, _Recorder());
      expect(find.text('İngilizce · 30 dk'), findsOneWidget);

      await t.runAsync(
        () => SkillsController(
          db,
          demoClock(),
          LogPipeline(db, demoClock()),
        ).delete('ingilizce'),
      );
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await t.pumpAndSettle();

      expect(find.text('İngilizce · 30 dk'), findsNothing);
      expect(find.text('Erken kalk'), findsOneWidget);
    });
  });

  group('HabitEditScreen', () {
    testWidgets('creates a simple daily habit', (t) async {
      final db = await openTestDb(t);
      await pumpMeskApp(t, db, '/bugun');
      await pushRoute(t, '/aliskanlik/yeni');

      expect(find.text('Yeni alışkanlık'), findsWidgets);
      final save = find.widgetWithText(FilledButton, 'Kaydet');
      expect(t.widget<FilledButton>(save).onPressed, isNull);

      await t.enterText(find.byKey(const ValueKey('habit-name')), 'Yürüyüş');
      await t.pump();
      await tapVisible(t, save);

      final habits = await _allHabits(t, db);
      final h = habits.singleWhere((h) => h.name == 'Yürüyüş');
      expect(h.kind, HabitKind.simple);
      expect(h.schedule, const DailySchedule());
      expect(h.skillId, isNull);
      expect(h.reminderMinuteOfDay, isNull);
      expect(currentLocation(t), '/bugun');
    });

    testWidgets('timed habit needs a skill and a target', (t) async {
      final db = await openTestDb(t);
      await pumpMeskApp(t, db, '/bugun');
      await pushRoute(t, '/aliskanlik/yeni');

      await t.enterText(find.byKey(const ValueKey('habit-name')), 'Gitar');
      await tapVisible(t, find.text('Süreli'));
      var save = await _saveButton(t);
      expect(t.widget<FilledButton>(save).onPressed, isNull);

      await tapVisible(t, find.byKey(const ValueKey('habit-skill-gitar')));
      await t.enterText(find.byKey(const ValueKey('habit-target')), '25');
      await t.pump();
      save = await _saveButton(t);
      await tapVisible(t, save);

      final h = (await _allHabits(t, db)).singleWhere((h) => h.name == 'Gitar');
      expect(h.kind, HabitKind.timed);
      expect(h.skillId, 'gitar');
      expect(h.targetMinutes, 25);
    });

    testWidgets('weekday and times-per-week programs', (t) async {
      final db = await openTestDb(t);
      await pumpMeskApp(t, db, '/bugun');
      await pushRoute(t, '/aliskanlik/yeni');
      await t.enterText(find.byKey(const ValueKey('habit-name')), 'Spor');

      await tapVisible(t, find.text('Belirli günler'));
      final save = find.widgetWithText(FilledButton, 'Kaydet');
      expect(t.widget<FilledButton>(save).onPressed, isNull);
      for (final w in ['Pzt', 'Çar', 'Paz']) {
        expect(find.text(w), findsOneWidget);
      }
      await tapVisible(t, find.byKey(const ValueKey('weekday-1')));
      await tapVisible(t, find.byKey(const ValueKey('weekday-3')));
      await tapVisible(t, save);
      var h = (await _allHabits(t, db)).singleWhere((h) => h.name == 'Spor');
      expect(h.schedule, const WeekdaysSchedule({1, 3}));

      await pushRoute(t, '/aliskanlik/${h.id}');
      await tapVisible(t, find.text('Haftada N kez'));
      await tapVisible(t, find.byKey(const ValueKey('times-4')));
      await tapVisible(t, find.widgetWithText(FilledButton, 'Kaydet'));
      h = (await _allHabits(t, db)).singleWhere((h) => h.name == 'Spor');
      expect(h.schedule, const TimesPerWeekSchedule(4));
    });

    testWidgets('reminder time can be set and cleared', (t) async {
      final db = await openTestDb(
        t,
        seed: (db) async {
          await seedDemo(db);
          await HabitsRepo(db)
              .put(_simple('h-su', 'Su iç', reminder: 8 * 60 + 30));
        },
      );
      await pumpMeskApp(t, db, '/bugun');
      await pushRoute(t, '/aliskanlik/h-su');

      expect(find.text('08:30'), findsOneWidget);
      await tapVisible(t, find.byTooltip('Hatırlatıcıyı kaldır'));
      expect(find.text('08:30'), findsNothing);
      await tapVisible(t, find.widgetWithText(FilledButton, 'Kaydet'));
      final h = (await _allHabits(t, db)).singleWhere((h) => h.id == 'h-su');
      expect(h.reminderMinuteOfDay, isNull);
    });

    testWidgets('archive and delete', (t) async {
      final db = await openTestDb(t);
      await pumpMeskApp(t, db, '/bugun');
      await pushRoute(t, '/aliskanlik/h-erken');
      await tapVisible(t, find.text('Arşivle'));
      var h = (await _allHabits(t, db)).singleWhere((h) => h.id == 'h-erken');
      expect(h.archivedAt, isNotNull);

      await pushRoute(t, '/aliskanlik/h-sekersiz');
      await tapVisible(t, find.text('Sil'));
      expect(find.byType(AlertDialog), findsOneWidget);
      await t.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Vazgeç'),
        ),
      );
      await t.pumpAndSettle();
      expect(
        (await _allHabits(t, db)).any((h) => h.id == 'h-sekersiz'),
        isTrue,
      );

      await tapVisible(t, find.text('Sil'));
      await t.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Sil'),
        ),
      );
      await t.pumpAndSettle();
      expect(
        (await _allHabits(t, db)).any((h) => h.id == 'h-sekersiz'),
        isFalse,
      );
      h = (await _allHabits(t, db)).singleWhere((h) => h.id == 'h-erken');
      expect(h.archivedAt, isNotNull);
    });

    testWidgets('unknown habit shows a message', (t) async {
      final db = await openTestDb(t);
      await pumpMeskApp(t, db, '/bugun');
      await pushRoute(t, '/aliskanlik/yok');
      expect(find.text('Alışkanlık bulunamadı.'), findsOneWidget);
    });
  });

  group('HabitCalendar', () {
    test('heat steps follow the completion ratio', () {
      expect(heatOpacity(0), 0);
      expect(heatOpacity(0.2), 0.3);
      expect(heatOpacity(0.5), 0.5);
      expect(heatOpacity(0.8), 0.7);
      expect(heatOpacity(1), 1);
    });

    testWidgets('month view, Monday first, Turkish names, navigation', (
      t,
    ) async {
      final db = await openTestDb(t);
      await pumpPhone(
        t,
        Scaffold(body: HabitCalendar(habit: _simple('h-erken', 'Erken kalk'))),
        overrides: appOverrides(db, demoClock()),
      );

      expect(find.text('Kasım 2026'), findsOneWidget);
      final headers = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
      final xs = [for (final h in headers) t.getTopLeft(find.text(h)).dx];
      expect(xs, [...xs]..sort());
      // 1 November 2026 is a Sunday: the last column of the first row.
      final first = t.getTopLeft(
        find.byKey(const ValueKey('cal-day-2026-11-01')),
      );
      expect(
        first.dx,
        greaterThan(
          t.getTopLeft(find.byKey(const ValueKey('cal-day-2026-11-02'))).dx,
        ),
      );
      expect(find.byKey(const ValueKey('cal-day-2026-11-30')), findsOneWidget);

      await t.tap(find.byTooltip('Önceki ay'));
      await t.pumpAndSettle();
      expect(find.text('Ekim 2026'), findsOneWidget);
      expect(find.byKey(const ValueKey('cal-day-2026-10-31')), findsOneWidget);

      await t.tap(find.byTooltip('Sonraki ay'));
      await t.pumpAndSettle();
      expect(find.text('Kasım 2026'), findsOneWidget);
      await t.tap(find.byTooltip('Sonraki ay'));
      await t.pumpAndSettle();
      expect(find.text('Aralık 2026'), findsOneWidget);
    });

    testWidgets('tapping a past day toggles a simple habit, not future days', (
      t,
    ) async {
      final db = await openTestDb(t);
      final rec = _Recorder();
      await pumpPhone(
        t,
        CelebrationHost(
          child: Scaffold(
            body: HabitCalendar(habit: _simple('h-sekersiz', 'Şekersiz gün')),
          ),
        ),
        overrides: appOverrides(db, demoClock(), notifications: rec),
      );
      bool has(int d) => _checksSync.any(
        (c) => c.habitId == 'h-sekersiz' && c.day == LocalDay(2026, 11, d),
      );
      _checksSync = await _checks(t, db);
      expect(has(19), isFalse);

      await t.tap(find.byKey(const ValueKey('cal-day-2026-11-19')));
      await t.pumpAndSettle();
      _checksSync = await _checks(t, db);
      expect(has(19), isTrue);

      await t.tap(find.byKey(const ValueKey('cal-day-2026-11-25')));
      await t.pumpAndSettle();
      _checksSync = await _checks(t, db);
      expect(has(25), isFalse);
    });

    testWidgets('overall view has a toggle-free grid of all habits', (t) async {
      final db = await openTestDb(t);
      await pumpPhone(
        t,
        const Scaffold(body: HabitCalendar()),
        overrides: appOverrides(db, demoClock()),
      );
      final before = await _checks(t, db);
      await t.tap(find.byKey(const ValueKey('cal-day-2026-11-19')));
      await t.pumpAndSettle();
      expect((await _checks(t, db)).length, before.length);
    });
  });

  group('app wiring', () {
    testWidgets('reminders are scheduled at start and on resume', (t) async {
      final db = await openTestDb(t);
      final rec = _Recorder();
      setPhoneView(t);
      await t.pumpWidget(
        ProviderScope(
          overrides: appOverrides(db, demoClock(), notifications: rec),
          child: const MeskApp(),
        ),
      );
      await t.pumpAndSettle();
      expect(_reminderCalls(rec), 1);

      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        t.binding.handleAppLifecycleStateChanged(state);
      }
      await t.pumpAndSettle();
      expect(_reminderCalls(rec), 2);
    });
  });

  group('goldens', () {
    testWidgets('habit edit', (t) async {
      final db = await openTestDb(
        t,
        seed: (db) async {
          await seedDemo(db);
          await HabitsRepo(db).put(
            _simple(
              'h-yuruyus',
              'Akşam yürüyüşü',
              schedule: const WeekdaysSchedule({1, 3, 5}),
              reminder: 19 * 60 + 30,
            ),
          );
        },
      );
      await pumpPhone(
        t,
        const HabitEditScreen(habitId: 'h-yuruyus'),
        overrides: appOverrides(db, demoClock()),
      );
      await expectGolden(t, 'habit_edit');
    }, tags: 'golden');

    testWidgets('habit calendar', (t) async {
      final db = await openTestDb(t);
      await pumpPhone(
        t,
        Scaffold(
          appBar: AppBar(title: const Text('Takvim')),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [HabitCalendar(habit: _simple('h-erken', 'Erken kalk'))],
          ),
        ),
        overrides: appOverrides(db, demoClock()),
      );
      await expectGolden(t, 'habit_calendar');
    }, tags: 'golden');
  });
}

List<HabitCheck> _checksSync = const [];

class _Throwing extends FakeNotificationService {
  @override
  Future<void> scheduleHabitReminders(
    List<Habit> habits,
    LocalDay today,
    HabitDayData data,
  ) async => throw StateError('no permission');
}
