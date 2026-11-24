import 'package:collection/collection.dart';

import 'models.dart';

/// Pomodoro and free (stopwatch) focus timer as a pure state machine (§5.7).
///
/// Time is never counted tick by tick: every value is derived from stored
/// instants, so the state stays correct across app kills and phone locks.

enum TimerMode { pomodoro, free }

enum TimerPhase { work, shortBreak, longBreak }

/// `waiting`: a pomodoro phase ended with its auto-start flag off; [TimerState.phase]
/// is then the phase that will start on the user's tap.
enum TimerStatus { idle, running, paused, waiting }

enum BoundaryKind { phaseEnd, freeModeWarning }

String? _isoN(DateTime? d) => d?.toUtc().toIso8601String();
DateTime? _dtN(Object? v) =>
    v == null ? null : DateTime.parse(v as String).toUtc();

/// A closed pomodoro work phase.
class WorkPhaseRecord {
  const WorkPhaseRecord({
    required this.start,
    required this.end,
    required this.seconds,
    required this.full,
    required this.unattended,
  });

  factory WorkPhaseRecord.fromJson(Map<String, Object?> j) => WorkPhaseRecord(
    start: _dtN(j['start'])!,
    end: _dtN(j['end'])!,
    seconds: j['seconds']! as int,
    full: j['full']! as bool,
    unattended: j['unattended']! as bool,
  );

  /// Effective start: `end - seconds` (a pause shifts it forward).
  final DateTime start;
  final DateTime end;
  final int seconds;

  /// Ran its whole planned length (counts as a pomodoro).
  final bool full;

  /// Auto-started after the user's last interaction (§5.7 "gözetimsiz devam").
  final bool unattended;

  Map<String, Object?> toJson() => {
    'start': _isoN(start),
    'end': _isoN(end),
    'seconds': seconds,
    'full': full,
    'unattended': unattended,
  };

  @override
  bool operator ==(Object other) =>
      other is WorkPhaseRecord &&
      other.start == start &&
      other.end == end &&
      other.seconds == seconds &&
      other.full == full &&
      other.unattended == unattended;

  @override
  int get hashCode => Object.hash(start, end, seconds, full, unattended);
}

class TimerState {
  const TimerState({
    required this.status,
    required this.mode,
    this.skillId,
    this.preset,
    this.phase = TimerPhase.work,
    this.phaseStartedAt,
    this.pausedElapsedSeconds,
    this.completedWork = const [],
    this.sessionStartedAt,
    this.lastInteractionAt,
  });

  factory TimerState.fromJson(Map<String, Object?> j) => TimerState(
    status: TimerStatus.values.byName(j['status']! as String),
    mode: TimerMode.values.byName(j['mode']! as String),
    skillId: j['skillId'] as String?,
    preset: j['preset'] == null
        ? null
        : TimerPreset.fromJson(j['preset']! as Map<String, Object?>),
    phase: TimerPhase.values.byName(j['phase']! as String),
    phaseStartedAt: _dtN(j['phaseStartedAt']),
    pausedElapsedSeconds: j['pausedElapsedSeconds'] as int?,
    completedWork: [
      for (final r in j['completedWork']! as List<Object?>)
        WorkPhaseRecord.fromJson(r! as Map<String, Object?>),
    ],
    sessionStartedAt: _dtN(j['sessionStartedAt']),
    lastInteractionAt: _dtN(j['lastInteractionAt']),
  );

  static const TimerState idle = TimerState(
    status: TimerStatus.idle,
    mode: TimerMode.pomodoro,
  );

  final TimerStatus status;
  final TimerMode mode;
  final String? skillId;

  /// Null in free mode.
  final TimerPreset? preset;
  final TimerPhase phase;

  /// Running: the phase's effective start (shifted forward by pauses).
  /// Waiting: the instant the previous phase ended.
  final DateTime? phaseStartedAt;

  /// Elapsed seconds frozen at pause; non-null only while paused.
  final int? pausedElapsedSeconds;
  final List<WorkPhaseRecord> completedWork;
  final DateTime? sessionStartedAt;
  final DateTime? lastInteractionAt;

  TimerState _copy({
    TimerStatus? status,
    TimerPhase? phase,
    DateTime? phaseStartedAt,
    int? Function()? pausedElapsedSeconds,
    List<WorkPhaseRecord>? completedWork,
    DateTime? lastInteractionAt,
  }) => TimerState(
    status: status ?? this.status,
    mode: mode,
    skillId: skillId,
    preset: preset,
    phase: phase ?? this.phase,
    phaseStartedAt: phaseStartedAt ?? this.phaseStartedAt,
    pausedElapsedSeconds: pausedElapsedSeconds == null
        ? this.pausedElapsedSeconds
        : pausedElapsedSeconds(),
    completedWork: completedWork ?? this.completedWork,
    sessionStartedAt: sessionStartedAt,
    lastInteractionAt: lastInteractionAt ?? this.lastInteractionAt,
  );

