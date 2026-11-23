import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../app/views.dart';
import '../../domain/format.dart';
import '../../domain/level_curve.dart';
import '../../domain/models.dart';
import '../../domain/stats.dart';
import '../../domain/titles.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/buttons.dart';
import '../../ui/widgets/mesk_card.dart';
import '../../ui/widgets/progress_bar.dart';
import '../../ui/widgets/section_header.dart';
import '../../ui/widgets/stat_dot.dart';
import '../../ui/widgets/weekly_chart.dart';
import '../celebrations/celebration_host.dart';
import '../entries/entry_form_screen.dart';
import '../goals/goal_card.dart';

/// The skill screen (§5.12): level and progress, real and experience time,
/// goal, links, next title, weekly chart, entries and level achievements.
class SkillDetailScreen extends ConsumerWidget {
  const SkillDetailScreen({super.key, required this.skillId});

  final String skillId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(skillViewProvider(skillId));
    return view.when(
      loading: () => Scaffold(appBar: AppBar()),
      error: (_, _) => Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Text('Yetenek yüklenemedi.', style: MeskType.caption),
        ),
      ),
      data: (v) => v == null
          ? Scaffold(
              appBar: AppBar(),
              body: const Center(
                child: Text('Yetenek bulunamadı.', style: MeskType.caption),
              ),
            )
          : _SkillDetail(view: v),
    );
  }
}

class _SkillDetail extends ConsumerStatefulWidget {
  const _SkillDetail({required this.view});

  final SkillView view;

  @override
  ConsumerState<_SkillDetail> createState() => _SkillDetailState();
}

class _SkillDetailState extends ConsumerState<_SkillDetail> {
  /// Entries swiped away, hidden until the store drops them.
  final Set<String> _removed = {};

  Skill get _skill => widget.view.skill;

  void _addEntry({bool prior = false}) =>
      context.push('/kayit/yeni?skill=${_skill.id}${prior ? '&prior=1' : ''}');

  Future<bool> _delete(TimeEntry e) async {
    if (!await confirmDeleteEntry(context, e)) return false;
    try {
      await runAndCelebrate(
        ref,
        () => ref.read(pipelineProvider).deleteEntry(e.id),
      );
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Silinemedi, tekrar dene.')),
        );
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final skill = _skill;
    final entries = [
      for (final e in ref.watch(entriesProvider).value ?? const <TimeEntry>[])
        if (e.skillId == skill.id && !_removed.contains(e.id)) e,
    ]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final today = ref.watch(todayProvider).value;
    final dayStartHour = ref.watch(settingsProvider).value?.dayStartHour ?? 0;
    final color = statColor(skill.primary);

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Elle kayıt ekle',
            icon: const Icon(Icons.add),
            onPressed: _addEntry,
          ),
          IconButton(
            tooltip: 'Düzenle',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/yetenekler/${skill.id}/duzenle'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            _Header(skill: skill),
            const SizedBox(height: 16),
            _LevelCard(view: view, color: color),
            const SizedBox(height: 12),
            _GoalArea(view: view),
            _CompletedGoals(skillId: skill.id),
            const SizedBox(height: 24),
            _Links(skill: skill),
            const SizedBox(height: 20),
            _NextTitle(view: view),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Son 12 hafta'),
            const SizedBox(height: 12),
            if (today != null)
              WeeklyChart(
                lastWeeksTrackedSeconds(entries, today, dayStartHour),
                color: color,
              ),
            const SizedBox(height: 28),
            SectionHeader(
              title: 'Kayıtlar',
              trailing: entries.isEmpty
                  ? null
                  : _SmallButton('Ekle', onPressed: _addEntry),
            ),
            const SizedBox(height: 4),
            if (entries.isEmpty)
              _Empty(
                text: 'Henüz kayıt yok. İlk çalışmanı ekle.',
                action: 'Kayıt ekle',
                onPressed: _addEntry,
              )
            else
              for (final e in entries)
                _EntryRow(
                  key: ValueKey('entry-${e.id}'),
                  entry: e,
                  confirmDelete: () => _delete(e),
                  onDeleted: () => setState(() => _removed.add(e.id)),
                ),
            Align(
              alignment: Alignment.centerLeft,
              child: _SmallButton(
                'Önceki deneyim ekle',
                onPressed: () => _addEntry(prior: true),
              ),
            ),
            const SizedBox(height: 24),
            _LevelAchievements(skill: skill, onAddEntry: _addEntry),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.skill});

  final Skill skill;

  @override
  Widget build(BuildContext context) {
    final secondary = skill.secondary;
    final description = skill.description;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            StatDot(skill.primary),
            MeskLabel(skill.primary.label),
            if (secondary != null) ...[
              StatDot(secondary),
              MeskLabel(secondary.label),
            ],
            if (skill.archived) const MeskLabel('Arşivde'),
          ],
        ),
        Semantics(
          header: true,
          child: Text(skill.name, style: MeskType.screenTitle),
        ),
        if (description != null) Text(description, style: MeskType.caption),
      ],
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.view, required this.color});

  final SkillView view;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tier = view.tier;
    final nextTier = view.nextTier;
    final xp = view.totals.xpSeconds;
    final band = tier == null
        ? view.band.label
        : '${view.band.label} · ${hiddenTierName(tier)}';
    return MeskCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 14,
            runSpacing: 4,
            children: [
              Text('Sv. ${view.level}', style: MeskType.bigNumber),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 2,
                  children: [
                    Text(
                      view.title,
                      style: MeskType.titleItalic.copyWith(fontSize: 24),
                    ),
                    MeskLabel(
                      band,
                      color: tier == null ? null : MeskColors.accent,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (view.level < maxLevel) ...[
            MeskProgressBar(value: view.progress, color: color, height: 4),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${formatDuration(view.secondsToNext)} kaldı',
                    style: MeskType.caption,
                  ),
                ),
                Text(formatPercent(view.progress), style: MeskType.caption),
              ],
            ),
          ] else if (nextTier != null) ...[
            // The tier's name stays hidden until it is reached (§5.3).
            const Text('Sıradaki: ???', style: MeskType.body14),
            const SizedBox(height: 8),
            MeskProgressBar(
              value: view.tierProgress,
              color: MeskColors.accent,
              height: 4,
            ),
            const SizedBox(height: 8),
            Text(
              '${formatPercent(view.tierProgress)} · '
              '${formatHours(hiddenTierThresholdSeconds(nextTier) - xp)} kaldı',
              style: MeskType.caption,
            ),
          ],
          const SizedBox(height: 16),
          Text(
            '${formatHours(xp)} tecrübe · '
            '${formatHours(view.totals.realSeconds)} gerçek',
            style: MeskType.body14,
          ),
          const SizedBox(height: 16),
          MeskPrimaryButton(
            label: 'Başlat',
            icon: Icons.play_arrow_rounded,
            onPressed: () => context.go('/odak?skill=${view.skill.id}'),
          ),
        ],
      ),
    );
  }
}

