import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../app/views.dart';
import '../../domain/format.dart';
import '../../domain/stats.dart';
import '../../domain/titles.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/buttons.dart';
import '../../ui/widgets/mesk_card.dart';
import '../../ui/widgets/radar_chart.dart';
import '../../ui/widgets/stat_dot.dart';
import 'character_controller.dart';
import 'stat_detail_sheet.dart';

/// The Karakter tab (§5.6): name, display title, total level, radar and the
/// six stats.
class CharacterScreen extends ConsumerWidget {
  const CharacterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(characterViewProvider).value;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: view == null
            ? const SizedBox.shrink()
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                children: [
                  const Text('Karakter', style: MeskType.screenTitle),
                  const SizedBox(height: 16),
                  _Identity(view),
                  const SizedBox(height: 20),
                  const MeskLabel('Toplam seviye'),
                  const SizedBox(height: 4),
                  Text('${view.totalLevel}', style: MeskType.bigNumber),
                  const SizedBox(height: 2),
                  Text(
                    '${formatHours(view.totalRealSeconds)} · '
                    '${view.skillCount} yetenek',
                    style: MeskType.caption,
                  ),
                  _LabeledRadar(view.stats),
                  _StatList(view.stats),
                  const SizedBox(height: 12),
                  const _HowItWorks(),
                  const SizedBox(height: 12),
                  MeskCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    onTap: () => context.push('/basarimlar'),
                    child: const SizedBox(
                      height: 48,
                      child: Row(
                        spacing: 12,
                        children: [
                          Icon(
                            Icons.emoji_events_outlined,
                            size: 20,
                            color: MeskColors.accent,
                          ),
                          Expanded(
                            child: Text('Başarımlar', style: MeskType.body15),
                          ),
                          Icon(Icons.chevron_right, color: MeskColors.muted),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Identity extends ConsumerWidget {
  const _Identity(this.view);

  final CharacterView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = view.name.isEmpty ? 'İsimsiz' : view.name;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: MeskType.sectionTitle.copyWith(fontSize: 30),
              ),
            ),
            IconButton(
              tooltip: 'Adı değiştir',
              icon: const Icon(Icons.edit_outlined, size: 20),
              color: MeskColors.muted,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              onPressed: () => _editName(context, ref),
            ),
          ],
        ),
        if (view.skillCount == 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                const Text(
                  'Unvanın ilk yeteneğinle birlikte gelir.',
                  style: MeskType.caption,
                ),
                MeskPrimaryButton(
                  label: 'Yetenek ekle',
                  icon: Icons.add,
                  onPressed: () => context.push('/yetenekler/yeni'),
                ),
              ],
            ),
          )
        else
          Tooltip(
            message: 'Unvanı değiştir',
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _pickTitle(context),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 4,
                  children: [
                    Flexible(
                      child: Text(
                        view.displayTitle,
                        style: MeskType.titleItalic.copyWith(
                          fontSize: 24,
                          color: MeskColors.accent,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.expand_more,
                      size: 20,
                      color: MeskColors.muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _editName(BuildContext context, WidgetRef ref) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(view.name),
    );
    if (name == null || name.trim().isEmpty) return;
    await ref.read(characterControllerProvider).setName(name);
  }

  Future<void> _pickTitle(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: MeskColors.surface,
    builder: (_) => const _TitlePicker(),
  );
}

class _NameDialog extends StatefulWidget {
  const _NameDialog(this.initial);

  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Karakterin adı', style: MeskType.sectionTitle),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLength: 40,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(labelText: 'Ad'),
      onSubmitted: (v) => Navigator.of(context).pop(v),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Vazgeç'),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(_controller.text),
        child: const Text('Kaydet'),
      ),
    ],
  );
}

/// Every title the user has reached (a [LevelReached] row of any skill),
/// highest level first, plus "Otomatik" for the default.
class _TitlePicker extends ConsumerWidget {
  const _TitlePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reached = ref.watch(levelReachedProvider).value ?? const [];
    final names = {
      for (final s in ref.watch(skillsProvider).value ?? const []) s.id: s.name,
    };
    final character = ref.watch(characterProvider).value;
    final chosenId = character?.titleSkillId;
    final chosenLevel = character?.titleLevel;
    final rows =
        [
          for (final r in reached)
            if (names.containsKey(r.skillId)) r,
        ]..sort((a, b) {
          final c = b.level.compareTo(a.level);
          return c != 0 ? c : trCompare(names[a.skillId]!, names[b.skillId]!);
        });
    final controller = ref.read(characterControllerProvider);

