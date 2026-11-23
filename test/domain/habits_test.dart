import 'package:flutter_test/flutter_test.dart';
import 'package:mesk/domain/day.dart';
import 'package:mesk/domain/habits.dart';
import 'package:mesk/domain/models.dart';

const today = const LocalDay(2026, 11, 21); // Saturday

Habit habit(
  String id,
  HabitSchedule schedule, {
  HabitKind kind = HabitKind.simple,
  String? skillId,
  int? targetMinutes,
  DateTime? createdAt,
}) => Habit(
  id: id,
  name: id,
  kind: kind,
  skillId: skillId,
  targetMinutes: targetMinutes,
  schedule: schedule,
  createdAt: createdAt ?? DateTime.utc(2026, 10, 1, 9),
);

TimeEntry entry(
  LocalDay day,
  int seconds, {
  String skill = 's',
  EntrySource source = EntrySource.manual,
  int hour = 12,
}) => TimeEntry(
  id: '${day.toIso()}-$seconds-$hour-${source.name}',
  skillId: skill,
  startedAt: DateTime.utc(day.year, day.month, day.day, hour),
  endedAt: DateTime.utc(
    day.year,
    day.month,
    day.day,
    hour,
  ).add(Duration(seconds: seconds)),
  offsetMinutes: 0,
  seconds: seconds,
  source: source,
  pomodoros: 0,
);

HabitDayData checksData(String id, Iterable<LocalDay> days) =>
    buildHabitDayData(const [], [
      for (final d in days) HabitCheck(habitId: id, day: d),
    ], 0);

