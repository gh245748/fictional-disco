import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../domain/day.dart';
import '../../domain/format.dart';
import '../../domain/models.dart';
import '../theme.dart';

/// Tracked seconds per Monday-start week for the [weeks] weeks up to and
/// including the week of [today], oldest first. Prior experience is left out
/// (it is not time spent in these weeks); every other entry counts in the
/// week of the day it started, honouring [dayStartHour].
Map<LocalDay, int> lastWeeksTrackedSeconds(
  Iterable<TimeEntry> entries,
  LocalDay today,
  int dayStartHour, {
  int weeks = 12,
}) {
  final last = today.weekStart;
  final first = last.addDays(-7 * (weeks - 1));
  final out = {for (var i = 0; i < weeks; i++) first.addDays(7 * i): 0};
  for (final e in entries) {
    if (e.isPrior) continue;
    final week = dayOfInstant(
      e.startedAt,
      e.offsetMinutes,
      dayStartHour,
    ).weekStart;
    final seconds = out[week];
    if (seconds != null) out[week] = seconds + e.seconds;
  }
  return out;
}

/// Bars of tracked time per week, oldest on the left. Build the data with
/// [lastWeeksTrackedSeconds].
class WeeklyChart extends StatelessWidget {
  const WeeklyChart(
    this.secondsByWeekStart, {
    super.key,
    this.color = MeskColors.accent,
  });

  final Map<LocalDay, int> secondsByWeekStart;
  final Color color;

  static const double _barsHeight = 88;

  @override
  Widget build(BuildContext context) {
    final weeks = secondsByWeekStart.keys.toList()..sort();
    if (weeks.isEmpty) return const SizedBox.shrink();
    final values = [for (final w in weeks) secondsByWeekStart[w]!];
    final most = values.fold(0, math.max);
    final total = values.fold(0, (a, b) => a + b);
    return Semantics(
      label:
          'Son ${weeks.length} hafta: toplam ${formatDuration(total)}, '
          'en çok ${formatDuration(most)}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Text(
            most == 0
                ? 'Bu haftalarda kayıt yok'
                : 'En çok ${formatHours(most)}',
            style: MeskType.caption,
          ),
          SizedBox(
            height: _barsHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              spacing: 6,
              children: [
                for (final v in values)
                  Expanded(
                    child: Container(
                      height: v == 0
                          ? 2
                          : math.max(3, _barsHeight * v / most).toDouble(),
                      decoration: BoxDecoration(
                        color: v == 0 ? MeskColors.track : color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Row(
            children: [
              Text(
                formatDayMonth(weeks.first.toDateTime()),
                style: MeskType.caption,
              ),
              const Spacer(),
              Text(
                formatDayMonth(weeks.last.toDateTime()),
                style: MeskType.caption,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
