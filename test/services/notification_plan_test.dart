import 'package:flutter_test/flutter_test.dart';
import 'package:mesk/domain/day.dart';
import 'package:mesk/domain/habits.dart';
import 'package:mesk/domain/models.dart';
import 'package:mesk/domain/timer_machine.dart';
import 'package:mesk/services/local_notifications.dart';

const today = LocalDay(2026, 11, 23); // Monday

Habit habit(
  String name,
  HabitSchedule schedule, {
  int? reminder = 8 * 60 + 30,
}) => Habit(
  id: name,
  name: name,
  kind: HabitKind.simple,
  schedule: schedule,
  reminderMinuteOfDay: reminder,
  createdAt: DateTime.utc(2026, 10, 1, 9),
);

HabitDayData data([Map<String, Set<LocalDay>> checks = const {}]) =>
    HabitDayData(trackedSecondsBySkillDay: const {}, checksByHabit: checks);

class ThrowingPlugin implements NotificationsPlugin {
  final List<String> calls = [];

  Never _boom(String name) {
    calls.add(name);
    throw StateError('permission denied: $name');
  }

  @override
  Future<bool> requestPermission() async => _boom('requestPermission');

  @override
  Future<bool> canScheduleExact() async => _boom('canScheduleExact');

  @override
  Future<void> schedule(
    PlannedNotification n, {
    required NotificationChannel channel,
    required bool exact,
    required bool sound,
    required bool vibration,
  }) async => _boom('schedule');

  @override
  Future<void> showOngoing({
    required String title,
    required String body,
    required DateTime phaseStartedAt,
    DateTime? phaseEndsAt,
  }) async => _boom('showOngoing');

  @override
  Future<void> cancel(int id) async => _boom('cancel');

  @override
  Future<List<int>> pendingIds() async => _boom('pendingIds');
}

class RecordingPlugin implements NotificationsPlugin {
  bool exactAllowed = true;
  List<int> pending = [];
  final List<PlannedNotification> scheduled = [];
  final List<bool> exactFlags = [];
  final List<NotificationChannel> channels = [];
  final List<int> cancelled = [];
  int ongoing = 0;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<bool> canScheduleExact() async => exactAllowed;

  @override
  Future<void> schedule(
    PlannedNotification n, {
    required NotificationChannel channel,
    required bool exact,
    required bool sound,
    required bool vibration,
  }) async {
    scheduled.add(n);
    exactFlags.add(exact);
    channels.add(channel);
  }

  @override
  Future<void> showOngoing({
    required String title,
    required String body,
    required DateTime phaseStartedAt,
    DateTime? phaseEndsAt,
  }) async => ongoing++;

  @override
  Future<void> cancel(int id) async => cancelled.add(id);

  @override
  Future<List<int>> pendingIds() async => pending;
}

