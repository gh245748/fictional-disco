import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../app/views.dart';
import '../../domain/day.dart';
import '../../domain/format.dart';
import '../../domain/habits.dart';
import '../../domain/models.dart';
import '../../domain/stat_calc.dart';
import '../../domain/stats.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/buttons.dart';
import '../../ui/widgets/stat_dot.dart';

/// Opens the contributions of [stat] (§5.6): the skills that feed it, or for
/// İrade the habits.
Future<void> showStatDetail(BuildContext context, Stat stat) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: MeskColors.surface,
      builder: (_) => StatDetailSheet(stat),
    );

/// "5", "11,5": whole numbers without a decimal, halves with a comma.
String formatContribution(double v) =>
    v == v.roundToDouble() ? '${v.round()}' : '${v.floor()},5';

class StatDetailSheet extends ConsumerWidget {
  const StatDetailSheet(this.stat, {super.key});

  final Stat stat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final character = ref.watch(characterViewProvider).value;
    final views = ref.watch(skillViewsProvider).value;
    final habits = ref.watch(habitsProvider).value;
    final dayData = ref.watch(habitDayDataProvider).value;
    final today = ref.watch(todayProvider).value;
    final ready =
        character != null &&
        views != null &&
        habits != null &&
        dayData != null &&
        today != null;

    final rows = <Widget>[];
    if (ready) {
      if (stat == Stat.irade) {
        rows.addAll(_habitRows(context, habits, today, dayData));
      } else {
        rows.addAll(_skillRows(context, views));
      }
    }
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              spacing: 10,
              children: [
                StatDot(stat, size: 10),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(stat.label, style: MeskType.sectionTitle),
                  ),
                ),
                Text(
                  '${character?.stats[stat] ?? 0}',
                  key: const ValueKey('stat-detail-value'),
                  style: MeskType.bigNumber.copyWith(fontSize: 36),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...rows,
          ],
        ),
      ),
    );
  }

  List<Widget> _skillRows(BuildContext context, List<SkillView> views) {
    final contributions = <(SkillView, double)>[];
    for (final v in views) {
      if (v.skill.primary == stat) contributions.add((v, v.level.toDouble()));
      if (v.skill.secondary == stat) contributions.add((v, v.level / 2));
    }
    contributions.sort((a, b) {
      final c = b.$2.compareTo(a.$2);
      return c != 0 ? c : trCompare(a.$1.skill.name, b.$1.skill.name);
    });
    if (contributions.isEmpty) {
      return [
        _Empty(
          'Bu stata katkı veren yetenek yok. Ana ya da ikincil stat olarak '
              '${stat.label} seçilmiş bir yetenek ekle.',
          'Yetenek ekle',
          () {
            Navigator.of(context).pop();
            context.push('/yetenekler/yeni');
          },
        ),
      ];
    }
    return [
      for (final (v, amount) in contributions)
        _Row(
          '${v.skill.name} · Sv. ${v.level} · +${formatContribution(amount)}'
          '${v.skill.archived ? ' (arşivde)' : ''}',
        ),
    ];
  }

  List<Widget> _habitRows(
    BuildContext context,
    List<Habit> habits,
    LocalDay today,
    HabitDayData dayData,
  ) {
    if (habits.isEmpty) {
      return [
        _Empty(
          'İrade alışkanlıklardan gelir. İlk alışkanlığını ekle, her '
              'tamamladığın gün puan kazan.',
          'Alışkanlık ekle',
          () {
            Navigator.of(context).pop();
            context.push('/aliskanlik/yeni');
          },
        ),
      ];
    }
    final sorted = [...habits]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return [
      for (final h in sorted)
        _Row(
          h.name,
          detail:
              '${completionCount(h, today, dayData)} tamamlama · '
              '+${streakBonusPoints(h, today, dayData)} seri ödülü',
        ),
      const SizedBox(height: 8),
      Text(
        '${iradePoints(habits, today, dayData)} puan ÷ $iradeDivisor',
        style: MeskType.caption,
      ),
    ];
  }
}

class _Row extends StatelessWidget {
  const _Row(this.text, {this.detail});

  final String text;
  final String? detail;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 44),
    alignment: Alignment.centerLeft,
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: MeskColors.divider)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: MeskType.body14),
        if (detail case final d?) Text(d, style: MeskType.caption),
      ],
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty(this.sentence, this.action, this.onPressed);

  final String sentence;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Column(
    spacing: 16,
    children: [
      Text(sentence, style: MeskType.caption, textAlign: TextAlign.center),
      MeskPrimaryButton(label: action, onPressed: onPressed),
    ],
  );
}
