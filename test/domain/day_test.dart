import 'package:flutter_test/flutter_test.dart';
import 'package:mesk/domain/day.dart';

void main() {
  test('day of instant with offset and day start hour', () {
    final utc = DateTime.utc(2026, 11, 21, 21, 30); // 00:30 next day in UTC+3
    expect(dayOfInstant(utc, 180, 0), const LocalDay(2026, 11, 22));
    expect(dayOfInstant(utc, 180, 4), const LocalDay(2026, 11, 21));
    expect(dayOfInstant(utc, -300, 0), const LocalDay(2026, 11, 21));
  });

  test('week math', () {
    expect(
      const LocalDay(2026, 11, 22).weekStart,
      const LocalDay(2026, 11, 16),
    );
    expect(
      const LocalDay(2026, 11, 30).addDays(1),
      const LocalDay(2026, 12, 1),
    );
    expect(
      const LocalDay(2026, 11, 21).daysUntil(const LocalDay(2027, 3, 31)),
      130,
    );
  });

  test('parse, iso, weekday, equality, ordering', () {
    final d = LocalDay.parse('2026-11-21');
    expect(d, const LocalDay(2026, 11, 21));
    expect(d.hashCode, const LocalDay(2026, 11, 21).hashCode);
    expect(d.toIso(), '2026-11-21');
    expect(const LocalDay(2026, 1, 5).toIso(), '2026-01-05');
    expect(d.weekday, DateTime.saturday);
    expect(
      const LocalDay(2026, 11, 16).weekStart,
      const LocalDay(2026, 11, 16),
    );
    expect(d.toDateTime(), DateTime(2026, 11, 21));
    expect(d.compareTo(d.addDays(1)), lessThan(0));
    expect(d.addDays(-21), const LocalDay(2026, 10, 31));
  });

  test('clocks', () {
    final c = FixedClock(DateTime.utc(2026, 11, 21, 21, 30));
    expect(c.offsetMinutesAt(c.nowUtc()), 180);
    expect(todayOf(c, 0), const LocalDay(2026, 11, 22));
    c.advance(const Duration(hours: 24));
    expect(c.nowUtc(), DateTime.utc(2026, 11, 22, 21, 30));
    c.offsetMinutes = -300;
    expect(todayOf(c, 0), const LocalDay(2026, 11, 22));
    expect(SystemClock().nowUtc().isUtc, isTrue);
  });
}
