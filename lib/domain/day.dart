/// A calendar day in the user's local time, independent of DST.
class LocalDay implements Comparable<LocalDay> {
  const LocalDay(this.year, this.month, this.day);

  factory LocalDay.parse(String iso) {
    final p = iso.split('-');
    if (p.length != 3) throw FormatException('Invalid day', iso);
    return LocalDay(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  final int year;
  final int month;
  final int day;

  String toIso() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  DateTime get _utc => DateTime.utc(year, month, day);

  static LocalDay _fromUtc(DateTime d) => LocalDay(d.year, d.month, d.day);

  LocalDay addDays(int n) => _fromUtc(_utc.add(Duration(days: n)));

  /// Whole days from this day to [other] (negative if earlier).
  int daysUntil(LocalDay other) => other._utc.difference(_utc).inDays;

  /// 1 = Monday ... 7 = Sunday.
  int get weekday => _utc.weekday;

  LocalDay get weekStart => addDays(1 - weekday);

  /// Local midnight of this day.
  DateTime toDateTime() => DateTime(year, month, day);

  @override
  int compareTo(LocalDay other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is LocalDay &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIso();
}

/// The local day an instant belongs to, where the day starts at
/// [dayStartHour] local time.
LocalDay dayOfInstant(DateTime utc, int offsetMinutes, int dayStartHour) {
  final shifted = utc.toUtc().add(
    Duration(minutes: offsetMinutes - dayStartHour * 60),
  );
  return LocalDay(shifted.year, shifted.month, shifted.day);
}

abstract class Clock {
  DateTime nowUtc();
  int offsetMinutesAt(DateTime utc);
}

class SystemClock implements Clock {
  @override
  DateTime nowUtc() => DateTime.now().toUtc();

  @override
  int offsetMinutesAt(DateTime utc) => utc.toLocal().timeZoneOffset.inMinutes;
}

class FixedClock implements Clock {
  FixedClock(this.utc, {this.offsetMinutes = 180});

  DateTime utc;
  int offsetMinutes;

  void advance(Duration d) => utc = utc.add(d);

  @override
  DateTime nowUtc() => utc;

  @override
  int offsetMinutesAt(DateTime utc) => offsetMinutes;
}

LocalDay todayOf(Clock clock, int dayStartHour) {
  final now = clock.nowUtc();
  return dayOfInstant(now, clock.offsetMinutesAt(now), dayStartHour);
}
