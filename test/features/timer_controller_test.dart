import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast.dart' show DatabaseClient;
import 'package:mesk/data/db.dart';
import 'package:mesk/data/entries_repo.dart';
import 'package:mesk/data/kv_repo.dart';
import 'package:mesk/data/presets_repo.dart';
import 'package:mesk/domain/day.dart';
import 'package:mesk/domain/habits.dart';
import 'package:mesk/domain/models.dart';
import 'package:mesk/domain/timer_machine.dart';
import 'package:mesk/features/focus/timer_controller.dart';
import 'package:mesk/features/skills/skills_controller.dart';
import 'package:mesk/services/notifications.dart';

import '../support/demo_data.dart';
import '../support/golden.dart';

/// Records the boundaries handed to [scheduleTimer].
class _RecordingNotifications extends FakeNotificationService {
  final List<List<PhaseBoundary>> scheduled = [];

  @override
  Future<void> scheduleTimer(
    List<PhaseBoundary> boundaries, {
    required String skillName,
    required bool sound,
    required bool vibration,
  }) async {
    scheduled.add(boundaries);
    await super.scheduleTimer(
      boundaries,
      skillName: skillName,
      sound: sound,
      vibration: vibration,
    );
  }
}

/// Permission denied and every call fails (Review Focus 5).
class _BrokenNotifications implements NotificationService {
  int calls = 0;

  Never _fail() {
    calls++;
    throw StateError('notifications unavailable');
  }

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> scheduleTimer(
    List<PhaseBoundary> boundaries, {
    required String skillName,
    required bool sound,
    required bool vibration,
  }) async => _fail();

  @override
  Future<void> showOngoingTimer({
    required String skillName,
    required DateTime phaseStartedAt,
    DateTime? phaseEndsAt,
  }) async => _fail();

  @override
  Future<void> cancelTimer() => throw StateError('sync failure');

  @override
  Future<void> scheduleHabitReminders(
    List<Habit> habits,
    LocalDay today,
    HabitDayData data, {
    bool sound = true,
    bool vibration = true,
  }) async => _fail();
}

/// Fails the first [failures] plain writes of an idle timer (a session
/// reset after saving), like a crash between the two writes.
class _FlakyKv extends KvRepo {
  _FlakyKv(super.db, {this.failures = 1});

  int failures;

  @override
  Future<void> saveTimer(TimerState s, {DatabaseClient? txn}) async {
    if (s.status == TimerStatus.idle && txn == null && failures > 0) {
      failures--;
      throw StateError('disk full');
    }
    await super.saveTimer(s, txn: txn);
  }
}

class _Env {
  _Env(this.container, this.db, this.clock);

  final ProviderContainer container;
  final MeskDb db;
  final FixedClock clock;

  TimerController get ctl => container.read(timerControllerProvider.notifier);
  TimerState get state => container.read(timerControllerProvider);
  DateTime get t0 => DateTime.utc(2026, 11, 21, 18);

  Future<List<TimeEntry>> newEntries(String skillId) async => [
    for (final e in await EntriesRepo(db).forSkill(skillId))
      if (!e.id.startsWith('$skillId-')) e,
  ];
}

Future<_Env> _setup(
  NotificationService notifications, {
  KvRepo Function(MeskDb db)? store,
}) async {
  final db = await MeskDb.openMemory();
  await seedDemo(db);
  final clock = demoClock();
  final container = ProviderContainer(
    overrides: [
      ...appOverrides(db, clock, notifications: notifications),
      if (store != null) timerStoreProvider.overrideWithValue(store(db)),
    ],
  );
  addTearDown(() async {
    container.dispose();
    await db.close();
  });
  container.listen(timerControllerProvider, (_, _) {});
  return _Env(container, db, clock);
}

/// 25/5/15/4 with both auto-start flags on.
const _autoAll = TimerPreset(
  'oto',
  'Otomatik',
  25,
  5,
  15,
  4,
  true,
  true,
  false,
);

