import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/day.dart';
import '../domain/habits.dart';
import '../domain/models.dart';
import '../domain/timer_machine.dart';
import 'notifications.dart';

/// Route the Odak screen lives at; tapping any timer notification opens it.
const focusRoute = '/odak';

/// Id ranges: 1000-1099 timer phases, 1100 ongoing, 1200 free-mode warning,
/// 2000+ habit reminders.
const timerPhaseIdBase = 1000;
const timerPhaseIdCount = 100;
const ongoingTimerId = 1100;
const freeWarningId = 1200;
const habitReminderIdBase = 2000;

/// A notification the service wants the OS to deliver at [atUtc].
class PlannedNotification {
  const PlannedNotification({
    required this.id,
    required this.atUtc,
    required this.title,
    required this.body,
  });

  final int id;
  final DateTime atUtc;
  final String title;
  final String body;

  @override
  String toString() => 'PlannedNotification($id, $atUtc, $title, $body)';
}

/// Maps phase boundaries to notifications with the §5.7 copy.
List<PlannedNotification> planTimerNotifications(
  List<PhaseBoundary> boundaries,
  String skillName,
) {
  final out = <PlannedNotification>[];
  var phaseIndex = 0;
  for (final b in boundaries) {
    if (b.kind == BoundaryKind.freeModeWarning) {
      out.add(
        PlannedNotification(
          id: freeWarningId,
          atUtc: b.at.toUtc(),
          title: 'Zamanlayıcı hâlâ çalışıyor',
          body: '$skillName için 4 saattir sayıyor. Bitirmek için dokun.',
        ),
      );
      continue;
    }
    if (phaseIndex >= timerPhaseIdCount) continue;
    final workEnded = b.ending == TimerPhase.work;
    out.add(
      PlannedNotification(
        id: timerPhaseIdBase + phaseIndex++,
        atUtc: b.at.toUtc(),
        title: workEnded ? 'Pomodoro bitti' : 'Mola bitti',
        body: workEnded ? 'Mola zamanı.' : 'Odaklanma zamanı.',
      ),
    );
  }
  return out;
}

/// iOS keeps at most 64 pending local notifications. Habit reminders get 56
/// of them (the rest is left for the timer's few notifications).
const habitReminderBudget = 56;

/// How many days ahead habit reminders are planned for [habitCount] habits
/// with a reminder: the full week up to 8 habits, then fewer so that
/// habits x days stays within [habitReminderBudget] (never below one day).
int habitReminderDays(int habitCount) {
  if (habitCount <= 0) return 7;
  final days = habitReminderBudget ~/ habitCount;
  return days.clamp(1, 7);
}

/// One reminder per scheduled, not-yet-done day for the next [days] days
/// starting today. Reminder times are wall-clock times on the device.
List<PlannedNotification> planHabitReminders(
  List<Habit> habits,
  LocalDay today,
  HabitDayData data, {
  int days = 7,
}) {
  final out = <PlannedNotification>[];
  var habitIndex = 0;
  for (final h in habits) {
    final minute = h.reminderMinuteOfDay;
    if (h.archivedAt != null || minute == null) continue;
    final slot = habitIndex++;
    for (var i = 0; i < days; i++) {
      final day = today.addDays(i);
      if (!isScheduledOn(h, day)) continue;
      if (i == 0 && isCompletedOn(h, day, data)) continue;
      // A weekly target that is met needs no more nudges that week.
      final schedule = h.schedule;
      if (schedule is TimesPerWeekSchedule &&
          weekCompletions(h, day, data) >= schedule.times) {
        continue;
      }
      out.add(
        PlannedNotification(
          id: habitReminderIdBase + slot * 10 + i,
          atUtc: DateTime(
            day.year,
            day.month,
            day.day,
            minute ~/ 60,
            minute % 60,
          ).toUtc(),
          title: h.name,
          body: 'Bugünkü alışkanlığın seni bekliyor.',
        ),
      );
    }
  }
  return out;
}

/// Android channels (iOS ignores them).
enum NotificationChannel { timer, ongoing, habits }

/// The few plugin operations the service needs, so tests can substitute a
/// fake and the rest of the app never sees `flutter_local_notifications`.
abstract class NotificationsPlugin {
  Future<bool> requestPermission();

  Future<bool> canScheduleExact();

  Future<void> schedule(
    PlannedNotification n, {
    required NotificationChannel channel,
    required bool exact,
    required bool sound,
    required bool vibration,
  });

  Future<void> showOngoing({
    required String title,
    required String body,
    required DateTime phaseStartedAt,
    DateTime? phaseEndsAt,
  });

  Future<void> cancel(int id);

  Future<List<int>> pendingIds();
}