  Map<String, Object?> toJson() => {
    'status': status.name,
    'mode': mode.name,
    'skillId': skillId,
    'preset': preset?.toJson(),
    'phase': phase.name,
    'phaseStartedAt': _isoN(phaseStartedAt),
    'pausedElapsedSeconds': pausedElapsedSeconds,
    'completedWork': [for (final r in completedWork) r.toJson()],
    'sessionStartedAt': _isoN(sessionStartedAt),
    'lastInteractionAt': _isoN(lastInteractionAt),
  };

  @override
  bool operator ==(Object other) =>
      other is TimerState &&
      other.status == status &&
      other.mode == mode &&
      other.skillId == skillId &&
      other.preset == preset &&
      other.phase == phase &&
      other.phaseStartedAt == phaseStartedAt &&
      other.pausedElapsedSeconds == pausedElapsedSeconds &&
      const ListEquality<WorkPhaseRecord>().equals(
        other.completedWork,
        completedWork,
      ) &&
      other.sessionStartedAt == sessionStartedAt &&
      other.lastInteractionAt == lastInteractionAt;

  @override
  int get hashCode => Object.hash(
    status,
    mode,
    skillId,
    preset,
    phase,
    phaseStartedAt,
    pausedElapsedSeconds,
    Object.hashAll(completedWork),
    sessionStartedAt,
    lastInteractionAt,
  );
}

/// A future instant at which the machine changes on its own (for notifications).
class PhaseBoundary {
  const PhaseBoundary({
    required this.at,
    required this.kind,
    this.ending,
    this.next,
  });

  final DateTime at;
  final BoundaryKind kind;

  /// Null for [BoundaryKind.freeModeWarning].
  final TimerPhase? ending;
  final TimerPhase? next;
}

class SessionSummary {
  const SessionSummary({
    required this.skillId,
    required this.startedAt,
    required this.endedAt,
    required this.workSeconds,
    required this.pomodoros,
  });

  final String skillId;
  final DateTime startedAt;
  final DateTime endedAt;
  final int workSeconds;
  final int pomodoros;

  /// Sessions under a minute are not saved (§5.7).
  bool get tooShort => workSeconds < 60;
}

abstract final class TimerMachine {
  static const Duration freeModeWarningAfter = Duration(hours: 4);

  static TimerState start({
    required TimerMode mode,
    required String skillId,
    TimerPreset? preset,
    required DateTime now,
  }) {
    if (mode == TimerMode.pomodoro && preset == null) {
      throw ArgumentError.notNull('preset');
    }
    assert(
      preset == null || preset.validate() == null,
      'Invalid preset: ${preset.validate()}',
    );
    now = now.toUtc();
    return TimerState(
      status: TimerStatus.running,
      mode: mode,
      skillId: skillId,
      preset: mode == TimerMode.pomodoro ? preset : null,
      phaseStartedAt: now,
      sessionStartedAt: now,
      lastInteractionAt: now,
    );
  }

  /// Closes every pomodoro phase that ended at or before [now]. Returns [s]
  /// itself when nothing ended (including when [now] is earlier than [s]'s
  /// instants, e.g. after the clock jumped backwards).
  static TimerState advance(TimerState s, DateTime now) {
    if (s.mode != TimerMode.pomodoro || s.status != TimerStatus.running) {
      return s;
    }
    final preset = s.preset!;
    var state = s;
    while (true) {
      final started = state.phaseStartedAt!;
      final end = started.add(_duration(preset, state.phase));
      if (end.isAfter(now)) return state;

      var work = state.completedWork;
      if (state.phase == TimerPhase.work) {
        work = [
          ...work,
          WorkPhaseRecord(
            start: started,
            end: end,
            seconds: preset.workMinutes * 60,
            full: true,
            // Only an auto-started phase can start after the last interaction:
            // every user action sets lastInteractionAt to the start it sets.
            unattended: started.isAfter(state.lastInteractionAt!),
          ),
        ];
      }
      final next = state.phase == TimerPhase.work
          ? _breakAfter(preset, work.where((r) => r.full).length)
          : TimerPhase.work;
      final auto = next == TimerPhase.work
          ? preset.autoStartWork
          : preset.autoStartBreaks;
      state = state._copy(
        status: auto ? TimerStatus.running : TimerStatus.waiting,
        phase: next,
        phaseStartedAt: end,
        completedWork: work,
      );
      if (!auto) return state;
    }
  }

  /// Records that the user watched the timer at [now] (the Odak screen was
  /// open), so work phases starting before it count as attended.
  static TimerState seen(TimerState s, DateTime now) =>
      s.status == TimerStatus.idle
      ? s
      : s._copy(lastInteractionAt: now.toUtc());