void main() {
  test('deleting the skill being timed ends the shown session', () async {
    final notes = _RecordingNotifications();
    final env = await _setup(notes);
    await env.ctl.start(mode: TimerMode.free, skillId: 'okuma');
    expect(env.state.status, TimerStatus.running);

    await env.container.read(skillsControllerProvider).delete('okuma');
    expect(env.state.status, TimerStatus.idle);
    expect(notes.calls, contains('cancelTimer'));
    // Finishing now is a clean error, not a half-state.
    await expectLater(env.ctl.finishAndSave(), throwsStateError);
  });

  test('start persists and schedules boundaries', () async {
    final notes = _RecordingNotifications();
    final env = await _setup(notes);
    await env.ctl.start(
      mode: TimerMode.pomodoro,
      skillId: 'okuma',
      presetId: 'derin',
    );

    final stored = await KvRepo(env.db).timer();
    expect(stored.status, TimerStatus.running);
    expect(stored.skillId, 'okuma');
    expect(stored.preset!.id, 'derin');
    expect(stored.sessionStartedAt, env.t0);
    expect(env.state, stored);

    expect(notes.calls, containsAll(['scheduleTimer', 'showOngoingTimer']));
    final boundaries = notes.scheduled.last;
    expect(boundaries.first.at, env.t0.add(const Duration(minutes: 50)));
    expect(boundaries.first.ending, TimerPhase.work);
    // Breaks start on their own, work does not: work end, then break end.
    expect(boundaries, hasLength(2));

    final settings = await KvRepo(env.db).settings();
    expect(settings.lastSkillId, 'okuma');
    expect(settings.lastPresetBySkill['okuma'], 'derin');
  });

  test('every change persists the timer', () async {
    final env = await _setup(FakeNotificationService());
    await env.ctl.start(mode: TimerMode.free, skillId: 'okuma');
    env.clock.advance(const Duration(minutes: 10));
    await env.ctl.pause();
    expect((await KvRepo(env.db).timer()).status, TimerStatus.paused);
    expect(env.state.status, TimerStatus.paused);
    env.clock.advance(const Duration(minutes: 5));
    await env.ctl.resume();
    final stored = await KvRepo(env.db).timer();
    expect(stored.status, TimerStatus.running);
    expect(stored, env.state);
    expect(env.ctl.preview().workSeconds, 600);
  });

  test('phases that ended while the screen was watched are attended', () async {
    final env = await _setup(FakeNotificationService());
    await PresetsRepo(env.db).put(_autoAll);
    await env.ctl.start(
      mode: TimerMode.pomodoro,
      skillId: 'okuma',
      presetId: 'oto',
    );
    // The Odak screen reconciles within a second of every boundary.
    for (final minutes in [26, 31, 56]) {
      env.clock.utc = env.t0.add(Duration(minutes: minutes));
      await env.ctl.reconcile(attended: true);
    }
    expect((await KvRepo(env.db).timer()).completedWork, hasLength(2));
    expect(env.ctl.unattendedPhases(), isEmpty);
  });

  test('reconcile after 90 min with auto work lists unattended', () async {
    final env = await _setup(FakeNotificationService());
    await PresetsRepo(env.db).put(_autoAll);
    await env.ctl.start(
      mode: TimerMode.pomodoro,
      skillId: 'okuma',
      presetId: 'oto',
    );
    env.clock.advance(const Duration(minutes: 90));
    await env.ctl.reconcile();

    // Work 0-25 was started by the user; 30-55 and 60-85 ran on their own.
    final phases = env.ctl.unattendedPhases();
    expect(
      [for (final p in phases) p.start],
      [
        env.t0.add(const Duration(minutes: 30)),
        env.t0.add(const Duration(minutes: 60)),
      ],
    );
    expect((await KvRepo(env.db).timer()).completedWork, hasLength(3));

    await env.ctl.keepUnattended({phases.first.start});
    expect(env.ctl.unattendedPhases(), isEmpty);
    final result = await env.ctl.finishAndSave();
    expect(result, isNotNull);
    final saved = (await env.newEntries('okuma')).single;
    expect(saved.seconds, 2 * 25 * 60);
    expect(saved.pomodoros, 2);
  });

  test('finish saves pomodoro entry with count', () async {
    final notes = FakeNotificationService();
    final env = await _setup(notes);
    await env.ctl.start(
      mode: TimerMode.pomodoro,
      skillId: 'okuma',
      presetId: 'klasik',
    );
    // Work 0-25, break 25-30, then the machine waits for the user.
    env.clock.advance(const Duration(minutes: 32));
    await env.ctl.startNextPhase();
    // Work 32-57, then a break that does not count.
    env.clock.advance(const Duration(minutes: 28));
    expect(env.ctl.preview().workSeconds, 3000);

    final result = await env.ctl.finishAndSave(note: '  Roman  ');
    expect(result, isNotNull);
    final saved = (await env.newEntries('okuma')).single;
    expect(saved.source, EntrySource.pomodoro);
    expect(saved.seconds, 3000);
    expect(saved.pomodoros, 2);
    expect(saved.startedAt, env.t0);
    expect(saved.endedAt, env.t0.add(const Duration(minutes: 60)));
    expect(saved.offsetMinutes, 180);
    expect(saved.note, 'Roman');

    expect(env.state.status, TimerStatus.idle);
    expect((await KvRepo(env.db).timer()).status, TimerStatus.idle);
    expect(notes.calls.last, 'cancelTimer');
  });

  test('retry after a failed reset saves the session once', () async {
    final env = await _setup(FakeNotificationService(), store: _FlakyKv.new);
    await env.ctl.start(mode: TimerMode.free, skillId: 'okuma');
    env.clock.advance(const Duration(minutes: 40));
    // The entry is written, then resetting the timer fails.
    await expectLater(env.ctl.finishAndSave(), throwsStateError);
    expect(await env.newEntries('okuma'), hasLength(1));
    expect(env.state.status, TimerStatus.running);

    env.clock.advance(const Duration(minutes: 1));
    expect(await env.ctl.finishAndSave(), isNotNull);
    final saved = (await env.newEntries('okuma')).single;
    expect(saved.seconds, 40 * 60);
    expect(env.state.status, TimerStatus.idle);
    expect((await KvRepo(env.db).timer()).status, TimerStatus.idle);
  });

  test('free session saves to the chosen skill with trim', () async {
    final env = await _setup(FakeNotificationService());
    await env.ctl.start(mode: TimerMode.free, skillId: 'okuma');
    env.clock.advance(const Duration(hours: 2));
    await env.ctl.finishAndSave(skillId: 'satranc', trimToSeconds: 4500);
    expect(await env.newEntries('okuma'), isEmpty);
    final saved = (await env.newEntries('satranc')).single;
    expect(saved.source, EntrySource.free);
    expect(saved.seconds, 4500);
    expect(saved.pomodoros, 0);
    expect(saved.note, isNull);
  });

  test('too short returns null and saves nothing', () async {
    final notes = FakeNotificationService();
    final env = await _setup(notes);
    final before = (await EntriesRepo(env.db).all()).length;
    await env.ctl.start(mode: TimerMode.free, skillId: 'okuma');
    env.clock.advance(const Duration(seconds: 59));
    expect(env.ctl.preview().tooShort, isTrue);

    expect(await env.ctl.finishAndSave(), isNull);
    expect(await EntriesRepo(env.db).all(), hasLength(before));
    // The session is over either way.
    expect(env.state.status, TimerStatus.idle);
    expect(notes.calls.last, 'cancelTimer');
  });

  test('one session at a time', () async {
    final env = await _setup(FakeNotificationService());
    await env.ctl.start(mode: TimerMode.free, skillId: 'okuma');
    final running = env.state;
    await expectLater(
      env.ctl.start(mode: TimerMode.free, skillId: 'satranc'),
      throwsA(isA<TimerBusyException>()),
    );
    expect(env.state, running);
    expect(await KvRepo(env.db).timer(), running);
  });

  test('discard ends the session without an entry', () async {
    final notes = FakeNotificationService();
    final env = await _setup(notes);
    final before = (await EntriesRepo(env.db).all()).length;
    await env.ctl.start(mode: TimerMode.free, skillId: 'okuma');
    env.clock.advance(const Duration(minutes: 30));
    await env.ctl.discard();
    expect(env.state, TimerState.idle);
    expect(await KvRepo(env.db).timer(), TimerState.idle);
    expect(await EntriesRepo(env.db).all(), hasLength(before));
    expect(notes.calls.last, 'cancelTimer');
  });

  test('loads the stored session and follows outside resets', () async {
    final db = await MeskDb.openMemory();
    await seedDemo(db);
    final clock = demoClock();
    final stored = TimerMachine.start(
      mode: TimerMode.free,
      skillId: 'okuma',
      now: clock.utc.subtract(const Duration(minutes: 5)),
    );
    await KvRepo(db).saveTimer(stored);
    final notes = FakeNotificationService();
    final container = ProviderContainer(
      overrides: appOverrides(db, clock, notifications: notes),
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    container.listen(timerControllerProvider, (_, _) {});
    final ctl = container.read(timerControllerProvider.notifier);
    await ctl.reconcile();
    expect(container.read(timerControllerProvider), stored);

    // Deleting the skill resets the stored timer (Ruling R14).
    await KvRepo(db).saveTimer(TimerState.idle);
    await ctl.reconcile();
    expect(container.read(timerControllerProvider), TimerState.idle);
    expect(notes.calls.last, 'cancelTimer');
  });

  test('denied permission: timer still runs and saves', () async {
    final broken = _BrokenNotifications();
    final env = await _setup(broken);
    await env.ctl.start(
      mode: TimerMode.pomodoro,
      skillId: 'okuma',
      presetId: 'klasik',
    );
    expect(env.state.status, TimerStatus.running);
    env.clock.advance(const Duration(minutes: 10));
    await env.ctl.pause();
    env.clock.advance(const Duration(minutes: 10));
    await env.ctl.resume();
    env.clock.advance(const Duration(minutes: 5));
    await env.ctl.reconcile();
    final result = await env.ctl.finishAndSave();
    expect(result, isNotNull);
    final saved = (await env.newEntries('okuma')).single;
    expect(saved.seconds, 15 * 60);
    expect(env.state.status, TimerStatus.idle);
    expect(broken.calls, greaterThan(0));
  });
}