/// The active goal's card, or a prompt to set a goal (§5.10).
class _GoalArea extends StatelessWidget {
  const _GoalArea({required this.view});

  final SkillView view;

  @override
  Widget build(BuildContext context) {
    if (view.activeGoal != null) return GoalCard(view);
    return MeskCard(
      child: Row(
        spacing: 12,
        children: [
          const Expanded(
            child: Text(
              'Bir hedef koyarak ilerlemeni ölç.',
              style: MeskType.caption,
            ),
          ),
          MeskPrimaryButton(
            label: 'Hedef koy',
            onPressed: () => context.push('/hedef/${view.skill.id}'),
          ),
        ],
      ),
    );
  }
}

/// Completed goals of a skill, newest first: target and completion date.
/// Hidden while there are none (the goal card above already invites one).
class _CompletedGoals extends ConsumerWidget {
  const _CompletedGoals({required this.skillId});

  final String skillId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clock = ref.watch(clockProvider);
    final done = [
      for (final g in ref.watch(goalsProvider).value ?? const <Goal>[])
        if (g.skillId == skillId && g.completedAt != null) g,
    ]..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
    if (done.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        const SectionHeader(title: 'Tamamlanan hedefler'),
        const SizedBox(height: 4),
        for (final g in done)
          Container(
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.centerLeft,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: MeskColors.divider)),
            ),
            child: Text(
              '${formatHours(g.targetSeconds)} · '
              '${formatDate(g.completedAt!.add(Duration(minutes: clock.offsetMinutesAt(g.completedAt!))))}',
              style: MeskType.body14,
            ),
          ),
      ],
    );
  }
}

class _Links extends ConsumerWidget {
  const _Links({required this.skill});

  final Skill skill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final links = ref.watch(linksProvider).value ?? const <SkillLink>[];
    final skills = ref.watch(skillsProvider).value ?? const <Skill>[];
    final ids = {
      for (final l in links)
        if (l.a == skill.id) l.b else if (l.b == skill.id) l.a,
    };
    final linked = [
      for (final s in skills)
        if (ids.contains(s.id)) s,
    ]..sort((a, b) => trCompare(a.name, b.name));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        const MeskLabel('Bağlı yetenekler'),
        if (linked.isEmpty)
          _Empty(
            text: 'Henüz bağlı yetenek yok.',
            action: 'Bağlantı ekle',
            onPressed: () => context.push('/yetenekler/${skill.id}/duzenle'),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final s in linked)
                ActionChip(
                  avatar: StatDot(s.primary),
                  label: Text(s.name),
                  onPressed: () => context.push('/yetenekler/${s.id}'),
                ),
            ],
          ),
      ],
    );
  }
}