void main() {
  habitBudgetTests();
  test('timer plan copy and ids', () {
    final t0 = DateTime.utc(2026, 11, 23, 10);
    final plan = planTimerNotifications([
      PhaseBoundary(
        at: t0.add(const Duration(minutes: 25)),
        kind: BoundaryKind.phaseEnd,
        ending: TimerPhase.work,
        next: TimerPhase.shortBreak,
      ),
      PhaseBoundary(
        at: t0.add(const Duration(minutes: 30)),
        kind: BoundaryKind.phaseEnd,
        ending: TimerPhase.shortBreak,
        next: TimerPhase.work,
      ),
    ], 'İngilizce');
    expect(plan.map((n) => n.id), [1000, 1001]);
    expect(plan[0].title, 'Pomodoro bitti');
    expect(plan[0].body, 'Mola zamanı.');
    expect(plan[0].atUtc, t0.add(const Duration(minutes: 25)));
    expect(plan[1].title, 'Mola bitti');
    expect(plan[1].body, 'Odaklanma zamanı.');
  });

  test('free warning planned at +4h', () {
    final t0 = DateTime.utc(2026, 11, 23, 10);
    final at = t0.add(const Duration(hours: 4));
    final plan = planTimerNotifications([
      PhaseBoundary(at: at, kind: BoundaryKind.freeModeWarning),
    ], 'Gitar');
    expect(plan, hasLength(1));
    expect(plan.single.id, 1200);
    expect(plan.single.atUtc, at);
    expect(plan.single.title, 'Zamanlayıcı hâlâ çalışıyor');
    expect(
      plan.single.body,
      'Gitar için 4 saattir sayıyor. Bitirmek için dokun.',
    );
  });

  test('habit plan skips unscheduled and done days', () {
    // Monday-only habit: the week from Monday has one scheduled day.
    final weekly = habit('Yürüyüş', const WeekdaysSchedule({1}));
    final plan = planHabitReminders([weekly], today, data());
    expect(plan, hasLength(1));
    expect(plan.single.title, 'Yürüyüş');
    expect(plan.single.body, 'Bugünkü alışkanlığın seni bekliyor.');
    expect(plan.single.atUtc, DateTime(2026, 11, 23, 8, 30).toUtc());

    // Daily habit already done today: today is skipped, six days remain.
    final daily = habit('Su', const DailySchedule());
    final done = planHabitReminders(
      [daily],
      today,
      data({
        'Su': {today},
      }),
    );
    expect(done, hasLength(6));
    expect(done.first.atUtc, DateTime(2026, 11, 24, 8, 30).toUtc());
    expect(done.map((n) => n.id).toSet(), hasLength(6));

    // No reminder time, or archived: nothing.
    expect(
      planHabitReminders(
        [habit('x', const DailySchedule(), reminder: null)],
        today,
        data(),
      ),
      isEmpty,
    );
  });

  test('a weekly habit at its target is not reminded for the rest of the week', () {
    final weekly = habit('Spor', const TimesPerWeekSchedule(2));
    // No check yet: every day of the window.
    expect(planHabitReminders([weekly], today, data()), hasLength(7));

    // One of two done on Monday: Tuesday to Sunday still remind.
    final one = planHabitReminders(
      [weekly],
      today,
      data({
        'Spor': {today},
      }),
    );
    expect(one, hasLength(6));

    // Monday and Tuesday done: the target is met, so Wednesday to Sunday stay
    // quiet. From Tuesday the window ends on next Monday, which reminds again.
    final met = planHabitReminders(
      [weekly],
      today.addDays(1),
      data({
        'Spor': {today, today.addDays(1)},
      }),
    );
    expect(met.map((n) => n.atUtc), [DateTime(2026, 11, 30, 8, 30).toUtc()]);
  });

  test('service methods never throw when permission denied', () async {
    final service = LocalNotificationService(ThrowingPlugin());
    expect(await service.requestPermission(), isFalse);
    await service.scheduleTimer(
      [
        PhaseBoundary(
          at: DateTime.now().toUtc().add(const Duration(minutes: 5)),
          kind: BoundaryKind.phaseEnd,
          ending: TimerPhase.work,
          next: TimerPhase.shortBreak,
        ),
      ],
      skillName: 'X',
      sound: true,
      vibration: true,
    );
    await service.showOngoingTimer(
      skillName: 'X',
      phaseStartedAt: DateTime.now(),
    );
    await service.cancelTimer();
    await service.scheduleHabitReminders(
      [habit('Su', const DailySchedule())],
      today,
      data(),
    );
  });

  test('uses inexact scheduling when exact alarms are not permitted', () async {
    final plugin = RecordingPlugin()..exactAllowed = false;
    final service = LocalNotificationService(plugin);
    await service.scheduleTimer(
      [
        PhaseBoundary(
          at: DateTime.now().toUtc().add(const Duration(minutes: 5)),
          kind: BoundaryKind.phaseEnd,
          ending: TimerPhase.work,
          next: TimerPhase.shortBreak,
        ),
      ],
      skillName: 'X',
      sound: true,
      vibration: false,
    );
    expect(plugin.scheduled.single.id, 1000);
    expect(plugin.exactFlags, [false]);
    expect(plugin.channels, [NotificationChannel.timer]);
  });

  test(
    'scheduleTimer clears stale timer ids and skips past boundaries',
    () async {
      final plugin = RecordingPlugin()..pending = [1000, 1001, 1100, 2003];
      final service = LocalNotificationService(plugin);
      await service.scheduleTimer(
        [
          PhaseBoundary(
            at: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
            kind: BoundaryKind.phaseEnd,
            ending: TimerPhase.work,
            next: TimerPhase.shortBreak,
          ),
        ],
        skillName: 'X',
        sound: true,
        vibration: true,
      );
      expect(plugin.cancelled, [1000, 1001]);
      expect(plugin.scheduled, isEmpty);
    },
  );

  test(
    'cancelTimer removes timer ids and the ongoing one, not habits',
    () async {
      final plugin = RecordingPlugin()..pending = [1000, 1200, 2003];
      await LocalNotificationService(plugin).cancelTimer();
      expect(plugin.cancelled, [1000, 1200, 1100]);
    },
  );
}

void habitBudgetTests() {
  group('habit reminder budget', () {
    test('up to seven habits keep the full seven days', () {
      for (var n = 0; n <= 7; n++) {
        expect(habitReminderDays(n), 7);
      }
    });

    test('more habits shrink the window so habits x days <= 56', () {
      expect(habitReminderDays(8), 7);
      expect(habitReminderDays(9), 6);
      expect(habitReminderDays(14), 4);
      expect(habitReminderDays(56), 1);
      expect(habitReminderDays(80), 1);
      for (var n = 1; n <= 56; n++) {
        expect(n * habitReminderDays(n), lessThanOrEqualTo(56));
      }
    });
  });
}