  static TimerState pause(TimerState s, DateTime now) {
    now = now.toUtc();
    final a = advance(s, now);
    if (a.status != TimerStatus.running) return a;
    final elapsed = elapsedInPhase(a, now);
    return a._copy(
      status: TimerStatus.paused,
      pausedElapsedSeconds: () => elapsed,
      lastInteractionAt: now,
    );
  }

  static TimerState resume(TimerState s, DateTime now) {
    now = now.toUtc();
    if (s.status != TimerStatus.paused) return s;
    return s._copy(
      status: TimerStatus.running,
      phaseStartedAt: now.subtract(Duration(seconds: s.pausedElapsedSeconds!)),
      pausedElapsedSeconds: () => null,
      lastInteractionAt: now,
    );
  }

  /// "Sonraki aşamaya geç": starts the waiting phase, or ends the current
  /// phase now (crediting partial work) and starts the next one.
  static TimerState startNextPhase(TimerState s, DateTime now) {
    if (s.mode != TimerMode.pomodoro || s.status == TimerStatus.idle) return s;
    now = now.toUtc();
    final a = advance(s, now);
    if (a.status == TimerStatus.waiting) return _begin(a, a.phase, now);

    var work = a.completedWork;
    if (a.phase == TimerPhase.work) {
      final elapsed = elapsedInPhase(a, now);
      if (elapsed > 0) {
        work = [
          ...work,
          WorkPhaseRecord(
            start: now.subtract(Duration(seconds: elapsed)),
            end: now,
            seconds: elapsed,
            full: false,
            unattended: a.phaseStartedAt!.isAfter(a.lastInteractionAt!),
          ),
        ];
      }
    }
    // Work ended early is never a full round, so a short break follows.
    final next = a.phase == TimerPhase.work
        ? TimerPhase.shortBreak
        : TimerPhase.work;
    return _begin(a._copy(completedWork: work), next, now);
  }

  /// "Molayı atla": during a break (running, paused or waiting to start one)
  /// starts work now. Does nothing during work.
  static TimerState skipPhase(TimerState s, DateTime now) {
    if (s.mode != TimerMode.pomodoro || s.status == TimerStatus.idle) return s;
    now = now.toUtc();
    final a = advance(s, now);
    if (a.phase == TimerPhase.work) return a;
    return _begin(a, TimerPhase.work, now);
  }

  /// Work phases that ran without the user (§5.7 "gözetimsiz devam"), as of
  /// [now]: the closed unattended records plus, if the running work phase
  /// was auto-started after the last interaction, that phase as a partial
  /// (`full: false`) record up to [now].
  static List<WorkPhaseRecord> unattendedPhases(TimerState s, DateTime now) {
    now = now.toUtc();
    final a = advance(s, now);
    final running = _runningUnattended(a, now);
    return [...a.completedWork.where((r) => r.unattended), ?running];
  }

  /// The user's answer to the unattended-phases screen, given at [now].
  /// Advances to [now], keeps the unattended phases whose start is in
  /// [keptStarts] (as attended records) and drops the rest. A dropped running
  /// work phase is discarded and the machine waits to start work again. Counts
  /// as a user interaction, so the same phases are not listed again.
  static TimerState keepUnattended(
    TimerState s,
    Set<DateTime> keptStarts,
    DateTime now,
  ) {
    if (s.status == TimerStatus.idle) return s;
    now = now.toUtc();
    final kept = {for (final d in keptStarts) d.toUtc()};
    final a = advance(s, now);
    final work = [
      for (final r in a.completedWork)
        if (!r.unattended)
          r
        else if (kept.contains(r.start))
          WorkPhaseRecord(
            start: r.start,
            end: r.end,
            seconds: r.seconds,
            full: r.full,
            unattended: false,
          ),
    ];
    final running = _runningUnattended(a, now);
    if (running != null && !kept.contains(running.start)) {
      return a._copy(
        status: TimerStatus.waiting,
        phase: TimerPhase.work,
        phaseStartedAt: now,
        completedWork: work,
        lastInteractionAt: now,
      );
    }
    return a._copy(completedWork: work, lastInteractionAt: now);
  }

  /// The running work phase of an advanced state as a partial unattended
  /// record up to [now], or null when it is attended or has no time yet.
  static WorkPhaseRecord? _runningUnattended(TimerState a, DateTime now) {
    if (a.mode != TimerMode.pomodoro ||
        a.status != TimerStatus.running ||
        a.phase != TimerPhase.work) {
      return null;
    }
    final started = a.phaseStartedAt!;
    if (!started.isAfter(a.lastInteractionAt!)) return null;
    final elapsed = elapsedInPhase(a, now);
    if (elapsed == 0) return null;
    return WorkPhaseRecord(
      start: started,
      end: started.add(Duration(seconds: elapsed)),
      seconds: elapsed,
      full: false,
      unattended: true,
    );
  }

