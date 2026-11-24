import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/db.dart';
import '../../data/entries_repo.dart';
import '../../data/habits_repo.dart';
import '../../data/kv_repo.dart';
import '../../data/log_pipeline.dart';
import '../../domain/day.dart';
import '../../domain/habits.dart';
import '../../domain/models.dart';
import '../../services/notifications.dart';

/// Saves, checks, archives and deletes habits.
///
/// Every change re-evaluates achievements through the [LogPipeline] and
/// reschedules the habit reminders. The returned [PipelineResult] goes to
/// `runAndCelebrate`.
class HabitsController {
  HabitsController(this.db, this.clock, this.pipeline, this.notifications)
    : _habits = HabitsRepo(db);

  final MeskDb db;
  final Clock clock;
  final LogPipeline pipeline;
  final NotificationService notifications;
  final HabitsRepo _habits;

  static const _nothing = PipelineResult([]);

  Future<PipelineResult> save(Habit h) async {
    await _habits.put(h);
    return _settle();
  }

  /// Flips the manual check of a simple habit on [day]. Timed habits (derived
  /// from time entries), future days and days before the habit existed are
  /// ignored.
  Future<PipelineResult> toggle(String habitId, LocalDay day) async {
    final h = await _habits.get(habitId);
    if (h == null || h.kind != HabitKind.simple) return _nothing;
    final today = await _today();
    final created = habitCreatedDay(h);
    if (day.compareTo(today) > 0 || day.compareTo(created) < 0) {
      return _nothing;
    }
    await _habits.toggleCheck(habitId, day);
    return _settle();
  }

  Future<PipelineResult> archive(String id) async {
    final h = await _habits.get(id);
    if (h == null) return _nothing;
    await _habits.put(h.copyWith(archivedAt: clock.nowUtc()));
    return _settle();
  }

  Future<PipelineResult> delete(String id) async {
    await _habits.deleteWithChecks(id);
    return _settle();
  }

  /// Replaces the pending habit reminders with the plan for the current
  /// data. Used after every change, at app start and on resume. A failing
  /// notification service never fails the caller.
  ///
  /// The window is 7 days for up to 8 habits with a reminder and shrinks
  /// beyond that so habits x days stays within iOS's 64 pending
  /// notifications (see `habitReminderDays`).
  Future<void> rescheduleReminders() async {
    try {
      final settings = await KvRepo(db).settings();
      final today = todayOf(clock, settings.dayStartHour);
      final data = buildHabitDayData(
        await EntriesRepo(db).all(),
        await _habits.allChecks(),
        settings.dayStartHour,
      );
      final active = [
        for (final h in await _habits.all())
          if (h.archivedAt == null) h,
      ];
      await notifications.scheduleHabitReminders(active, today, data);
    } on Object {
      // Reminders are best effort; the next change, start or resume retries.
    }
  }

  Future<PipelineResult> _settle() async {
    await rescheduleReminders();
    return pipeline.afterHabitChange();
  }

  Future<LocalDay> _today() async =>
      todayOf(clock, (await KvRepo(db).settings()).dayStartHour);
}

final habitsControllerProvider = Provider<HabitsController>(
  (ref) => HabitsController(
    ref.watch(dbProvider),
    ref.watch(clockProvider),
    ref.watch(pipelineProvider),
    ref.watch(notificationsProvider),
  ),
);
