import 'day.dart';
import 'models.dart';

/// Length of the rolling window used to estimate the daily pace.
const int paceWindowDays = 28;

class GoalStatus {
  const GoalStatus({
    required this.progress,
    required this.remainingSeconds,
    required this.requiredDailySeconds,
    required this.daysLeft,
    required this.projectedDay,
    required this.completed,
    required this.expired,
  });

  /// 0..1, capped at 1 once the target is reached.
  final double progress;
  final int remainingSeconds;

  /// Seconds per day needed to meet the deadline; null when there is no
  /// deadline, the goal is completed, or the deadline has passed.
  final int? requiredDailySeconds;

  /// Days from today to the deadline, inclusive; null without a deadline.
  final int? daysLeft;

  /// Day the target is reached at the current pace; null when the pace is 0
  /// or the goal is completed.
  final LocalDay? projectedDay;
  final bool completed;
  final bool expired;
}

int _ceilDiv(int a, int b) => (a + b - 1) ~/ b;

/// Average tracked seconds per day over the last 28 days (or since
/// [firstTrackedDay] if more recent), ending [today]. Floors.
int paceSecondsPerDay(
  Map<LocalDay, int> trackedSecondsByDay,
  LocalDay today,
  LocalDay? firstTrackedDay,
) {
  if (firstTrackedDay == null) return 0;
  final sinceFirst = firstTrackedDay.daysUntil(today) + 1;
  final window = sinceFirst < paceWindowDays ? sinceFirst : paceWindowDays;
  if (window <= 0) return 0;
  var total = 0;
  for (var i = 0; i < window; i++) {
    total += trackedSecondsByDay[today.addDays(-i)] ?? 0;
  }
  return total ~/ window;
}

GoalStatus goalStatus(
  Goal goal, {
  required int realSeconds,
  required int paceSecondsPerDay,
  required LocalDay today,
}) {
  final completed = realSeconds >= goal.targetSeconds;
  final remaining = completed ? 0 : goal.targetSeconds - realSeconds;
  final progress = goal.targetSeconds <= 0
      ? 1.0
      : (realSeconds / goal.targetSeconds).clamp(0.0, 1.0);
  final deadline = goal.deadline;
  final daysLeft = deadline == null ? null : today.daysUntil(deadline) + 1;
  final expired = !completed && daysLeft != null && daysLeft <= 0;
  final required = (completed || daysLeft == null || daysLeft <= 0)
      ? null
      : _ceilDiv(remaining, daysLeft);
  final projected = (completed || paceSecondsPerDay <= 0)
      ? null
      : today.addDays(_ceilDiv(remaining, paceSecondsPerDay));
  return GoalStatus(
    progress: progress,
    remainingSeconds: remaining,
    requiredDailySeconds: required,
    daysLeft: daysLeft,
    projectedDay: projected,
    completed: completed,
    expired: expired,
  );
}

/// Minutes per day (rounded up) needed to meet the deadline.
int habitMinutesFor(GoalStatus s) {
  final r = s.requiredDailySeconds;
  if (r == null) {
    throw StateError('Goal has no required daily pace');
  }
  return _ceilDiv(r, 60);
}
