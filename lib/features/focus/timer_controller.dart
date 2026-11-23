import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/db.dart';
import '../../data/kv_repo.dart';
import '../../data/log_pipeline.dart';
import '../../data/presets_repo.dart';
import '../../data/skills_repo.dart';
import '../../domain/day.dart';
import '../../domain/models.dart';
import '../../domain/timer_machine.dart';
import '../../services/notifications.dart';

/// Thrown by [TimerController.start] while another session is active
/// ("Aynı anda tek oturum", §5.7).
class TimerBusyException implements Exception {
  const TimerBusyException();

  @override
  String toString() => 'TimerBusyException: a session is already active';
}

/// The focus timer (§5.7) on top of [TimerMachine].
///
/// The stored timer is the source of truth: every operation reads it, applies
/// one transition at the clock's current instant, writes it back and then
/// reschedules notifications. Operations run one at a time, in call order.
/// A failing notification service never stops the timer (Review Focus 5).
class TimerController extends Notifier<TimerState> {
  late MeskDb _db;
  late Clock _clock;
  late NotificationService _notifications;
  late LogPipeline _pipeline;
  Future<void> _queue = Future.value();

  KvRepo get _kv => KvRepo(_db);

  @override
  TimerState build() {
    _db = ref.watch(dbProvider);
    _clock = ref.watch(clockProvider);
    _notifications = ref.watch(notificationsProvider);
    _pipeline = ref.watch(pipelineProvider);
    _queue = Future.value();
    // Load the stored session (it survives app kills). A failure leaves the
    // timer idle until the next reconcile.
    unawaited(reconcile().catchError((Object _) {}));
    return TimerState.idle;
  }

  DateTime get _now => _clock.nowUtc();