/// Real notifications. Nothing here throws: a denied permission or a plugin
/// failure only means the notification does not appear.
class LocalNotificationService implements NotificationService {
  LocalNotificationService(this._plugin, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final NotificationsPlugin _plugin;
  final DateTime Function() _now;

  Future<T> _safe<T>(Future<T> Function() call, T fallback) async {
    try {
      return await call();
    } on Object {
      // Best effort: a denied permission or plugin error must never surface.
      return fallback;
    }
  }

  @override
  Future<bool> requestPermission() => _safe(_plugin.requestPermission, false);

  @override
  Future<void> scheduleTimer(
    List<PhaseBoundary> boundaries, {
    required String skillName,
    required bool sound,
    required bool vibration,
  }) async {
    // The ongoing notification is left alone: showOngoingTimer replaces it.
    await _cancelRange(timerPhaseIdBase, timerPhaseIdBase + timerPhaseIdCount);
    await _cancelRange(freeWarningId, freeWarningId + 1);
    final exact = await _safe(_plugin.canScheduleExact, false);
    final now = _now().toUtc();
    for (final n in planTimerNotifications(boundaries, skillName)) {
      if (!n.atUtc.isAfter(now)) continue;
      await _safe(
        () => _plugin.schedule(
          n,
          channel: NotificationChannel.timer,
          exact: exact,
          sound: sound,
          vibration: vibration,
        ),
        null,
      );
    }
  }

  @override
  Future<void> showOngoingTimer({
    required String skillName,
    required DateTime phaseStartedAt,
    DateTime? phaseEndsAt,
  }) => _safe(
    () => _plugin.showOngoing(
      title: skillName.isEmpty ? 'Odak' : skillName,
      body: 'Zamanlayıcı çalışıyor',
      phaseStartedAt: phaseStartedAt,
      phaseEndsAt: phaseEndsAt,
    ),
    null,
  );

  @override
  Future<void> cancelTimer() async {
    await _cancelRange(timerPhaseIdBase, freeWarningId + 1);
    // Shown, not scheduled, so it is never in the pending list.
    await _safe(() => _plugin.cancel(ongoingTimerId), null);
  }

  @override
  Future<void> scheduleHabitReminders(
    List<Habit> habits,
    LocalDay today,
    HabitDayData data, {
    bool sound = true,
    bool vibration = true,
  }) async {
    await _cancelRange(habitReminderIdBase, 1 << 30);
    final exact = await _safe(_plugin.canScheduleExact, false);
    final now = _now().toUtc();
    final withReminder = habits
        .where((h) => h.archivedAt == null && h.reminderMinuteOfDay != null)
        .length;
    final days = habitReminderDays(withReminder);
    for (final n in planHabitReminders(habits, today, data, days: days)) {
      if (!n.atUtc.isAfter(now)) continue;
      await _safe(
        () => _plugin.schedule(
          n,
          channel: NotificationChannel.habits,
          exact: exact,
          sound: sound,
          vibration: vibration,
        ),
        null,
      );
    }
  }

  /// Cancels every pending id in [from, to).
  Future<void> _cancelRange(int from, int to) async {
    final pending = await _safe(_plugin.pendingIds, const <int>[]);
    for (final id in pending.where((id) => id >= from && id < to)) {
      await _safe(() => _plugin.cancel(id), null);
    }
  }
}

/// Used when the plugin cannot be initialised: the app keeps working without
/// notifications.
class NoopNotificationService implements NotificationService {
  const NoopNotificationService();

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> scheduleTimer(
    List<PhaseBoundary> boundaries, {
    required String skillName,
    required bool sound,
    required bool vibration,
  }) async {}

  @override
  Future<void> showOngoingTimer({
    required String skillName,
    required DateTime phaseStartedAt,
    DateTime? phaseEndsAt,
  }) async {}

  @override
  Future<void> cancelTimer() async {}

