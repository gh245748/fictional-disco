import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../app/views.dart';
import '../../domain/format.dart';
import '../../domain/habits.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/buttons.dart';
import '../../ui/widgets/mesk_card.dart';
import '../../ui/widgets/progress_bar.dart';
import '../../ui/widgets/section_header.dart';
import '../../ui/widgets/stat_dot.dart';
import '../goals/goal_card.dart';
import '../habits/habit_row.dart';
import '../skills/skills_screen.dart';
import 'backup_reminder.dart';
import 'character_card.dart';
import 'focus_card.dart';

/// "21 KASIM · CUMARTESİ".
String todayLabel(DateTime local) =>
    trUpper('${formatDayMonth(local)} · ${formatWeekday(local)}');

/// The Bugün tab (§5.12): the character, today's focus, today's habits and
/// the skills worked on last.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider).value;
    final character = ref.watch(characterViewProvider).value;
    final focus = ref.watch(todayFocusProvider).value;
    final habits = ref.watch(todayHabitsProvider).value;
    final views = ref.watch(skillViewsProvider).value;
    if (today == null ||
        character == null ||
        focus == null ||
        habits == null ||
        views == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final recent = [
      for (final v in sortSkillViews(
        views.where((v) => !v.skill.archived),
        SkillSort.recent,
      ))
        if (v.lastEntryAt != null) v,
    ];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [
                _Header(today.toDateTime()),
                const BackupReminder(),
                CharacterCard(character),
                FocusCard(
                  seconds: focus.$1,
                  pomodoros: focus.$2,
                  lastSkillName: recent.isEmpty
                      ? null
                      : recent.first.skill.name,
                ),
                _HabitsSection(habits),
                _RecentSection(
                  recent.take(3).toList(),
                  hasSkills: views.isNotEmpty,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.date);

  final DateTime date;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 2,
          children: [
            MeskLabel(todayLabel(date)),
            const Text('Bugün', style: MeskType.screenTitle),
          ],
        ),
      ),
      IconButton(
        tooltip: 'Ayarlar',
        onPressed: () => context.push('/ayarlar'),
        style: IconButton.styleFrom(
          fixedSize: const Size.square(44),
          backgroundColor: MeskColors.surface,
          foregroundColor: MeskColors.muted,
          shape: const CircleBorder(
            side: BorderSide(color: MeskColors.surfaceBorder),
          ),
        ),
        icon: const Icon(Icons.tune, size: 20),
      ),
    ],
  );
}

const _rowDivider = BoxDecoration(
  border: Border(bottom: BorderSide(color: MeskColors.divider)),
);

class _HabitsSection extends StatelessWidget {
  const _HabitsSection(this.habits);

  final List<TodayHabit> habits;

  @override
  Widget build(BuildContext context) {
    final done = habits.where((h) => h.done).length;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          SectionHeader(
            title: 'Alışkanlıklar',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (habits.isNotEmpty)
                  Text(
                    'bugün $done / ${habits.length}',
                    style: MeskType.caption,
                  ),
                IconButton(
                  tooltip: 'Yeni alışkanlık',
                  constraints: const BoxConstraints.tightFor(
                    width: 44,
                    height: 44,
                  ),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.add,
                    size: 20,
                    color: MeskColors.accent,
                  ),
                  onPressed: () => context.push('/aliskanlik/yeni'),
                ),
              ],
            ),
          ),
          if (habits.isEmpty)
            MeskCard(
              child: Column(
                spacing: 12,
                children: [
                  const Text(
                    'Henüz alışkanlığın yok.',
                    textAlign: TextAlign.center,
                    style: MeskType.caption,
                  ),
                  MeskPrimaryButton(
                    label: 'Yeni alışkanlık',
                    icon: Icons.add,
                    onPressed: () => context.push('/aliskanlik/yeni'),
                  ),
                ],
              ),
            )
          else
            MeskCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final (i, h) in habits.indexed)
                    DecoratedBox(
                      decoration: i == habits.length - 1
                          ? const BoxDecoration()
                          : _rowDivider,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(4, 3, 14, 3),
                        child: HabitRow(h),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RecentSection extends StatelessWidget {
  const _RecentSection(this.recent, {required this.hasSkills});

  final List<SkillView> recent;
  final bool hasSkills;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        SectionHeader(
          title: 'Son çalıştıkların',
          trailing: recent.isEmpty
              ? null
              : TextButton(
                  onPressed: () => context.go('/yetenekler'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    foregroundColor: MeskColors.accent,
                    textStyle: const TextStyle(
                      fontFamily: MeskType.sans,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  child: const Text('Tümü'),
                ),
        ),
        if (recent.isEmpty)
          MeskCard(
            child: Column(
              spacing: 12,
              children: [
                Text(
                  hasSkills
                      ? 'Henüz çalışma kaydın yok.'
                      : 'Henüz yeteneğin yok. İlkini ekleyerek başla.',
                  textAlign: TextAlign.center,
                  style: MeskType.caption,
                ),
                MeskPrimaryButton(
                  label: hasSkills ? 'Kayıt ekle' : 'Yeni yetenek',
                  icon: Icons.add,
                  onPressed: () => context.push(
                    hasSkills ? '/kayit/yeni' : '/yetenekler/yeni',
                  ),
                ),
              ],
            ),
          )
        else
          MeskCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (i, v) in recent.indexed)
                  DecoratedBox(
                    decoration: i == recent.length - 1
                        ? const BoxDecoration()
                        : _rowDivider,
                    child: _RecentRow(v),
                  ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _RecentRow extends StatelessWidget {
  const _RecentRow(this.view);

  final SkillView view;

  @override
  Widget build(BuildContext context) {
    final skill = view.skill;
    return InkWell(
      onTap: () => context.push('/yetenekler/${skill.id}'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 5,
            children: [
              Row(
                spacing: 8,
                children: [
                  StatDot(skill.primary),
                  Expanded(
                    child: Text(
                      skill.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MeskType.body15,
                    ),
                  ),
                  Text('Sv. ${view.level}', style: MeskType.levelNumber),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                spacing: 8,
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: MeskType.caption,
                        children: [
                          TextSpan(
                            text: view.title,
                            style: MeskType.titleItalic,
                          ),
                          TextSpan(
                            text: ' · ${formatHours(view.totals.xpSeconds)}',
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${formatHours(view.secondsToNext)} kaldı',
                    style: MeskType.caption,
                  ),
                ],
              ),
              MeskProgressBar(
                value: view.progress,
                color: statColor(skill.primary),
              ),
              GoalLine(view),
            ],
          ),
        ),
      ),
    );
  }
}