  /// Runs [op] after every earlier operation has finished.
  Future<T> _serial<T>(Future<T> Function() op) {
    final run = _queue.then((_) => op());
    _queue = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  void _publish(TimerState s) {
    if (ref.mounted) state = s;
  }

  /// Writes [next], publishes it and reschedules notifications.
  Future<void> _commit(TimerState next) async {
    await _kv.saveTimer(next);
    _publish(next);
    await _syncNotifications(next);
  }

  /// Applies [transition] to the stored timer at the current instant.
  Future<void> _apply(TimerState Function(TimerState s, DateTime now) step) =>
      _serial(() async {
        final s = await _kv.timer();
        final next = step(s, _now);
        if (next == s) {
          _publish(s);
          return;
        }
        await _commit(next);
      });

  /// Starts a session. Pomodoro uses the preset [presetId] (the first
  /// built-in when it is missing). Remembers the skill and its preset.
  /// Throws [TimerBusyException] while another session is active.
  Future<void> start({
    required TimerMode mode,
    required String skillId,
    String? presetId,
  }) => _serial(() async {
    final current = await _kv.timer();
    if (current.status != TimerStatus.idle) {
      _publish(current);
      throw const TimerBusyException();
    }
    TimerPreset? preset;
    if (mode == TimerMode.pomodoro) {
      final presets = PresetsRepo(_db);
      preset =
          (presetId == null ? null : await presets.get(presetId)) ??
          await presets.get(TimerPreset.builtIns.first.id) ??
          TimerPreset.builtIns.first;
    }
    final next = TimerMachine.start(
      mode: mode,
      skillId: skillId,
      preset: preset,
      now: _now,
    );
    await _db.database.transaction((txn) async {
      final settings = await _kv.settings(txn: txn);
      await _kv.saveSettings(
        settings.copyWith(
          lastSkillId: skillId,
          lastPresetBySkill: preset == null
              ? null
              : {...settings.lastPresetBySkill, skillId: preset.id},
        ),
        txn: txn,
      );
      await _kv.saveTimer(next, txn: txn);
    });
    _publish(next);
    await _syncNotifications(next);
  });

  Future<void> pause() => _apply(TimerMachine.pause);

  Future<void> resume() => _apply(TimerMachine.resume);

  /// "Molayı atla".
  Future<void> skipPhase() => _apply(TimerMachine.skipPhase);

  /// "Sonraki aşama".
  Future<void> startNextPhase() => _apply(TimerMachine.startNextPhase);

  /// Reloads the stored timer and closes the phases that ended meanwhile.
  /// Call it on app start and resume; then ask about [unattendedPhases].
  Future<void> reconcile() => _serial(() async {
    final s = await _kv.timer();
    final next = TimerMachine.advance(s, _now);
    if (next != s) await _kv.saveTimer(next);
    _publish(next);
    await _syncNotifications(next);
  });

  /// Work phases that ran without the user, as of now.
  List<WorkPhaseRecord> unattendedPhases() =>
      TimerMachine.unattendedPhases(state, _now);

  /// The user's answer to the unattended sheet: keeps the phases starting at
  /// [keptStarts], drops the others.
  Future<void> keepUnattended(Set<DateTime> keptStarts) =>
      _apply((s, now) => TimerMachine.keepUnattended(s, keptStarts, now));

  /// What finishing now would save. Throws [StateError] while idle.
  SessionSummary preview({int? trimToSeconds}) =>
      TimerMachine.finish(state, _now, trimToSeconds: trimToSeconds);

  /// Ends the session and saves it as one entry for [skillId] (default: the
  /// session's skill). Returns null, saving nothing, when the session is
  /// shorter than a minute (§5.7); the session ends either way. Throws
  /// [StateError] while idle. If saving fails the session stays.
  Future<PipelineResult?> finishAndSave({
    String? skillId,
    int? trimToSeconds,
    String? note,
  }) => _serial(() async {
    final s = await _kv.timer();
    if (s.status == TimerStatus.idle) {
      _publish(s);
      throw StateError('No timer session to finish');
    }
    final summary = TimerMachine.finish(s, _now, trimToSeconds: trimToSeconds);
    PipelineResult? result;
    if (!summary.tooShort) {
      final text = note?.trim();
      // After a backwards clock jump `now` can precede the start; keep the
      // entry consistent (it never spans less than its work time).
      final minEnd = summary.startedAt.add(
        Duration(seconds: summary.workSeconds),
      );
      result = await _pipeline.saveEntry(
        TimeEntry(
          id: newId(),
          skillId: skillId ?? summary.skillId,
          startedAt: summary.startedAt,
          endedAt: summary.endedAt.isBefore(minEnd) ? minEnd : summary.endedAt,
          offsetMinutes: _clock.offsetMinutesAt(summary.startedAt),
          seconds: summary.workSeconds,
          source: s.mode == TimerMode.pomodoro
              ? EntrySource.pomodoro
              : EntrySource.free,
          pomodoros: summary.pomodoros,
          note: text == null || text.isEmpty ? null : text,
        ),
      );
    }
    await _commit(TimerState.idle);
    return result;
  });

  /// Ends the session without saving it.
  Future<void> discard() => _serial(() => _commit(TimerState.idle));

  /// Mirrors [s] in the system notifications. Failures are swallowed: the
  /// timer works without notifications (denied permission included).
  Future<void> _syncNotifications(TimerState s) async {
    Future<void> guard(Future<void> Function() call) async {
      try {
        await call();
      } on Object {
        // Notifications are best effort; the stored timer stays correct.
      }
    }

    if (s.status != TimerStatus.running) {
      await guard(_notifications.cancelTimer);
      return;
    }
    final now = _now;
    var skillName = '';
    var sound = true;
    var vibration = true;
    try {
      skillName = (await SkillsRepo(_db).get(s.skillId!))?.name ?? '';
      final settings = await _kv.settings();
      sound = settings.sound;
      vibration = settings.vibration;
    } on Object {
      // Fall back to the defaults above.
    }
    await guard(
      () => _notifications.scheduleTimer(
        TimerMachine.upcomingBoundaries(s, now),
        skillName: skillName,
        sound: sound,
        vibration: vibration,
      ),
    );
    final remaining = TimerMachine.remainingInPhase(s, now);
    await guard(
      () => _notifications.showOngoingTimer(
        skillName: skillName,
        phaseStartedAt: s.phaseStartedAt!,
        phaseEndsAt: remaining == null
            ? null
            : now.add(Duration(seconds: remaining)),
      ),
    );
  }
}

final timerControllerProvider = NotifierProvider<TimerController, TimerState>(
  TimerController.new,
);