  @override
  Future<void> scheduleHabitReminders(
    List<Habit> habits,
    LocalDay today,
    HabitDayData data, {
    bool sound = true,
    bool vibration = true,
  }) async {}
}

/// Adapter over `flutter_local_notifications`.
class FlutterNotificationsPlugin implements NotificationsPlugin {
  FlutterNotificationsPlugin(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const _androidIcon = '@mipmap/ic_launcher';
  static const _chime = 'chime';

  /// Initialises the plugin and the time zone database. Throws on failure;
  /// [createLocalNotificationService] turns that into a no-op service.
  static Future<FlutterNotificationsPlugin> initialize({
    required void Function() onOpenFocus,
  }) async {
    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } on Object {
      // Instants are absolute; a wrong zone only matters for iOS wall-clock
      // matching, which this app does not use.
    }
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(_androidIcon),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
          defaultPresentBanner: true,
          defaultPresentList: true,
          defaultPresentSound: true,
        ),
      ),
      onDidReceiveNotificationResponse: (_) => onOpenFocus(),
    );
    return FlutterNotificationsPlugin(plugin);
  }

  /// Whether a notification started the app from a terminated state.
  Future<bool> launchedFromNotification() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp ?? false;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> requestPermission() async {
    final android = _android;
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _ios;
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            sound: true,
            badge: true,
          ) ??
          false;
    }
    return false;
  }

  @override
  Future<bool> canScheduleExact() async =>
      await _android?.canScheduleExactNotifications() ?? true;

  // Android 8+ fixes sound and vibration per channel, so each on/off
  // combination of the timer and habit channels is its own channel.
  AndroidNotificationDetails _androidDetails(
    NotificationChannel channel, {
    required bool sound,
    required bool vibration,
  }) {
    switch (channel) {
      case NotificationChannel.timer:
        final suffix = '${sound ? 's' : 'm'}${vibration ? 'v' : 'n'}';
        final name = switch ((sound, vibration)) {
          (true, true) => 'Zamanlayıcı',
          (true, false) => 'Zamanlayıcı (yalnızca ses)',
          (false, true) => 'Zamanlayıcı (yalnızca titreşim)',
          (false, false) => 'Zamanlayıcı (sessiz)',
        };
        return AndroidNotificationDetails(
          'timer_$suffix',
          name,
          channelDescription: 'Aşama bitişi bildirimleri',
          importance: Importance.high,
          priority: Priority.high,
          playSound: sound,
          sound: sound
              ? const RawResourceAndroidNotificationSound(_chime)
              : null,
          enableVibration: vibration,
          category: AndroidNotificationCategory.alarm,
        );
      case NotificationChannel.ongoing:
        return const AndroidNotificationDetails(
          'timer_ongoing',
          'Çalışan zamanlayıcı',
          channelDescription: 'Zamanlayıcı çalışırken süreyi gösterir',
          importance: Importance.low,
          priority: Priority.low,
          playSound: false,
          enableVibration: false,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          showWhen: true,
          usesChronometer: true,
        );
      case NotificationChannel.habits:
        final suffix = '${sound ? 's' : 'm'}${vibration ? 'v' : 'n'}';
        final name = switch ((sound, vibration)) {
          (true, true) => 'Alışkanlıklar',
          (true, false) => 'Alışkanlıklar (yalnızca ses)',
          (false, true) => 'Alışkanlıklar (yalnızca titreşim)',
          (false, false) => 'Alışkanlıklar (sessiz)',
        };
        return AndroidNotificationDetails(
          'habits_$suffix',
          name,
          channelDescription: 'Alışkanlık hatırlatmaları',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          playSound: sound,
          enableVibration: vibration,
        );
    }
  }

  @override
  Future<void> schedule(
    PlannedNotification n, {
    required NotificationChannel channel,
    required bool exact,
    required bool sound,
    required bool vibration,
  }) {
    final isTimer = channel == NotificationChannel.timer;
    return _plugin.zonedSchedule(
      id: n.id,
      title: n.title,
      body: n.body,
      scheduledDate: tz.TZDateTime.from(n.atUtc, tz.local),
      notificationDetails: NotificationDetails(
        android: _androidDetails(channel, sound: sound, vibration: vibration),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentList: true,
          presentSound: sound,
          sound: sound && isTimer ? 'chime.wav' : null,
        ),
      ),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: isTimer ? focusRoute : null,
    );
  }

  @override
  Future<void> showOngoing({
    required String title,
    required String body,
    required DateTime phaseStartedAt,
    DateTime? phaseEndsAt,
  }) async {
    final android = _android;
    if (android == null) return; // iOS has no ongoing notification in v1.
    final base = _androidDetails(
      NotificationChannel.ongoing,
      sound: false,
      vibration: false,
    );
    final countdown = phaseEndsAt != null;
    await _plugin.show(
      id: ongoingTimerId,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          base.channelId,
          base.channelName,
          channelDescription: base.channelDescription,
          importance: base.importance,
          priority: base.priority,
          playSound: false,
          enableVibration: false,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          showWhen: true,
          usesChronometer: true,
          chronometerCountDown: countdown,
          when:
              (countdown ? phaseEndsAt : phaseStartedAt).millisecondsSinceEpoch,
        ),
      ),
      payload: focusRoute,
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<List<int>> pendingIds() async => [
    for (final r in await _plugin.pendingNotificationRequests()) r.id,
  ];
}

/// Builds the real service, or a no-op one if the plugin cannot start.
/// [onOpenFocus] runs when a notification is tapped while the app is alive;
/// the returned `launchedFromNotification` answers for a cold start.
Future<({NotificationService service, Future<bool> Function() launched})>
createLocalNotificationService({required void Function() onOpenFocus}) async {
  try {
    final plugin = await FlutterNotificationsPlugin.initialize(
      onOpenFocus: onOpenFocus,
    );
    return (
      service: LocalNotificationService(plugin),
      launched: () async {
        try {
          return await plugin.launchedFromNotification();
        } on Object {
          return false;
        }
      },
    );
  } on Object catch (e) {
    debugPrint('Notifications unavailable: $e');
    return (
      service: const NoopNotificationService(),
      launched: () async => false,
    );
  }
}
