import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../app/views.dart';
import '../../domain/format.dart';
import '../../domain/stats.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/buttons.dart';
import '../../ui/widgets/progress_bar.dart';
import '../../ui/widgets/stat_dot.dart';

enum SkillSort {
  recent('Son çalışılan'),
  level('Seviye'),
  name('Ad');

  const SkillSort(this.label);
  final String label;
}

/// Orders [views] by [sort]; ties fall back to the name.
List<SkillView> sortSkillViews(Iterable<SkillView> views, SkillSort sort) {
  int byName(SkillView a, SkillView b) => trCompare(a.skill.name, b.skill.name);
  final out = [...views];
  switch (sort) {
    case SkillSort.name:
      out.sort(byName);
    case SkillSort.level:
      out.sort((a, b) {
        final c = b.level.compareTo(a.level);
        if (c != 0) return c;
        final x = b.totals.xpSeconds.compareTo(a.totals.xpSeconds);
        return x != 0 ? x : byName(a, b);
      });
    case SkillSort.recent:
      out.sort((a, b) {
        final x = a.lastEntryAt, y = b.lastEntryAt;
        if (x == null && y == null) return byName(a, b);
        if (x == null) return 1; // never worked on: last
        if (y == null) return -1;
        final c = y.compareTo(x);
        return c != 0 ? c : byName(a, b);
      });
  }
  return out;
}

/// The Yetenekler tab: every skill, sorted or grouped by stat, with archived
/// skills in a collapsible section.
class SkillsScreen extends ConsumerStatefulWidget {
  const SkillsScreen({super.key});

  @override
  ConsumerState<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends ConsumerState<SkillsScreen> {
  SkillSort _sort = SkillSort.recent;
  bool _group = false;
  bool _archiveOpen = false;

  void _create() => context.push('/yetenekler/yeni');

  @override
  Widget build(BuildContext context) {
    final views = ref.watch(skillViewsProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: views.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const Center(
            child: Text('Yetenekler yüklenemedi.', style: MeskType.caption),
          ),
          data: _content,
        ),
      ),
    );
  }

  Widget _content(List<SkillView> all) {
    final active = [
      for (final v in all)
        if (!v.skill.archived) v,
    ];
    final archived = [
      for (final v in all)
        if (v.skill.archived) v,
    ];
    final sortedActive = sortSkillViews(active, _sort);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            const Text('Yetenekler', style: MeskType.screenTitle),
            if (all.isNotEmpty)
              MeskPrimaryButton(
                label: 'Yeni yetenek',
                icon: Icons.add,
                onPressed: _create,
              ),
          ],
        ),
        if (all.isEmpty)
          _empty()
        else ...[
          const SizedBox(height: 16),
          _controls(),
          const SizedBox(height: 8),
          if (active.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Bütün yeteneklerin arşivde.',
                style: MeskType.caption,
              ),
            )
          else if (_group)
            for (final stat in skillStats) ..._groupSection(stat, sortedActive)
          else
            for (final v in sortedActive) _SkillRow(view: v),
          if (archived.isNotEmpty) ..._archive(sortSkillViews(archived, _sort)),
        ],
      ],
    );
  }

  Widget _empty() => Padding(
    padding: const EdgeInsets.only(top: 48),
    child: Column(
      spacing: 16,
      children: [
        const Text(
          'Henüz yeteneğin yok. İlkini ekleyerek başla.',
          textAlign: TextAlign.center,
          style: MeskType.caption,
        ),
        MeskPrimaryButton(
          label: 'Yeni yetenek',
          icon: Icons.add,
          onPressed: _create,
        ),
      ],
    ),
  );

  Widget _controls() => Wrap(
    spacing: 8,
    runSpacing: 4,
    children: [
      for (final s in SkillSort.values)
        ChoiceChip(
          label: Text(s.label),
          selected: _sort == s,
          side: _sort == s ? meskSelectedChipSide : null,
          onSelected: (_) => setState(() => _sort = s),
        ),
      FilterChip(
        label: const Text('Stata göre grupla'),
        selected: _group,
        side: _group ? meskSelectedChipSide : null,
        onSelected: (v) => setState(() => _group = v),
      ),
    ],
  );

  List<Widget> _groupSection(Stat stat, List<SkillView> sorted) {
    final rows = [
      for (final v in sorted)
        if (v.skill.primary == stat) v,
    ];
    if (rows.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Row(
          spacing: 8,
          children: [StatDot(stat), MeskLabel(stat.label)],
        ),
      ),
      for (final v in rows) _SkillRow(view: v),
    ];
  }

  List<Widget> _archive(List<SkillView> archived) => [
    const SizedBox(height: 16),
    Semantics(
      button: true,
      expanded: _archiveOpen,
      child: InkWell(
        onTap: () => setState(() => _archiveOpen = !_archiveOpen),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            spacing: 8,
            children: [
              const Text('Arşiv', style: MeskType.sectionTitle),
              Text('${archived.length}', style: MeskType.caption),
              const Spacer(),
              Icon(
                _archiveOpen ? Icons.expand_less : Icons.expand_more,
                color: MeskColors.muted,
              ),
            ],
          ),
        ),
      ),
    ),
    if (_archiveOpen)
      for (final v in archived) _SkillRow(view: v),
  ];
}

class _SkillRow extends StatelessWidget {
  const _SkillRow({required this.view});

  final SkillView view;

  @override
  Widget build(BuildContext context) {
    final skill = view.skill;
    final row = InkWell(
      onTap: () => context.push('/yetenekler/${skill.id}'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              Row(
                spacing: 10,
                children: [
                  StatDot(skill.primary, size: 10),
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
                spacing: 8,
                children: [
                  Expanded(
                    child: Text(
                      view.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MeskType.titleItalic.copyWith(
                        color: MeskColors.muted,
                      ),
                    ),
                  ),
                  Text(
                    formatHours(view.totals.xpSeconds),
                    style: MeskType.caption,
                  ),
                ],
              ),
              MeskProgressBar(
                value: view.progress,
                color: statColor(skill.primary),
              ),
            ],
          ),
        ),
      ),
    );
    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: MeskColors.divider)),
        ),
        child: row,
      ),
    );
  }
}
