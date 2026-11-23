import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../app/views.dart';
import '../../domain/achievements.dart';
import '../../domain/format.dart';
import '../../domain/level_curve.dart';
import '../../domain/models.dart';
import '../../domain/titles.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/buttons.dart';
import '../skills/skills_screen.dart';

/// Başarımlar (§5.5): the 23 general badges and, per skill, the level badges
/// with milestone levels in a gold frame.
class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Başarımlar', style: MeskType.sectionTitle),
        bottom: const TabBar(
          labelStyle: MeskType.body14,
          labelColor: MeskColors.text,
          unselectedLabelColor: MeskColors.muted,
          indicatorColor: MeskColors.accent,
          dividerColor: MeskColors.surfaceBorder,
          tabs: [
            Tab(text: 'Genel'),
            Tab(text: 'Yetenekler'),
          ],
        ),
      ),
      body: const SafeArea(
        top: false,
        child: TabBarView(children: [_GeneralTab(), _SkillsTab()]),
      ),
    ),
  );
}

/// Local calendar date of a stored UTC instant, as "21 Kasım 2026".
String _localDate(WidgetRef ref, DateTime utc) {
  final offset = ref.read(clockProvider).offsetMinutesAt(utc);
  return formatDate(utc.add(Duration(minutes: offset)));
}

class _GeneralTab extends ConsumerWidget {
  const _GeneralTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlocked = {
      for (final u in ref.watch(achievementsProvider).value ?? const [])
        u.key: u.at,
    };
    Widget tile(AchievementDef def) {
      final at = unlocked[def.key];
      return _BadgeTile(
        key: ValueKey('badge-${def.key}'),
        name: def.name,
        caption: at == null ? def.condition : _localDate(ref, at),
        unlocked: at != null,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        spacing: 12,
        children: [
          for (var i = 0; i < generalAchievements.length; i += 2)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  Expanded(child: tile(generalAchievements[i])),
                  Expanded(
                    child: i + 1 < generalAchievements.length
                        ? tile(generalAchievements[i + 1])
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A badge card; locked ones are faint and show their condition, unlocked
/// ones show the date.
class _BadgeTile extends StatelessWidget {
  const _BadgeTile({
    super.key,
    required this.name,
    required this.caption,
    required this.unlocked,
    this.icon,
  });

  final String name;
  final String caption;
  final bool unlocked;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final nameColor = unlocked ? MeskColors.text : MeskColors.faint;
    return Semantics(
      container: true,
      label: unlocked ? '$name, açıldı, $caption' : '$name, kilitli, $caption',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: MeskColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: unlocked ? MeskColors.accent : MeskColors.surfaceBorder,
          ),
        ),
        child: Column(
          spacing: 6,
          children: [
            Icon(
              icon ??
                  (unlocked
                      ? Icons.workspace_premium_outlined
                      : Icons.lock_outline),
              size: 26,
              color: unlocked ? MeskColors.accent : MeskColors.faint,
            ),
            Text(
              name,
              textAlign: TextAlign.center,
              style: MeskType.body14.copyWith(color: nameColor),
            ),
            Text(
              caption,
              textAlign: TextAlign.center,
              style: MeskType.caption.copyWith(
                color: unlocked ? MeskColors.muted : MeskColors.faint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkillsTab extends ConsumerWidget {
  const _SkillsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final views = ref.watch(skillViewsProvider).value;
    if (views == null) return const SizedBox.shrink();
    if (views.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: [
              const Text(
                'Seviye başarımların yeteneklerinle birlikte burada toplanır. '
                'İlk yeteneğini ekleyerek başla.',
                style: MeskType.caption,
                textAlign: TextAlign.center,
              ),
              MeskPrimaryButton(
                label: 'Yetenek ekle',
                icon: Icons.add,
                onPressed: () => context.push('/yetenekler/yeni'),
              ),
            ],
          ),
        ),
      );
    }

    final levelRows = ref.watch(levelReachedProvider).value ?? const [];
    final tierRows = ref.watch(tierReachedProvider).value ?? const [];
    final reachedBySkill = <String, Map<int, DateTime>>{};
    for (final r in levelRows) {
      (reachedBySkill[r.skillId] ??= {})[r.level] = r.at;
    }
    // Hidden tiers are not mentioned until some skill reaches level 99
    // (§5.3, Ruling R16).
    final showTiers =
        tierRows.isNotEmpty || views.any((v) => v.level >= maxLevel);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        for (final v in sortSkillViews(views, SkillSort.level))
          _SkillSection(
            v,
            reachedBySkill[v.skill.id] ?? const {},
            onLevelTap: (level, at) =>
                _showLevelDetail(context, ref, v, level, at),
          ),
        if (showTiers)
          _HiddenTiers(tierRows, {
            for (final v in views) v.skill.id: v.skill.name,
          }),
      ],
    );
  }

  void _showLevelDetail(
    BuildContext context,
    WidgetRef ref,
    SkillView view,
    int level,
    DateTime at,
  ) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: MeskColors.surface,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            Text('${view.skill.name} · Sv. $level', style: MeskType.caption),
            Text(
              titleForLevel(level),
              style: MeskType.titleItalic.copyWith(
                fontSize: 32,
                color: milestoneLevels.contains(level)
                    ? MeskColors.accent
                    : MeskColors.text,
              ),
            ),
            Text(descriptionForLevel(level), style: MeskType.body14),
            Text(_localDate(ref, at), style: MeskType.caption),
          ],
        ),
      ),
    ),
  );
}