void main() {
  test('timed habit completes from tracked time only', () {
    final h = habit(
      'h',
      const DailySchedule(),
      kind: HabitKind.timed,
      skillId: 's',
      targetMinutes: 30,
    );
    var data = buildHabitDayData([entry(today, 1200)], const [], 0);
    expect(isCompletedOn(h, today, data), false);
    expect(timedSecondsOn(h, today, data), 1200);
    data = buildHabitDayData(
      [entry(today, 1200), entry(today, 600, hour: 14)],
      const [],
      0,
    );
    expect(isCompletedOn(h, today, data), true);
    data = buildHabitDayData(
      [entry(today, 1200), entry(today, 3600, source: EntrySource.prior)],
      const [],
      0,
    );
    expect(isCompletedOn(h, today, data), false);
    expect(timedSecondsOn(h, today, data), 1200);
  });

  test('timed habit without skill or target is never completed', () {
    final data = buildHabitDayData([entry(today, 9999)], const [], 0);
    final noSkill = habit(
      'a',
      const DailySchedule(),
      kind: HabitKind.timed,
      targetMinutes: 1,
    );
    final noTarget = habit(
      'b',
      const DailySchedule(),
      kind: HabitKind.timed,
      skillId: 's',
    );
    expect(isCompletedOn(noSkill, today, data), false);
    expect(isCompletedOn(noTarget, today, data), false);
  });

  test('daily streak excludes unfinished today', () {
    final h = habit('h', const DailySchedule());
    final five = [for (var i = 1; i <= 5; i++) today.addDays(-i)];
    expect(currentStreak(h, today, checksData('h', five)), 5);
    expect(currentStreak(h, today, checksData('h', [...five, today])), 6);
    final gap = [
      for (final i in [1, 2, 4, 5]) today.addDays(-i),
    ];
    expect(currentStreak(h, today, checksData('h', gap)), 2);
    expect(bestStreak(h, today, checksData('h', gap)), 2);
  });

  test('weekdays schedule ignores off days', () {
    final h = habit('h', const WeekdaysSchedule({1, 3, 5}));
    final days = <LocalDay>[];
    for (var i = 0; i < 21; i++) {
      final d = today.addDays(-i);
      if ({1, 3, 5}.contains(d.weekday)) days.add(d);
    }
    expect(days.length, 9);
    expect(currentStreak(h, today, checksData('h', days)), 9);
    expect(isScheduledOn(h, const LocalDay(2026, 11, 20)), true);
    expect(isScheduledOn(h, today), false);
  });

  test('times per week counts weeks', () {
    final h = habit('h', const TimesPerWeekSchedule(3));
    final weekStart = today.weekStart; // 2026-11-16
    List<LocalDay> week(LocalDay start, int n) => [
      for (var i = 0; i < n; i++) start.addDays(i),
    ];
    final past = [
      ...week(weekStart.addDays(-7), 3),
      ...week(weekStart.addDays(-14), 4),
    ];
    expect(
      currentStreak(
        h,
        today,
        checksData('h', [...past, ...week(weekStart, 2)]),
      ),
      2,
    );
    expect(weekCompletions(h, today, checksData('h', week(weekStart, 2))), 2);
    expect(
      currentStreak(
        h,
        today,
        checksData('h', [...past, ...week(weekStart, 3)]),
      ),
      3,
    );
  });

  test('today list', () {
    final daily = habit('d', const DailySchedule());
    final wk = habit('w', const WeekdaysSchedule({1, 3, 5}));
    final wkSat = habit('ws', const WeekdaysSchedule({6}));
    final tpw = habit('t', const TimesPerWeekSchedule(3));
    final habits = [daily, wk, wkSat, tpw];
    final ws = today.weekStart;
    var data = checksData('t', [ws, ws.addDays(1)]);
    var list = todayHabits(habits, today, data);
    expect(list.map((t) => t.habit.id), ['d', 'ws', 't']);
    final t = list.last;
    expect(t.weekDone, 2);
    expect(t.weekTarget, 3);
    expect(t.done, false);
    expect(list.first.weekDone, isNull);
    expect(list.first.progressSeconds, isNull);

    data = checksData('t', [ws, ws.addDays(1), ws.addDays(2)]);
    list = todayHabits(habits, today, data);
    expect(list.map((t) => t.habit.id), ['d', 'ws']);

    data = checksData('t', [ws, ws.addDays(1), today]);
    list = todayHabits(habits, today, data);
    expect(list.map((t) => t.habit.id), ['d', 'ws', 't']);
    expect(list.last.done, true);
  });

  test('today list shows timed progress seconds', () {
    final h = habit(
      'h',
      const DailySchedule(),
      kind: HabitKind.timed,
      skillId: 's',
      targetMinutes: 30,
    );
    final data = buildHabitDayData([entry(today, 600)], const [], 0);
    final item = todayHabits([h], today, data).single;
    expect(item.progressSeconds, 600);
    expect(item.done, false);
  });

  test('irade points include streak milestones once per run', () {
    final h = habit('h', const DailySchedule());
    final scattered = [for (var i = 0; i < 10; i++) today.addDays(-2 * i - 1)];
    expect(iradePoints([h], today, checksData('h', scattered)), 10);
    final run = [for (var i = 1; i <= 30; i++) today.addDays(-i)];
    final data = checksData('h', run);
    expect(iradePoints([h], today, data), 50);
    expect(streakRunLengths(h, today, data), [30]);
    expect(streakMilestoneBonus, {7: 5, 30: 15, 100: 50, 365: 150});
  });

  test('completions before createdAt do not count', () {
    final h = habit(
      'h',
      const DailySchedule(),
      kind: HabitKind.timed,
      skillId: 's',
      targetMinutes: 10,
      createdAt: DateTime.utc(2026, 11, 21, 8),
    );
    final data = buildHabitDayData(
      [for (var i = 1; i <= 7; i++) entry(today.addDays(-i), 3600)],
      const [],
      0,
    );
    expect(iradePoints([h], today, data), 0);
    expect(currentStreak(h, today, data), 0);
    expect(isCompletedOn(h, today.addDays(-1), data), false);
  });

  test('day start hour moves late entries to previous day', () {
    // 03:30 local (+03:00) on 2026-11-22 is 00:30 UTC.
    final e = TimeEntry(
      id: 'e',
      skillId: 's',
      startedAt: DateTime.utc(2026, 11, 22, 0, 30),
      endedAt: DateTime.utc(2026, 11, 22, 1),
      offsetMinutes: 180,
      seconds: 1800,
      source: EntrySource.free,
      pomodoros: 0,
    );
    final data = buildHabitDayData([e], const [], 4);
    expect(data.trackedSecondsBySkillDay['s']![LocalDay(2026, 11, 21)], 1800);
    expect(
      data.trackedSecondsBySkillDay['s']!.containsKey(LocalDay(2026, 11, 22)),
      false,
    );
  });

  test('perfect week', () {
    final daily = habit('d', const DailySchedule());
    final wk = habit('w', const WeekdaysSchedule({1, 3, 5}));
    final tpw = habit('t', const TimesPerWeekSchedule(2));
    final week = [for (var i = 0; i < 7; i++) const LocalDay(2026, 11, 9).addDays(i)];
    HabitDayData build(Set<HabitCheck> c) => buildHabitDayData(const [], c, 0);
    final checks = <HabitCheck>{
      for (final d in week) HabitCheck(habitId: 'd', day: d),
      for (final d in week.where((d) => {1, 3, 5}.contains(d.weekday)))
        HabitCheck(habitId: 'w', day: d),
      HabitCheck(habitId: 't', day: week[0]),
      HabitCheck(habitId: 't', day: week[4]),
    };
    final habits = [daily, wk, tpw];
    expect(hadPerfectWeek(habits, today, build(checks)), true);
    final missing = {...checks}..remove(HabitCheck(habitId: 'd', day: week[2]));
    expect(hadPerfectWeek(habits, today, build(missing)), false);
    final tpwShort = {...checks}
      ..remove(HabitCheck(habitId: 't', day: week[4]));
    expect(hadPerfectWeek(habits, today, build(tpwShort)), false);
  });

  test('maxDailyStreak ignores times-per-week habits', () {
    final d = habit('d', const DailySchedule());
    final t = habit('t', const TimesPerWeekSchedule(1));
    final days = [for (var i = 1; i <= 4; i++) today.addDays(-i)];
    final data = buildHabitDayData(const [], [
      for (final x in days) HabitCheck(habitId: 'd', day: x),
      for (var i = 0; i < 6; i++)
        HabitCheck(habitId: 't', day: today.weekStart.addDays(-7 * i)),
    ], 0);
    expect(maxDailyStreak([d, t], today, data), 4);
    expect(maxDailyStreak([t], today, data), 0);
  });
}
