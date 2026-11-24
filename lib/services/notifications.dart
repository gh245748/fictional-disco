import '../domain/day.dart';
import '../domain/habits.dart';
import '../domain/models.dart';
import '../domain/timer_machine.dart';

/// Local notifications (the real implementation arrives in Task 19).
abstract class NotificationService {
  Future<bool> requestPermission();

  Future<void> scheduleTimer(
    List<PhaseBoundary> boundaries, {
    required String skillName,
    required bool sound,
    required bool vibration,
  });

  Future<void> showOngoingTimer({
    required String skillName,
    required DateTime phaseStartedAt,
    DateTime? phaseEndsAt,
  });

  Future<void> cancelTimer();

  Future<void> scheduleHabitReminders(
    List<Habit> habits,
    LocalDay today,
    HabitDayData data, {
    bool sound = true,
    bool vibration = true,
  });
}

/// Records every call by name; [requestPermission] answers
/// [permissionGranted].
class FakeNotificationService implements NotificationService {
  FakeNotificationService({this.permissionGranted = true});

  bool permissionGranted;
  final List<String> calls = [];

  @override
  Future<bool> requestPermission() async {
    calls.add('requestPermission');
    return permissionGranted;
  }

  @override
  Future<void> scheduleTimer(
    List<PhaseBoundary> boundaries, {
    required String skillName,
    required bool sound,
    required bool vibration,
  }) async {
    calls.add('scheduleTimer');
  }

  @override
  Future<void> showOngoingTimer({
    required String skillName,
    required DateTime phaseStartedAt,
    DateTime? phaseEndsAt,
  }) async {
    calls.add('showOngoingTimer');
  }

  @override
  Future<void> cancelTimer() async {
    calls.add('cancelTimer');
  }

  @override
  Future<void> scheduleHabitReminders(
    List<Habit> habits,
    LocalDay today,
    HabitDayData data, {
    bool sound = true,
    bool vibration = true,
  }) async {
    calls.add('scheduleHabitReminders');
  }
}
