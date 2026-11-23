import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../domain/day.dart';
import '../../domain/habits.dart';
import '../../domain/models.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/progress_ring.dart';
import '../celebrations/celebration_host.dart';
import 'habits_controller.dart';

/// The status line of a habit row, e.g. "Süreli · 20 / 30 dk".
String habitSubtitle(TodayHabit t) {
  final h = t.habit;
  final base = h.kind == HabitKind.timed
      ? 'Süreli · ${(t.progressSeconds ?? 0) ~/ 60} / ${h.targetMinutes ?? 0} dk'
      : 'Basit · ${t.done ? 'tamamlandı' : 'bekliyor'}';
  final week = t.weekTarget == null
      ? ''
      : ' · bu hafta ${t.weekDone} / ${t.weekTarget}';
  return '$base$week';
}

/// "12 gün", or "3 hafta" for times-per-week habits; empty without a streak.
String habitStreakLabel(TodayHabit t) {
  if (t.streak <= 0) return '';
  final unit = t.habit.schedule is TimesPerWeekSchedule ? 'hafta' : 'gün';
  return '${t.streak} $unit';
}

/// One habit of today. Simple habits get a check circle; timed habits a
/// progress ring that only reflects the tracked time. The text opens the
/// editor.
class HabitRow extends ConsumerWidget {
  const HabitRow(this.today, {super.key});

  final TodayHabit today;

  static const double _control = 44;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habit = today.habit;
    final timed = habit.kind == HabitKind.timed;
    final streak = habitStreakLabel(today);
    return Row(
      children: [
        timed ? _ring() : _check(ref),
        Expanded(
          child: InkWell(
            key: ValueKey('habit-open-${habit.id}'),
            onTap: () => context.push('/aliskanlik/${habit.id}'),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _control),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(habit.name, style: MeskType.body15),
                    Text(habitSubtitle(today), style: MeskType.caption),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (streak.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              streak,
              style: MeskType.body14.copyWith(color: MeskColors.accent),
            ),
          ),
      ],
    );
  }

  Widget _ring() {
    final habit = today.habit;
    final target = (habit.targetMinutes ?? 0) * 60;
    final ratio = target <= 0 ? 0.0 : (today.progressSeconds ?? 0) / target;
    return Semantics(
      label: today.done
          ? '${habit.name}, hedef tamamlandı'
          : '${habit.name}, süre kayıtlarından ilerliyor',
      child: SizedBox.square(
        dimension: _control,
        child: Center(
          child: ProgressRing(
            key: ValueKey('habit-ring-${habit.id}'),
            value: ratio,
            size: 28,
            strokeWidth: 3,
            color: MeskColors.accent,
            child: today.done
                ? const Icon(Icons.check, size: 14, color: MeskColors.accent)
                : null,
          ),
        ),
      ),
    );
  }

  Widget _check(WidgetRef ref) {
    final habit = today.habit;
    return Semantics(
      button: true,
      label: today.done
          ? 'İşareti geri al: ${habit.name}'
          : 'Tamamlandı olarak işaretle: ${habit.name}',
      child: InkResponse(
        key: ValueKey('habit-check-${habit.id}'),
        radius: 24,
        onTap: () =>
            toggleHabitDay(ref, habit.id, ref.read(todayProvider).value),
        child: SizedBox.square(
          dimension: _control,
          child: Center(child: CheckCircle(done: today.done)),
        ),
      ),
    );
  }
}

/// Toggles a simple habit on [day] and queues the celebrations. Failures
/// show a snack bar through [onError] when given.
Future<void> toggleHabitDay(
  WidgetRef ref,
  String habitId,
  LocalDay? day,
) async {
  if (day == null) return;
  await runAndCelebrate(
    ref,
    () => ref.read(habitsControllerProvider).toggle(habitId, day),
  );
}

/// A 26 px circle, filled with a check when [done].
class CheckCircle extends StatelessWidget {
  const CheckCircle({super.key, required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) => Container(
    width: 26,
    height: 26,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: done ? MeskColors.accent : null,
      border: Border.all(
        color: done ? MeskColors.accent : MeskColors.faint,
        width: 1.5,
      ),
    ),
    child: done
        ? const Icon(Icons.check, size: 16, color: MeskColors.bg)
        : null,
  );
}
