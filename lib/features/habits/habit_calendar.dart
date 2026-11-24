import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../domain/day.dart';
import '../../domain/habits.dart';
import '../../domain/models.dart';
import '../../ui/theme.dart';
import 'habit_row.dart';

const _weekdayNames = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

/// The accent opacity of a day completed to [ratio] (0..1): none, then three
/// steps, then solid.
double heatOpacity(double ratio) {
  if (ratio <= 0) return 0;
  if (ratio <= 0.34) return 0.3;
  if (ratio <= 0.67) return 0.5;
  if (ratio < 1) return 0.7;
  return 1;
}

LocalDay _utcDay(DateTime t) {
  final u = t.toUtc();
  return LocalDay(u.year, u.month, u.day);
}

/// How far [h] got on [d] (0..1; timed habits partly), or null when the habit
/// is not due: before it existed, after it was archived, or on a day outside
/// its weekdays.
double? habitDayRatio(Habit h, LocalDay d, HabitDayData data) {
  if (d.compareTo(habitCreatedDay(h)) < 0) return null;
  final archived = h.archivedAt;
  if (archived != null && d.compareTo(_utcDay(archived)) > 0) return null;
  if (!isScheduledOn(h, d)) return null;
  if (h.kind == HabitKind.timed) {
    final target = (h.targetMinutes ?? 0) * 60;
    if (target <= 0) return 0;
    return (timedSecondsOn(h, d, data) / target).clamp(0.0, 1.0);
  }
  return isCompletedOn(h, d, data) ? 1 : 0;
}

/// The mean ratio of every habit due on [d]. A times-per-week habit counts
/// only on the days it was done, since it has no fixed days to miss.
double? overallDayRatio(Iterable<Habit> habits, LocalDay d, HabitDayData data) {
  var sum = 0.0;
  var n = 0;
  for (final h in habits) {
    final r = habitDayRatio(h, d, data);
    if (r == null) continue;
    if (h.schedule is TimesPerWeekSchedule && r == 0) continue;
    sum += r;
    n++;
  }
  return n == 0 ? null : sum / n;
}

/// A month heat map, Monday first. With a [habit] it shows that habit and
/// lets simple habits be checked on past days; without one it shows every
/// active habit together.
class HabitCalendar extends ConsumerStatefulWidget {
  const HabitCalendar({super.key, this.habit});

  final Habit? habit;

  @override
  ConsumerState<HabitCalendar> createState() => _HabitCalendarState();
}

class _HabitCalendarState extends ConsumerState<HabitCalendar> {
  /// First day of the shown month; null until today is known.
  LocalDay? _month;

  void _shift(LocalDay current, int months) {
    final index = current.year * 12 + current.month - 1 + months;
    setState(() => _month = LocalDay(index ~/ 12, index % 12 + 1, 1));
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider).value;
    final data = ref.watch(habitDayDataProvider).value;
    final all = ref.watch(habitsProvider).value;
    if (today == null || data == null || all == null) {
      return const SizedBox(height: 280);
    }
    final month = _month ?? LocalDay(today.year, today.month, 1);
    final habit = widget.habit;
    final active = [
      for (final h in all)
        if (h.archivedAt == null) h,
    ];
    final first = month;
    final daysInMonth = DateTime.utc(month.year, month.month + 1, 0).day;
    final lead = first.weekday - 1;
    final rows = (lead + daysInMonth + 6) ~/ 7;
    final title = DateFormat('MMMM y', 'tr').format(first.toDateTime());

    Widget cell(int slot) {
      final dayNo = slot - lead + 1;
      if (dayNo < 1 || dayNo > daysInMonth) return const SizedBox.shrink();
      final day = LocalDay(month.year, month.month, dayNo);
      final ratio = habit == null
          ? overallDayRatio(active, day, data)
          : habitDayRatio(habit, day, data);
      final future = day.compareTo(today) > 0;
      final canToggle =
          habit != null &&
          habit.kind == HabitKind.simple &&
          !future &&
          ratio != null;
      return _DayCell(
        day: day,
        ratio: future ? null : ratio,
        isToday: day == today,
        future: future,
        onTap: canToggle ? () => toggleHabitDay(ref, habit.id, day) : null,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Önceki ay',
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _shift(month, -1),
            ),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: MeskType.sectionTitle,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Sonraki ay',
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _shift(month, 1),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final name in _weekdayNames)
              Expanded(
                child: Center(child: Text(name, style: MeskType.caption)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++) Expanded(child: cell(r * 7 + c)),
            ],
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.ratio,
    required this.isToday,
    required this.future,
    required this.onTap,
  });

  final LocalDay day;
  final double? ratio;
  final bool isToday;
  final bool future;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final opacity = ratio == null ? 0.0 : heatOpacity(ratio!);
    final dark = opacity >= 0.7;
    final textColor = dark
        ? MeskColors.bg
        : (future || ratio == null ? MeskColors.faint : MeskColors.text);
    final status = future
        ? ''
        : ratio == null
        ? ''
        : ratio! >= 1
        ? ', tamamlandı'
        : ratio! > 0
        ? ', kısmen'
        : ', yapılmadı';
    final box = Padding(
      padding: const EdgeInsets.all(2),
      child: AspectRatio(
        aspectRatio: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: MeskColors.accent.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isToday ? MeskColors.accentHover : MeskColors.divider,
              width: isToday ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Text(
              '${day.day}',
              style: MeskType.body14.copyWith(
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
    return Semantics(
      key: ValueKey('cal-day-${day.toIso()}'),
      button: onTap != null,
      label:
          '${day.day} ${DateFormat('MMMM', 'tr').format(day.toDateTime())}'
          '$status',
      excludeSemantics: true,
      onTap: onTap,
      child: onTap == null
          ? box
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: box,
            ),
    );
  }
}
