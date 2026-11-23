import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../app/views.dart';
import '../../domain/day.dart';
import '../../domain/format.dart';
import '../../domain/goals.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/buttons.dart';
import '../../ui/widgets/mesk_card.dart';
import '../../ui/widgets/progress_bar.dart';
import '../celebrations/celebration_host.dart';
import 'goals_controller.dart';

/// "Hedef 100 sa · %27".
String goalHeadline(SkillView view) {
  final goal = view.activeGoal!;
  return 'Hedef ${formatHours(goal.targetSeconds)} · '
      '${formatPercent(view.goal!.progress)}';
}

/// "31 Mart için günde 34 dk"; null when the goal has no deadline or has
/// expired.
String? goalDeadlineLine(SkillView view) {
  final status = view.goal!;
  final deadline = view.activeGoal!.deadline;
  if (status.expired ||
      deadline == null ||
      status.requiredDailySeconds == null) {
    return null;
  }
  return '${formatDayMonth(deadline.toDateTime())} için günde '
      '${habitMinutesFor(status)} dk';
}

/// The one-line goal summary of a skill row on Today: the card's headline and
/// deadline pace, e.g. "Hedef 100 sa · %27 · 31 Mart için günde 34 dk".
/// Shows nothing when the skill has no active goal.
class GoalLine extends StatelessWidget {
  const GoalLine(this.view, {super.key});

  final SkillView view;

  @override
  Widget build(BuildContext context) {
    if (view.activeGoal == null || view.goal == null) {
      return const SizedBox.shrink();
    }
    final text = [
      goalHeadline(view),
      if (view.goal!.expired) 'Süre doldu' else ?goalDeadlineLine(view),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        spacing: 6,
        children: [
          const Icon(Icons.adjust, size: 13, color: MeskColors.accent),
          Expanded(
            child: Text(
              text,
              style: MeskType.caption.copyWith(color: MeskColors.text),
            ),
          ),
        ],
      ),
    );
  }
}

/// The active goal of a skill (§5.10): target and progress, the daily time
/// the deadline needs, the date reached at the current pace, and the
/// actions that fit. Shows nothing when the skill has no active goal.
/// Tapping the card opens the goal editor.
class GoalCard extends ConsumerStatefulWidget {
  const GoalCard(this.view, {super.key});

  final SkillView view;

  @override
  ConsumerState<GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends ConsumerState<GoalCard> {
  /// True while a habit is being created, so a double tap adds only one.
  bool _converting = false;

  SkillView get view => widget.view;

  @override
  Widget build(BuildContext context) {
    final goal = view.activeGoal;
    final status = view.goal;
    if (goal == null || status == null) return const SizedBox.shrink();
    final deadline = goal.deadline;
    final projected = status.projectedDay;
    return MeskCard(
      onTap: () => context.push('/hedef/${view.skill.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Text(goalHeadline(view), style: MeskType.body14),
          MeskProgressBar(value: status.progress, color: MeskColors.accent),
          if (status.expired)
            const Text(
              'Süre doldu',
              style: TextStyle(
                fontFamily: MeskType.sans,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: MeskColors.danger,
              ),
            )
          else if (goalDeadlineLine(view) case final line?)
            Text(line, style: MeskType.body14),
          Text(
            projected == null
                ? 'Bu hızla tahmin yok'
                : 'Bu hızla ${formatDayMonth(projected.toDateTime())}',
            style: MeskType.caption,
          ),
          if (status.expired)
            Wrap(
              spacing: 8,
              children: [
                MeskTextButton('Tarihi uzat', onPressed: () => _extend()),
                MeskTextButton(
                  'Hedefi kapat',
                  color: MeskColors.danger,
                  onPressed: () =>
                      ref.read(goalsControllerProvider).close(goal.id),
                ),
              ],
            )
          else if (deadline != null)
            Align(
              alignment: Alignment.centerLeft,
              child: MeskSecondaryButton(
                label: 'Günlük alışkanlığa çevir',
                onPressed: () => _toHabit(),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _extend() async {
    final today = await ref.read(todayProvider.future);
    if (!mounted) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: today.addDays(7).toDateTime(),
      firstDate: today.toDateTime(),
      lastDate: DateTime(today.year + 20),
    );
    if (picked == null) return;
    await ref
        .read(goalsControllerProvider)
        .extend(
          view.activeGoal!.id,
          LocalDay(picked.year, picked.month, picked.day),
        );
  }

  Future<void> _toHabit() async {
    if (_converting) return;
    _converting = true;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await runAndCelebrate(
        ref,
        () async =>
            (await ref
                    .read(goalsControllerProvider)
                    .toHabitResult(view.activeGoal!.id))
                .$2,
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('Alışkanlık eklendi.')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Eklenemedi, tekrar dene.')),
      );
    } finally {
      _converting = false;
    }
  }
}
