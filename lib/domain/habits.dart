import 'day.dart';
import 'models.dart';

/// Per-day aggregates the habit rules read from.
class HabitDayData {
  const HabitDayData({
    required this.trackedSecondsBySkillDay,
    required this.checksByHabit,
  });

  final Map<String, Map<LocalDay, int>> trackedSecondsBySkillDay;
  final Map<String, Set<LocalDay>> checksByHabit;
}

/// Prior-experience entries are excluded; every other entry counts on the
/// day it started (honouring [dayStartHour]).
HabitDayData buildHabitDayData(
  Iterable<TimeEntry> entries,
  Iterable<HabitCheck> checks,
  int dayStartHour,
) {
  final tracked = <String, Map<LocalDay, int>>{};
  for (final e in entries) {
    if (e.source == EntrySource.prior) continue;
    final day = dayOfInstant(e.startedAt, e.offsetMinutes, dayStartHour);
    final perDay = tracked.putIfAbsent(e.skillId, () => <LocalDay, int>{});
    perDay[day] = (perDay[day] ?? 0) + e.seconds;
  }
  final byHabit = <String, Set<LocalDay>>{};
  for (final c in checks) {
    byHabit.putIfAbsent(c.habitId, () => <LocalDay>{}).add(c.day);
  }
  return HabitDayData(
    trackedSecondsBySkillDay: tracked,
    checksByHabit: byHabit,
  );
}

LocalDay _dayOfUtc(DateTime t) {
  final u = t.toUtc();
  return LocalDay(u.year, u.month, u.day);
}

/// The first day the habit can be done on: the logical day it was made on,
/// or the UTC date of its creation for habits saved without one.
LocalDay habitCreatedDay(Habit h) => h.createdDay ?? _dayOfUtc(h.createdAt);

LocalDay _createdDay(Habit h) => habitCreatedDay(h);

/// Whether [d] is a scheduled day. Times-per-week habits may be done on any
/// day, so every day counts as scheduled for them.
bool isScheduledOn(Habit h, LocalDay d) => switch (h.schedule) {
  DailySchedule() => true,
  WeekdaysSchedule(:final weekdays) => weekdays.contains(d.weekday),
  TimesPerWeekSchedule() => true,
};

int timedSecondsOn(Habit h, LocalDay d, HabitDayData data) {
  final skill = h.skillId;
  if (skill == null) return 0;
  return data.trackedSecondsBySkillDay[skill]?[d] ?? 0;
}

bool isCompletedOn(Habit h, LocalDay d, HabitDayData data) {
  if (d.compareTo(_createdDay(h)) < 0) return false;
  if (h.kind == HabitKind.timed) {
    final target = h.targetMinutes;
    if (h.skillId == null || target == null) return false;
    return timedSecondsOn(h, d, data) >= target * 60;
  }
  return data.checksByHabit[h.id]?.contains(d) ?? false;
}

/// Completed days in the Monday-Sunday week containing [anyDayInWeek].
int weekCompletions(Habit h, LocalDay anyDayInWeek, HabitDayData data) {
  final start = anyDayInWeek.weekStart;
  var n = 0;
  for (var i = 0; i < 7; i++) {
    if (isCompletedOn(h, start.addDays(i), data)) n++;
  }
  return n;
}

/// Lengths of every streak run from the habit's creation up to [today], in
/// chronological order. The unit still in progress (today / this week) never
/// breaks a run and counts only once completed.
List<int> streakRunLengths(Habit h, LocalDay today, HabitDayData data) =>
    _walkStreaks(h, today, data).runs;

({List<int> runs, int current}) _walkStreaks(
  Habit h,
  LocalDay today,
  HabitDayData data,
) {
  final runs = <int>[];
  var run = 0;
  void close() {
    if (run > 0) runs.add(run);
    run = 0;
  }

  final created = _createdDay(h);
  final schedule = h.schedule;
  if (schedule is TimesPerWeekSchedule) {
    final currentWeek = today.weekStart;
    for (
      var w = created.weekStart;
      w.compareTo(currentWeek) <= 0;
      w = w.addDays(7)
    ) {
      if (weekCompletions(h, w, data) >= schedule.times) {
        run++;
      } else if (w != currentWeek) {
        close();
      }
    }
  } else {
    for (var d = created; d.compareTo(today) <= 0; d = d.addDays(1)) {
      if (!isScheduledOn(h, d)) continue;
      if (isCompletedOn(h, d, data)) {
        run++;
      } else if (d != today) {
        close();
      }
    }
  }
  final current = run; // still open: nothing broke it
  close();
  return (runs: runs, current: current);
}

