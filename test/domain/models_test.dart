import 'package:flutter_test/flutter_test.dart';
import 'package:mesk/domain/day.dart';
import 'package:mesk/domain/level_curve.dart';
import 'package:mesk/domain/models.dart';
import 'package:mesk/domain/stats.dart';

void main() {
  final t = DateTime.utc(2026, 11, 23, 10, 30);
  final t2 = DateTime.utc(2026, 11, 24, 8);
  const day = LocalDay(2026, 11, 23);

  void roundTrip<T>(
    T x,
    T Function(Map<String, Object?>) from,
    Map<String, Object?> Function(T) to,
  ) {
    expect(from(to(x)), x);
  }

  test('every model round-trips through JSON', () {
    roundTrip(
      const Character(name: 'A', titleSkillId: 's', titleLevel: 3),
      Character.fromJson,
      (x) => x.toJson(),
    );
    roundTrip(
      const Character(name: 'A'),
      Character.fromJson,
      (x) => x.toJson(),
    );

    roundTrip(
      Skill(
        id: 's',
        name: 'Resim',
        primary: Stat.yaraticilik,
        secondary: Stat.zihin,
        description: 'd',
        createdAt: t,
        archivedAt: t2,
        graphX: 1.5,
        graphY: -2,
      ),
      Skill.fromJson,
      (x) => x.toJson(),
    );
    final s0 = Skill(id: 's', name: 'Resim', primary: Stat.irade, createdAt: t);
    roundTrip(s0, Skill.fromJson, (x) => x.toJson());
    expect(s0.archived, isFalse);
    expect(s0.copyWith(archivedAt: t2).archived, isTrue);
    expect(
      s0.copyWith(archivedAt: t2).copyWith(archivedAt: null).archived,
      isFalse,
    );

    roundTrip(
      SkillLink(id: 'l', a: 'a', b: 'b', createdAt: t),
      SkillLink.fromJson,
      (x) => x.toJson(),
    );

    final e = TimeEntry(
      id: 'e',
      skillId: 's',
      startedAt: t,
      endedAt: t2,
      offsetMinutes: 180,
      seconds: 1500,
      source: EntrySource.pomodoro,
      pomodoros: 1,
      note: 'n',
    );
    roundTrip(e, TimeEntry.fromJson, (x) => x.toJson());
    roundTrip(
      e.copyWith(note: null, source: EntrySource.prior),
      TimeEntry.fromJson,
      (x) => x.toJson(),
    );
    expect(e.isPrior, isFalse);
    expect(e.copyWith(source: EntrySource.prior).isPrior, isTrue);
    expect(e.toJson()['startedAt'], '2026-11-23T10:30:00.000Z');
    expect(TimeEntry.fromJson(e.toJson()).startedAt.isUtc, isTrue);

    roundTrip(
      const XpAward(
        id: 'x',
        entryId: 'e',
        skillId: 's',
        seconds: 10,
        rateBp: 1000,
      ),
      XpAward.fromJson,
      (x) => x.toJson(),
    );
    roundTrip(
      LevelReached(skillId: 's', level: 5, at: t),
      LevelReached.fromJson,
      (x) => x.toJson(),
    );
    roundTrip(
      TierReached(skillId: 's', tier: HiddenTier.efsane, at: t),
      TierReached.fromJson,
      (x) => x.toJson(),
    );
    roundTrip(
      AchievementUnlock(key: 'k', at: t),
      AchievementUnlock.fromJson,
      (x) => x.toJson(),
    );

    final h = Habit(
      id: 'h',
      name: 'Oku',
      kind: HabitKind.timed,
      skillId: 's',
      targetMinutes: 20,
      schedule: const WeekdaysSchedule({1, 3}),
      reminderMinuteOfDay: 540,
      createdAt: t,
      archivedAt: t2,
    );
    roundTrip(h, Habit.fromJson, (x) => x.toJson());
    roundTrip(
      Habit(
        id: 'h',
        name: 'Su',
        kind: HabitKind.simple,
        schedule: const DailySchedule(),
        createdAt: t,
      ),
      Habit.fromJson,
      (x) => x.toJson(),
    );

    roundTrip(
      const HabitCheck(habitId: 'h', day: day),
      HabitCheck.fromJson,
      (x) => x.toJson(),
    );

    final g = Goal(
      id: 'g',
      skillId: 's',
      targetSeconds: 3600,
      deadline: day,
      createdAt: t,
      completedAt: t2,
      closedAt: t2,
    );
    roundTrip(g, Goal.fromJson, (x) => x.toJson());
    final g0 = Goal(id: 'g', skillId: 's', targetSeconds: 3600, createdAt: t);
    roundTrip(g0, Goal.fromJson, (x) => x.toJson());
    expect(g0.active, isTrue);
    expect(g.active, isFalse);
    expect(g0.copyWith(closedAt: t2).active, isFalse);

    for (final p in TimerPreset.builtIns) {
      roundTrip(p, TimerPreset.fromJson, (x) => x.toJson());
    }

    roundTrip(AppSettings.defaults, AppSettings.fromJson, (x) => x.toJson());
    roundTrip(
      AppSettings(
        bonusRateBp: 500,
        dayStartHour: 4,
        sound: false,
        vibration: false,
        lastBackupAt: t,
        lastSkillId: 's',
        lastPresetBySkill: const {'s': 'klasik'},
        onboarded: true,
      ),
      AppSettings.fromJson,
      (x) => x.toJson(),
    );
  });

  test('link is normalized', () {
    final l = SkillLink.normalized(id: 'l', x: 'b', y: 'a', createdAt: t);
    expect(l.a, 'a');
    expect(l.b, 'b');
    expect(
      () => SkillLink.normalized(id: 'l', x: 'a', y: 'a', createdAt: t),
      throwsA(isA<AssertionError>()),
    );
  });

  test('schedules round-trip', () {
    for (final s in <HabitSchedule>[
      const DailySchedule(),
      const WeekdaysSchedule({1, 5, 7}),
      const TimesPerWeekSchedule(3),
    ]) {
      expect(HabitSchedule.fromJson(s.toJson()), s);
    }
    expect(const WeekdaysSchedule({1, 2}), const WeekdaysSchedule({2, 1}));
  });

  test('preset ranges validated', () {
    for (final p in TimerPreset.builtIns) {
      expect(p.validate(), isNull);
    }
    final p = TimerPreset.builtIns.first;
    expect(p.copyWith(workMinutes: 0).validate(), isNotNull);
    expect(p.copyWith(workMinutes: 181).validate(), isNotNull);
    expect(p.copyWith(workMinutes: 180).validate(), isNull);
    expect(p.copyWith(shortBreakMinutes: 61).validate(), isNotNull);
    expect(p.copyWith(longBreakMinutes: 91).validate(), isNotNull);
    expect(p.copyWith(roundsBeforeLong: 13).validate(), isNotNull);
    expect(p.copyWith(roundsBeforeLong: 12).validate(), isNull);
  });

  test('newId yields distinct uuids', () {
    expect(newId(), isNot(newId()));
    expect(newId().length, 36);
  });
}
