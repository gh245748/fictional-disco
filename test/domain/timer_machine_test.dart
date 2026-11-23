import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mesk/domain/models.dart';
import 'package:mesk/domain/timer_machine.dart';

final t0 = DateTime.utc(2026, 11, 21, 9);
DateTime m(int n) => t0.add(Duration(minutes: n));

TimerPreset preset({bool autoBreaks = true, bool autoWork = false}) =>
    TimerPreset('t', 't', 25, 5, 15, 4, autoBreaks, autoWork, false);

TimerState pomodoro({bool autoBreaks = true, bool autoWork = false}) =>
    TimerMachine.start(
      mode: TimerMode.pomodoro,
      skillId: 's1',
      preset: preset(autoBreaks: autoBreaks, autoWork: autoWork),
      now: t0,
    );

void main() {
  test('idle constant has no skill', () {
    expect(TimerState.idle.status, TimerStatus.idle);
    expect(TimerState.idle.skillId, isNull);
    expect(TimerState.idle.completedWork, isEmpty);
  });

  test('start sets the session and interaction instants', () {
    final s = pomodoro();
    expect(s.status, TimerStatus.running);
    expect(s.mode, TimerMode.pomodoro);
    expect(s.phase, TimerPhase.work);
    expect(s.phaseStartedAt, t0);
    expect(s.sessionStartedAt, t0);
    expect(s.lastInteractionAt, t0);
    expect(TimerMachine.remainingInPhase(s, m(10)), 15 * 60);
    expect(TimerMachine.elapsedInPhase(s, m(10)), 600);
  });

  test('work → short break with auto breaks', () {
    final s = TimerMachine.advance(pomodoro(), m(25));
    expect(s.phase, TimerPhase.shortBreak);
    expect(s.status, TimerStatus.running);
    expect(s.phaseStartedAt, m(25));
    expect(s.completedWork.single.seconds, 1500);
    expect(s.completedWork.single.full, isTrue);
    expect(s.completedWork.single.unattended, isFalse);
    expect(s.completedWork.single.start, t0);
    expect(s.completedWork.single.end, m(25));
  });

  test('waiting when auto breaks off', () {
    final s = TimerMachine.advance(pomodoro(autoBreaks: false), m(40));
    expect(s.status, TimerStatus.waiting);
    expect(s.phase, TimerPhase.shortBreak);
    expect(s.completedWork.single.seconds, 1500);
    expect(TimerMachine.elapsedInPhase(s, m(40)), 0);
    expect(TimerMachine.upcomingBoundaries(s, m(40)), isEmpty);
    final sum = TimerMachine.finish(s, m(40));
    expect(sum.workSeconds, 1500);
    expect(sum.pomodoros, 1);
  });

  test('auto work off waits after break', () {
    final s = TimerMachine.advance(pomodoro(), m(31));
    expect(s.status, TimerStatus.waiting);
    expect(s.phase, TimerPhase.work);
    expect(s.completedWork, hasLength(1));

    final next = TimerMachine.startNextPhase(s, m(33));
    expect(next.status, TimerStatus.running);
    expect(next.phase, TimerPhase.work);
    expect(next.phaseStartedAt, m(33));
    expect(next.lastInteractionAt, m(33));
  });

  test('long break after 4th work', () {
    final s = TimerMachine.advance(pomodoro(autoWork: true), m(115));
    expect(s.phase, TimerPhase.longBreak);
    expect(s.status, TimerStatus.running);
    expect(s.phaseStartedAt, m(115));
    expect(s.completedWork, hasLength(4));
    expect(TimerMachine.remainingInPhase(s, m(115)), 15 * 60);
    final after = TimerMachine.advance(s, m(130));
    expect(after.phase, TimerPhase.work);
    expect(after.phaseStartedAt, m(130));
  });

  test('pause shifts the end', () {
    var s = TimerMachine.pause(pomodoro(), m(10));
    expect(s.status, TimerStatus.paused);
    expect(s.lastInteractionAt, m(10));
    expect(TimerMachine.elapsedInPhase(s, m(15)), 600);
    expect(TimerMachine.upcomingBoundaries(s, m(15)), isEmpty);
    // While paused nothing ends.
    expect(TimerMachine.advance(s, m(60)), s);

    s = TimerMachine.resume(s, m(20));
    expect(s.status, TimerStatus.running);
    expect(s.lastInteractionAt, m(20));
    expect(TimerMachine.upcomingBoundaries(s, m(20)).first.at, m(35));
    expect(TimerMachine.advance(s, m(34)).phase, TimerPhase.work);
    final ended = TimerMachine.advance(s, m(35));
    expect(ended.phase, TimerPhase.shortBreak);
    expect(ended.phaseStartedAt, m(35));
    expect(ended.completedWork.single.seconds, 1500);
  });

  test('skip break', () {
    final inBreak = TimerMachine.advance(pomodoro(), m(27));
    expect(inBreak.phase, TimerPhase.shortBreak);
    final s = TimerMachine.skipPhase(inBreak, m(27));
    expect(s.phase, TimerPhase.work);
    expect(s.status, TimerStatus.running);
    expect(s.phaseStartedAt, m(27));
    expect(s.lastInteractionAt, m(27));
    expect(s.completedWork, hasLength(1));
  });

  test('skip break while waiting for the break', () {
    final waiting = TimerMachine.advance(pomodoro(autoBreaks: false), m(26));
    final s = TimerMachine.skipPhase(waiting, m(26));
    expect(s.phase, TimerPhase.work);
    expect(s.status, TimerStatus.running);
    expect(s.phaseStartedAt, m(26));
  });

  test('skipPhase during work changes nothing', () {
    final s = pomodoro();
    expect(TimerMachine.skipPhase(s, m(5)), s);
  });

  test('startNextPhase during work credits the partial work', () {
    final s = TimerMachine.startNextPhase(pomodoro(), m(10));
    expect(s.phase, TimerPhase.shortBreak);
    expect(s.status, TimerStatus.running);
    expect(s.phaseStartedAt, m(10));
    expect(s.completedWork.single.seconds, 600);
    expect(s.completedWork.single.full, isFalse);
    expect(TimerMachine.finish(s, m(12)).pomodoros, 0);
  });

  test('work ended early after a long break gets a short break', () {
    // 4 full rounds, long break 115–130, work 5 from 130 ended early at 140.
    final s = TimerMachine.advance(pomodoro(autoWork: true), m(135));
    final next = TimerMachine.startNextPhase(s, m(140));
    expect(next.phase, TimerPhase.shortBreak);
    expect(next.completedWork.last.full, isFalse);
  });

  test('unattended auto-started work phases are listed and can be dropped', () {
    var s = TimerMachine.advance(pomodoro(autoWork: true), m(90));
    expect(s.lastInteractionAt, t0);
    expect(TimerMachine.unattendedPhases(s).map((r) => r.start), [
      m(30),
      m(60),
    ]);
    s = TimerMachine.keepUnattended(s, {m(30)});
    expect(TimerMachine.unattendedPhases(s).map((r) => r.start), [m(30)]);
    final sum = TimerMachine.finish(s, m(90));
    expect(sum.workSeconds, 3000);
    expect(sum.pomodoros, 2);
  });

  test('free mode', () {
    final s = TimerMachine.start(mode: TimerMode.free, skillId: 's1', now: t0);
    expect(TimerMachine.remainingInPhase(s, m(50)), isNull);
    expect(TimerMachine.advance(s, m(50)), s);
    final sum = TimerMachine.finish(s, m(50));
    expect(sum.skillId, 's1');
    expect(sum.startedAt, t0);
    expect(sum.endedAt, m(50));
    expect(sum.workSeconds, 3000);
    expect(sum.pomodoros, 0);
    expect(sum.tooShort, isFalse);

    final b = TimerMachine.upcomingBoundaries(s, m(50));
    expect(b, hasLength(1));
    expect(b.single.kind, BoundaryKind.freeModeWarning);
    expect(b.single.at, t0.add(TimerMachine.freeModeWarningAfter));
    expect(b.single.ending, isNull);
    expect(b.single.next, isNull);
    expect(TimerMachine.upcomingBoundaries(s, m(241)), isEmpty);
  });

  test('free mode pause freezes elapsed', () {
    var s = TimerMachine.start(mode: TimerMode.free, skillId: 's1', now: t0);
    s = TimerMachine.pause(s, m(10));
    expect(TimerMachine.elapsedInPhase(s, m(50)), 600);
    expect(TimerMachine.upcomingBoundaries(s, m(50)), isEmpty);
    s = TimerMachine.resume(s, m(50));
    expect(TimerMachine.finish(s, m(60)).workSeconds, 1200);
  });

  test('too short', () {
    final s = TimerMachine.start(mode: TimerMode.free, skillId: 's1', now: t0);
    final sum = TimerMachine.finish(s, t0.add(const Duration(seconds: 40)));
    expect(sum.workSeconds, 40);
    expect(sum.tooShort, isTrue);
  });

  test('trim', () {
    final s = TimerMachine.start(mode: TimerMode.free, skillId: 's1', now: t0);
    expect(
      TimerMachine.finish(s, m(50), trimToSeconds: 1200).workSeconds,
      1200,
    );
    expect(TimerMachine.finish(s, m(10), trimToSeconds: 1200).workSeconds, 600);
  });

  test('finish counts the running work phase', () {
    final sum = TimerMachine.finish(pomodoro(), m(40));
    // Work 1 (1500) + break 25–30 + work 2 waiting from m(30): only 1500.
    expect(sum.workSeconds, 1500);
    final running = TimerMachine.finish(pomodoro(autoWork: true), m(40));
    expect(running.workSeconds, 1500 + 600);
    expect(running.pomodoros, 1);
  });

  test('clock jumps backwards', () {
    final s = pomodoro();
    final earlier = t0.subtract(const Duration(minutes: 5));
    expect(TimerMachine.elapsedInPhase(s, earlier), 0);
    expect(TimerMachine.remainingInPhase(s, earlier), 1500);
    expect(identical(TimerMachine.advance(s, earlier), s), isTrue);

    final later = TimerMachine.advance(s, m(27));
    expect(identical(TimerMachine.advance(later, m(10)), later), isTrue);
  });

  test('json round-trip', () {
    var s = TimerMachine.advance(pomodoro(autoWork: true), m(90));
    s = TimerMachine.pause(s, m(95));
    final back = TimerState.fromJson(
      jsonDecode(jsonEncode(s.toJson())) as Map<String, Object?>,
    );
    expect(back, s);
    expect(back.completedWork, hasLength(3));

    final free = TimerMachine.start(
      mode: TimerMode.free,
      skillId: 's2',
      now: t0,
    );
    expect(TimerState.fromJson(free.toJson()), free);
    expect(TimerState.fromJson(TimerState.idle.toJson()), TimerState.idle);
  });

  test('boundaries', () {
    final s = pomodoro();
    final b = TimerMachine.upcomingBoundaries(s, m(1));
    expect(b.map((x) => x.at), [m(25), m(30)]);
    expect(b.map((x) => x.kind), everyElement(BoundaryKind.phaseEnd));
    expect(b[0].ending, TimerPhase.work);
    expect(b[0].next, TimerPhase.shortBreak);
    expect(b[1].ending, TimerPhase.shortBreak);
    expect(b[1].next, TimerPhase.work);

    final auto = TimerMachine.upcomingBoundaries(
      pomodoro(autoWork: true),
      m(1),
      count: 8,
    );
    expect(auto.map((x) => x.at), [
      m(25),
      m(30),
      m(55),
      m(60),
      m(85),
      m(90),
      m(115),
      m(130),
    ]);
    expect(auto[6].next, TimerPhase.longBreak);

    final noAutoBreaks = TimerMachine.upcomingBoundaries(
      pomodoro(autoBreaks: false),
      m(1),
    );
    expect(noAutoBreaks.map((x) => x.at), [m(25)]);

    // Not yet advanced past a boundary: only future boundaries are returned.
    expect(TimerMachine.upcomingBoundaries(s, m(26)).map((x) => x.at), [m(30)]);

    final free = TimerMachine.start(
      mode: TimerMode.free,
      skillId: 's',
      now: t0,
    );
    expect(TimerMachine.upcomingBoundaries(free, m(1)).map((x) => x.kind), [
      BoundaryKind.freeModeWarning,
    ]);
  });
}