int currentStreak(Habit h, LocalDay today, HabitDayData data) =>
    _walkStreaks(h, today, data).current;

int bestStreak(Habit h, LocalDay today, HabitDayData data) {
  var best = 0;
  for (final r in streakRunLengths(h, today, data)) {
    if (r > best) best = r;
  }
  return best;
}

const Map<int, int> streakMilestoneBonus = {7: 5, 30: 15, 100: 50, 365: 150};

/// Days [h] was completed, from its creation up to [today].
int completionCount(Habit h, LocalDay today, HabitDayData data) {
  var n = 0;
  for (var d = _createdDay(h); d.compareTo(today) <= 0; d = d.addDays(1)) {
    if (isCompletedOn(h, d, data)) n++;
  }
  return n;
}

/// Bonus points of every streak run of [h] that reached a milestone.
int streakBonusPoints(Habit h, LocalDay today, HabitDayData data) {
  var total = 0;
  for (final run in streakRunLengths(h, today, data)) {
    for (final e in streakMilestoneBonus.entries) {
      if (e.key <= run) total += e.value;
    }
  }
  return total;
}

int iradePoints(Iterable<Habit> habits, LocalDay today, HabitDayData data) {
  var total = 0;
  for (final h in habits) {
    total +=
        completionCount(h, today, data) + streakBonusPoints(h, today, data);
  }
  return total;
}

/// Best streak over daily and weekdays habits only.
int maxDailyStreak(Iterable<Habit> habits, LocalDay today, HabitDayData data) {
  var best = 0;
  for (final h in habits) {
    if (h.schedule is TimesPerWeekSchedule) continue;
    final b = bestStreak(h, today, data);
    if (b > best) best = b;
  }
  return best;
}

/// True when some fully past Monday-Sunday week had at least one scheduled
/// habit-day and all of them were completed. Times-per-week habits count as
/// met when the week reached their target.
bool hadPerfectWeek(Iterable<Habit> habits, LocalDay today, HabitDayData data) {
  final list = habits.toList();
  if (list.isEmpty) return false;
  final currentWeek = today.weekStart;
  var first = currentWeek;
  for (final h in list) {
    final w = _createdDay(h).weekStart;
    if (w.compareTo(first) < 0) first = w;
  }
  for (var w = first; w.compareTo(currentWeek) < 0; w = w.addDays(7)) {
    var units = 0;
    var allDone = true;
    for (final h in list) {
      final created = _createdDay(h);
      final archived = h.archivedAt == null ? null : _dayOfUtc(h.archivedAt!);
      final schedule = h.schedule;
      if (schedule is TimesPerWeekSchedule) {
        final end = w.addDays(6);
        if (created.compareTo(end) > 0) continue;
        if (archived != null && archived.compareTo(w) < 0) continue;
        units++;
        if (weekCompletions(h, w, data) < schedule.times) allDone = false;
      } else {
        for (var i = 0; i < 7; i++) {
          final d = w.addDays(i);
          if (d.compareTo(created) < 0 || !isScheduledOn(h, d)) continue;
          if (archived != null && archived.compareTo(d) < 0) continue;
          units++;
          if (!isCompletedOn(h, d, data)) allDone = false;
        }
      }
    }
    if (units > 0 && allDone) return true;
  }
  return false;
}

class TodayHabit {
  const TodayHabit({
    required this.habit,
    required this.done,
    required this.progressSeconds,
    required this.weekDone,
    required this.weekTarget,
    required this.streak,
  });

  final Habit habit;
  final bool done;
  final int? progressSeconds;
  final int? weekDone;
  final int? weekTarget;
  final int streak;
}

List<TodayHabit> todayHabits(
  Iterable<Habit> habits,
  LocalDay today,
  HabitDayData data,
) {
  final out = <TodayHabit>[];
  for (final h in habits) {
    final done = isCompletedOn(h, today, data);
    final schedule = h.schedule;
    int? weekDone;
    int? weekTarget;
    if (schedule is TimesPerWeekSchedule) {
      weekDone = weekCompletions(h, today, data);
      weekTarget = schedule.times;
      if (weekDone >= weekTarget && !done) continue;
    } else if (!isScheduledOn(h, today)) {
      continue;
    }
    out.add(
      TodayHabit(
        habit: h,
        done: done,
        progressSeconds: h.kind == HabitKind.timed
            ? timedSecondsOn(h, today, data)
            : null,
        weekDone: weekDone,
        weekTarget: weekTarget,
        streak: currentStreak(h, today, data),
      ),
    );
  }
  return out;
}