class _NextTitle extends StatelessWidget {
  const _NextTitle({required this.view});

  final SkillView view;

  @override
  Widget build(BuildContext context) {
    final String? next = view.level < maxLevel
        ? titleForLevel(view.level + 1)
        : view.nextTier == null
        ? null
        : '???';
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      children: [
        if (next != null) Text('Sıradaki unvan: $next', style: MeskType.body14),
        _SmallButton(
          'Unvan yolu',
          onPressed: () =>
              context.push('/yetenekler/${view.skill.id}/unvanlar'),
        ),
      ],
    );
  }
}

String entrySourceLabel(EntrySource s) => switch (s) {
  EntrySource.pomodoro => 'Pomodoro',
  EntrySource.free => 'Serbest',
  EntrySource.manual => 'Elle',
  EntrySource.prior => 'Önceki deneyim',
};

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    super.key,
    required this.entry,
    required this.confirmDelete,
    required this.onDeleted,
  });

  final TimeEntry entry;
  final Future<bool> Function() confirmDelete;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final note = e.note;
    final local = e.startedAt.add(Duration(minutes: e.offsetMinutes));
    return Semantics(
      customSemanticsActions: {
        const CustomSemanticsAction(label: 'Sil'): confirmDelete,
      },
      child: Dismissible(
        key: ValueKey('dismiss-${e.id}'),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => confirmDelete(),
        onDismissed: (_) => onDeleted(),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 16),
          color: MeskColors.surface,
          child: const Icon(Icons.delete_outline, color: MeskColors.danger),
        ),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: MeskColors.divider)),
          ),
          child: InkWell(
            onTap: () => context.push('/kayit/${e.id}'),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 12,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 2,
                        children: [
                          Text(formatDate(local), style: MeskType.body14),
                          Text(
                            entrySourceLabel(e.source),
                            style: MeskType.caption,
                          ),
                          if (note != null && note.isNotEmpty)
                            Text(
                              note,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: MeskType.caption.copyWith(
                                color: MeskColors.faint,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(formatDuration(e.seconds), style: MeskType.body14),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LevelAchievements extends ConsumerWidget {
  const _LevelAchievements({required this.skill, required this.onAddEntry});

  final Skill skill;
  final VoidCallback onAddEntry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clock = ref.watch(clockProvider);
    final levels = [
      for (final r in ref.watch(levelReachedProvider).value ?? const [])
        if (r.skillId == skill.id) r,
    ]..sort((a, b) => b.level.compareTo(a.level));
    final tiers = [
      for (final r in ref.watch(tierReachedProvider).value ?? const [])
        if (r.skillId == skill.id) r,
    ]..sort((a, b) => b.tier.index.compareTo(a.tier.index));
    String date(DateTime utc) =>
        formatDate(utc.add(Duration(minutes: clock.offsetMinutesAt(utc))));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        SectionHeader(
          title: 'Seviye başarımları',
          trailing: Text(
            '${levels.length} / $maxLevel',
            style: MeskType.caption,
          ),
        ),
        if (levels.isEmpty)
          _Empty(
            text: 'İlk kaydınla 1. seviyenin başarımı açılır.',
            action: 'Kayıt ekle',
            onPressed: onAddEntry,
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in tiers)
                _Badge(
                  text: hiddenTierName(t.tier).characters.first,
                  gold: true,
                  tooltip: '${hiddenTierName(t.tier)} · ${date(t.at)}',
                ),
              for (final r in levels)
                _Badge(
                  text: '${r.level}',
                  gold: milestoneLevels.contains(r.level),
                  tooltip:
                      'Sv. ${r.level} · ${titleForLevel(r.level)} · '
                      '${date(r.at)}',
                ),
            ],
          ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.gold, required this.tooltip});

  final String text;
  final bool gold;
  final String tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: MeskColors.surface,
        border: Border.all(
          color: gold ? MeskColors.accent : MeskColors.surfaceBorder,
          width: gold ? 1.5 : 1,
        ),
      ),
      child: Text(
        text,
        style: MeskType.levelNumber.copyWith(
          fontSize: 17,
          color: gold ? MeskColors.accent : MeskColors.text,
        ),
      ),
    ),
  );
}

/// A guiding sentence with an action, for empty lists (§5.12).
class _Empty extends StatelessWidget {
  const _Empty({
    required this.text,
    required this.action,
    required this.onPressed,
  });

  final String text;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        Text(text, style: MeskType.caption),
        _SmallButton(action, onPressed: onPressed),
      ],
    ),
  );
}

/// A gold text button at least 44 px tall.
class _SmallButton extends StatelessWidget {
  const _SmallButton(this.label, {required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      minimumSize: const Size(44, 44),
      foregroundColor: MeskColors.accent,
      textStyle: MeskPrimaryButton.textStyle,
    ),
    child: Text(label),
  );
}
