import 'package:flutter_test/flutter_test.dart';
import 'package:mesk/domain/day.dart';
import 'package:mesk/domain/goals.dart';
import 'package:mesk/domain/models.dart';

Goal goal({required int target, LocalDay? deadline}) => Goal(
  id: 'g1',
  skillId: 's1',
  targetSeconds: target,
  deadline: deadline,
  createdAt: DateTime.utc(2026, 11, 1),
);

void main() {
  const today = LocalDay(2026, 11, 21);

  test('mockup goal: 100 h by 31 Mart', () {
    final g = goal(target: 100 * 3600, deadline: const LocalDay(2027, 3, 31));
    final s = goalStatus(
      g,
      realSeconds: 97560,
      paceSecondsPerDay: 1800,
      today: today,
    ); // 27,1 h
    expect(s.progress, closeTo(0.271, 1e-3));
    expect(s.remainingSeconds, 262440);
    expect(s.daysLeft, 131);
    expect(habitMinutesFor(s), 34);
    expect(s.projectedDay, today.addDays(146));
  });

  test('pace window is 28 days or since first tracked day', () {
    final byDay = {for (var i = 0; i < 28; i++) today.addDays(-i): 1800};
    expect(paceSecondsPerDay(byDay, today, today.addDays(-60)), 1800);
    expect(paceSecondsPerDay({today: 3600}, today, today.addDays(-9)), 360);
  });

  test('pace is 0 without a first tracked day', () {
    expect(paceSecondsPerDay({today: 3600}, today, null), 0);
  });

  test('pace ignores days outside the window and floors', () {
    final byDay = {today: 100, today.addDays(-30): 99999};
    expect(paceSecondsPerDay(byDay, today, today.addDays(-40)), 100 ~/ 28);
  });

  test('no pace, completed, expired', () {
    final g = goal(target: 3600, deadline: today.addDays(-1));
    expect(
      goalStatus(
        g,
        realSeconds: 0,
        paceSecondsPerDay: 0,
        today: today,
      ).projectedDay,
      isNull,
    );
    expect(
      goalStatus(g, realSeconds: 0, paceSecondsPerDay: 0, today: today).expired,
      isTrue,
    );
    final done = goalStatus(
      g,
      realSeconds: 4000,
      paceSecondsPerDay: 0,
      today: today,
    );
    expect(
      (done.completed, done.remainingSeconds, done.expired),
      (true, 0, false),
    );
    expect(done.progress, 1.0);
    expect(done.requiredDailySeconds, isNull);
    expect(done.projectedDay, isNull);
  });

  test('goal without deadline has no required pace', () {
    final s = goalStatus(
      goal(target: 3600),
      realSeconds: 600,
      paceSecondsPerDay: 300,
      today: today,
    );
    expect(s.daysLeft, isNull);
    expect(s.requiredDailySeconds, isNull);
    expect(s.expired, isFalse);
    expect(s.projectedDay, today.addDays(10));
    expect(() => habitMinutesFor(s), throwsStateError);
  });
}
