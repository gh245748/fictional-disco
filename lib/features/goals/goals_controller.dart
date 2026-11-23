import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/views.dart';
import '../../data/db.dart';
import '../../data/entries_repo.dart';
import '../../data/goals_repo.dart';
import '../../data/kv_repo.dart';
import '../../data/log_pipeline.dart';
import '../../data/skills_repo.dart';
import '../../domain/day.dart';
import '../../domain/goals.dart';
import '../../domain/habits.dart';
import '../../domain/models.dart';
import '../habits/habits_controller.dart';

/// Saves, closes and extends goals and turns a goal into a daily habit.
///
/// Goal completion lives in the [LogPipeline]: saving a goal runs
/// `afterHabitChange`, which re-evaluates every active goal, so a goal whose
/// target is already met completes at once. The returned [PipelineResult]
/// goes to `runAndCelebrate`.
class GoalsController {
  GoalsController(this.db, this.clock, this.pipeline, this.habits)
    : _goals = GoalsRepo(db);

  final MeskDb db;
  final Clock clock;
  final LogPipeline pipeline;
  final HabitsController habits;
  final GoalsRepo _goals;

  /// Stores [g]. A skill has one active goal, so any other active goal of the
  /// same skill is closed; saving the active goal itself just edits it.
  Future<PipelineResult> save(Goal g) async {
    final now = clock.nowUtc();
    await db.database.transaction((txn) async {
      for (final other in await _goals.all(txn: txn)) {
        if (other.skillId == g.skillId && other.id != g.id && other.active) {
          await _goals.put(other.copyWith(closedAt: now), txn: txn);
        }
      }
      await _goals.put(g, txn: txn);
    });
    return pipeline.afterHabitChange();
  }

  /// Closes the goal without completing it.
  Future<void> close(String id) async {
    final g = await _goals.get(id);
    if (g == null || !g.active) return;
    await _goals.put(g.copyWith(closedAt: clock.nowUtc()));
  }

  /// Moves the deadline of [id] to [newDeadline].
  Future<void> extend(String id, LocalDay newDeadline) async {
    final g = await _goals.get(id);
    if (g == null) return;
    await _goals.put(g.copyWith(deadline: newDeadline));
  }

  /// Creates the daily timed habit "{skill} · {m} dk" whose target is the
  /// goal's required daily minutes (rounded up) and returns its id. Throws
  /// [StateError] when the goal has no such pace (no deadline, expired or
  /// completed).
  Future<String> toHabit(String goalId) async =>
      (await toHabitResult(goalId)).$1;

  /// [toHabit] with the [PipelineResult] of saving the habit, for
  /// `runAndCelebrate`.
  Future<(String, PipelineResult)> toHabitResult(String goalId) async {
    final goal = await _goals.get(goalId);
    final skill = goal == null ? null : await SkillsRepo(db).get(goal.skillId);
    if (goal == null || skill == null) {
      throw StateError('No goal $goalId');
    }
    final settings = await KvRepo(db).settings();
    final entries = await EntriesRepo(db).all();
    final view = buildSkillViews(
      skills: [skill],
      entries: entries,
      awards: await AwardsRepo(db).all(),
      goals: [goal],
      dayData: buildHabitDayData(entries, const [], settings.dayStartHour),
      today: todayOf(clock, settings.dayStartHour),
    ).single;
    final status = view.goal;
    if (status == null) throw StateError('Goal $goalId is not active');
    final minutes = habitMinutesFor(status);
    final habit = Habit(
      id: newId(),
      name: '${skill.name} · $minutes dk',
      kind: HabitKind.timed,
      skillId: skill.id,
      targetMinutes: minutes,
      schedule: const DailySchedule(),
      createdAt: clock.nowUtc(),
    );
    return (habit.id, await habits.save(habit));
  }
}

final goalsControllerProvider = Provider<GoalsController>(
  (ref) => GoalsController(
    ref.watch(dbProvider),
    ref.watch(clockProvider),
    ref.watch(pipelineProvider),
    ref.watch(habitsControllerProvider),
  ),
);