  /// Seconds into the current phase, never negative. In pomodoro mode capped
  /// at the phase length; 0 while idle or waiting.
  static int elapsedInPhase(TimerState s, DateTime now) {
    switch (s.status) {
      case TimerStatus.idle:
      case TimerStatus.waiting:
        return 0;
      case TimerStatus.paused:
        return s.pausedElapsedSeconds!;
      case TimerStatus.running:
        final raw = now.difference(s.phaseStartedAt!).inSeconds;
        final elapsed = raw < 0 ? 0 : raw;
        if (s.mode == TimerMode.free) return elapsed;
        final length = _duration(s.preset!, s.phase).inSeconds;
        return elapsed > length ? length : elapsed;
    }
  }

  /// Seconds left in the current pomodoro phase; null in free mode, while
  /// idle, or while waiting.
  static int? remainingInPhase(TimerState s, DateTime now) {
    if (s.mode == TimerMode.free) return null;
    if (s.status != TimerStatus.running && s.status != TimerStatus.paused) {
      return null;
    }
    return _duration(s.preset!, s.phase).inSeconds - elapsedInPhase(s, now);
  }

  /// The next instants after [now] at which the machine changes on its own,
  /// in order. Pomodoro: phase ends, chained through the auto-start flags up
  /// to and including the first end after which the machine would wait.
  /// Free: the 4-hour warning, if still ahead. Empty unless running.
  static List<PhaseBoundary> upcomingBoundaries(
    TimerState s,
    DateTime now, {
    int count = 8,
  }) {
    final a = advance(s, now);
    if (a.status != TimerStatus.running) return const [];
    if (a.mode == TimerMode.free) {
      // Counted time: phaseStartedAt already shifts forward with pauses.
      final at = a.phaseStartedAt!.add(freeModeWarningAfter);
      return [
        if (at.isAfter(now))
          PhaseBoundary(at: at, kind: BoundaryKind.freeModeWarning),
      ];
    }
    final preset = a.preset!;
    final out = <PhaseBoundary>[];
    var phase = a.phase;
    var end = a.phaseStartedAt!.add(_duration(preset, phase));
    var fullCount = a.completedWork.where((r) => r.full).length;
    while (out.length < count) {
      if (phase == TimerPhase.work) fullCount++;
      final next = phase == TimerPhase.work
          ? _breakAfter(preset, fullCount)
          : TimerPhase.work;
      out.add(
        PhaseBoundary(
          at: end,
          kind: BoundaryKind.phaseEnd,
          ending: phase,
          next: next,
        ),
      );
      final auto = next == TimerPhase.work
          ? preset.autoStartWork
          : preset.autoStartBreaks;
      if (!auto) break;
      phase = next;
      end = end.add(_duration(preset, phase));
    }
    return out;
  }

  /// Summary for the "Oturumu bitir" sheet. Credits closed work records plus
  /// the current work phase's elapsed time (none while waiting); breaks never
  /// count. [trimToSeconds] caps the work time.
  static SessionSummary finish(
    TimerState s,
    DateTime now, {
    int? trimToSeconds,
  }) {
    if (s.status == TimerStatus.idle) {
      throw StateError('No timer session to finish');
    }
    now = now.toUtc();
    final a = advance(s, now);
    var work = a.completedWork.fold<int>(0, (sum, r) => sum + r.seconds);
    if (a.phase == TimerPhase.work && a.status != TimerStatus.waiting) {
      work += elapsedInPhase(a, now);
    }
    if (trimToSeconds != null && work > trimToSeconds) work = trimToSeconds;
    return SessionSummary(
      skillId: a.skillId!,
      startedAt: a.sessionStartedAt!,
      endedAt: now,
      workSeconds: work,
      pomodoros: a.completedWork.where((r) => r.full).length,
    );
  }

  static TimerState _begin(TimerState s, TimerPhase phase, DateTime now) =>
      s._copy(
        status: TimerStatus.running,
        phase: phase,
        phaseStartedAt: now,
        pausedElapsedSeconds: () => null,
        lastInteractionAt: now,
      );

  static Duration _duration(TimerPreset p, TimerPhase phase) => Duration(
    minutes: switch (phase) {
      TimerPhase.work => p.workMinutes,
      TimerPhase.shortBreak => p.shortBreakMinutes,
      TimerPhase.longBreak => p.longBreakMinutes,
    },
  );

  /// The break after a full work phase: long after every
  /// `roundsBeforeLong`-th full work phase, short otherwise.
  static TimerPhase _breakAfter(TimerPreset p, int fullCount) =>
      fullCount > 0 && fullCount % p.roundsBeforeLong == 0
      ? TimerPhase.longBreak
      : TimerPhase.shortBreak;
}