    Widget option({
      required Key key,
      required String title,
      required String caption,
      required bool selected,
      required VoidCallback onTap,
    }) => InkWell(
      key: key,
      onTap: () {
        onTap();
        Navigator.of(context).pop();
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Row(
            spacing: 12,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: MeskType.titleItalic.copyWith(fontSize: 18),
                    ),
                    Text(caption, style: MeskType.caption),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check, size: 18, color: MeskColors.accent),
            ],
          ),
        ),
      ),
    );

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Unvanını seç', style: MeskType.sectionTitle),
            ),
            option(
              key: const ValueKey('title-auto'),
              title: 'Otomatik',
              caption: 'En yüksek seviyeli yeteneğinin unvanı',
              selected: chosenId == null || chosenLevel == null,
              onTap: controller.clearTitle,
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final r in rows)
                    option(
                      key: ValueKey('title-${r.skillId}-${r.level}'),
                      title: titleForLevel(r.level),
                      caption: '${names[r.skillId]} · Sv. ${r.level}',
                      selected: r.skillId == chosenId && r.level == chosenLevel,
                      onTap: () => controller.setTitle(r.skillId, r.level),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The radar with each stat's name and value at its axis.
class _LabeledRadar extends StatelessWidget {
  const _LabeledRadar(this.stats);

  final Map<Stat, int> stats;

  static const double _radar = 260;
  static const double _height = 330;

  /// Axis length of the radar painter: 46 of its 110-unit box.
  static const double _axis = _radar * 46 / 110;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: _height,
    child: LayoutBuilder(
      builder: (context, c) {
        final center = Offset(c.maxWidth / 2, _height / 2);
        final labels = <Widget>[];
        for (var i = 0; i < radarOrder.length; i++) {
          final angle = -math.pi / 2 + i * math.pi / 3;
          final cos = math.cos(angle);
          final distance = _axis + 24 + 22 * cos * cos;
          final p = center + Offset(cos, math.sin(angle)) * distance;
          final stat = radarOrder[i];
          labels.add(
            Positioned(
              left: p.dx,
              top: p.dy,
              child: FractionalTranslation(
                translation: const Offset(-0.5, -0.5),
                child: ExcludeSemantics(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(stat.label, style: MeskType.caption),
                      Text('${stats[stat] ?? 0}', style: MeskType.body14),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return Stack(
          children: [
            Positioned(
              left: center.dx - _radar / 2,
              top: center.dy - _radar / 2,
              child: RadarChart(
                size: _radar,
                values: {
                  for (final e in stats.entries) e.key: e.value.toDouble(),
                },
              ),
            ),
            ...labels,
          ],
        );
      },
    ),
  );
}

class _StatList extends StatelessWidget {
  const _StatList(this.stats);

  final Map<Stat, int> stats;

  @override
  Widget build(BuildContext context) => MeskCard(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        for (final (i, s) in Stat.values.indexed) ...[
          if (i > 0) const Divider(),
          InkWell(
            key: ValueKey('stat-${s.name}'),
            onTap: () => showStatDetail(context, s),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  spacing: 12,
                  children: [
                    StatDot(s, size: 10),
                    Expanded(child: Text(s.label, style: MeskType.body15)),
                    Text('${stats[s] ?? 0}', style: MeskType.levelNumber),
                    const Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: MeskColors.muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

/// "Statlar nasıl hesaplanır?": three plain sentences from §5.6.
class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  static const List<String> _sentences = [
    'Her yetenek ana statına seviyesinin tamamını, ikincil statına '
        'yarısını verir.',
    'İrade, tamamladığın alışkanlıklardan ve seri ödüllerinden gelir.',
    'Statlar zamanla düşmez; yalnızca kayıtlarını düzeltirsen değişir.',
  ];

  @override
  Widget build(BuildContext context) => MeskCard(
    padding: EdgeInsets.zero,
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: const Text('Statlar nasıl hesaplanır?', style: MeskType.body15),
        iconColor: MeskColors.muted,
        collapsedIconColor: MeskColors.muted,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final s in _sentences)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                s,
                style: MeskType.caption.copyWith(fontSize: 13, height: 1.45),
              ),
            ),
        ],
      ),
    ),
  );
}