class _SkillSection extends StatelessWidget {
  const _SkillSection(this.view, this.reached, {required this.onLevelTap});

  final SkillView view;
  final Map<int, DateTime> reached;
  final void Function(int level, DateTime at) onLevelTap;

  @override
  Widget build(BuildContext context) {
    final levels = reached.keys.toList()..sort();
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Semantics(
            header: true,
            child: Text(view.skill.name, style: MeskType.sectionTitle),
          ),
          Text(
            'Sv. ${view.level} · ${view.title}'
            '${view.skill.archived ? ' · arşivde' : ''}',
            style: MeskType.caption,
          ),
          if (levels.isEmpty)
            const Text(
              'İlk süre kaydıyla 1. seviye başarımı açılır.',
              style: MeskType.caption,
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final level in levels)
                  _LevelBadge(
                    skillId: view.skill.id,
                    level: level,
                    onTap: () => onLevelTap(level, reached[level]!),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({
    required this.skillId,
    required this.level,
    required this.onTap,
  });

  final String skillId;
  final int level;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final milestone = milestoneLevels.contains(level);
    return Semantics(
      button: true,
      label: 'Seviye $level, ${titleForLevel(level)}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          key: ValueKey('level-$skillId-$level'),
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: milestone ? MeskColors.accent : MeskColors.surfaceBorder,
              width: milestone ? 2 : 1,
            ),
          ),
          child: Text(
            '$level',
            style: MeskType.levelNumber.copyWith(
              fontSize: 17,
              color: milestone ? MeskColors.accent : MeskColors.text,
            ),
          ),
        ),
      ),
    );
  }
}

/// The three hidden tiers; names stay "???" until some skill reached them.
class _HiddenTiers extends StatelessWidget {
  const _HiddenTiers(this.rows, this.skillNames);

  final List<TierReached> rows;
  final Map<String, String> skillNames;

  @override
  Widget build(BuildContext context) {
    final first = <HiddenTier, TierReached>{};
    for (final r in rows) {
      final other = first[r.tier];
      if (other == null || r.at.isBefore(other.at)) first[r.tier] = r;
    }
    return Consumer(
      builder: (context, ref, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Semantics(
            header: true,
            child: const Text('Gizli kademeler', style: MeskType.sectionTitle),
          ),
          for (final t in HiddenTier.values)
            _BadgeTile(
              key: ValueKey('tier-${t.name}'),
              name: first[t] == null ? '???' : hiddenTierName(t),
              caption: first[t] == null
                  ? 'Henüz ulaşılmadı'
                  : '${skillNames[first[t]!.skillId] ?? ''} · '
                        '${_localDate(ref, first[t]!.at)}',
              unlocked: first[t] != null,
              icon: first[t] == null ? Icons.help_outline : Icons.spa_outlined,
            ),
        ],
      ),
    );
  }
}
