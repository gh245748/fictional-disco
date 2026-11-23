import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../domain/format.dart';
import '../../domain/models.dart';
import '../../domain/stats.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/buttons.dart';
import '../../ui/widgets/stat_dot.dart';
import 'skills_controller.dart';

const Color _danger = Color(0xFFE08A73);
const BorderSide _selectedSide = BorderSide(color: MeskColors.accent);
const ChipThemeData _chipTheme = ChipThemeData(
  shape: StadiumBorder(),
  showCheckmark: false,
  backgroundColor: MeskColors.surface,
  selectedColor: Color(0xFF2A2418),
  side: BorderSide(color: MeskColors.surfaceBorder),
  labelStyle: MeskType.body14,
  padding: EdgeInsets.symmetric(horizontal: 6),
);

/// Creates a skill, or edits the one with [skillId].
class SkillEditScreen extends ConsumerWidget {
  const SkillEditScreen({super.key, this.skillId});

  final String? skillId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = skillId;
    final title = Text(
      id == null ? 'Yeni yetenek' : 'Yeteneği düzenle',
      style: MeskType.sectionTitle,
    );
    final skills = ref.watch(skillsProvider).value;
    final links = ref.watch(linksProvider).value;
    if (skills == null || links == null) {
      return Scaffold(appBar: AppBar(title: title));
    }
    final skill = id == null
        ? null
        : skills.where((s) => s.id == id).firstOrNull;
    if (id != null && skill == null) {
      return Scaffold(
        appBar: AppBar(title: title),
        body: const Center(
          child: Text('Yetenek bulunamadı.', style: MeskType.caption),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: title),
      body: SafeArea(
        child: _SkillForm(
          key: ValueKey(id),
          skill: skill,
          others: [
            for (final s in skills)
              if (s.id != id) s,
          ]..sort((a, b) => trCompare(a.name, b.name)),
          initialLinks: {
            for (final l in links)
              if (l.a == id) l.b else if (l.b == id) l.a,
          },
        ),
      ),
    );
  }
}

enum _DeleteChoice { backup, archive, delete }

class _SkillForm extends ConsumerStatefulWidget {
  const _SkillForm({
    super.key,
    required this.skill,
    required this.others,
    required this.initialLinks,
  });

  /// Null when creating.
  final Skill? skill;

  /// Every other skill, by name.
  final List<Skill> others;
  final Set<String> initialLinks;

  @override
  ConsumerState<_SkillForm> createState() => _SkillFormState();
}

class _SkillFormState extends ConsumerState<_SkillForm> {
  late final _name = TextEditingController(text: widget.skill?.name);
  late final _description = TextEditingController(
    text: widget.skill?.description,
  );
  late Stat? _primary = widget.skill?.primary;
  late Stat? _secondary = widget.skill?.secondary;
  late Set<String> _links = {...widget.initialLinks};
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  String get _trimmed => _name.text.trim();

  bool get _duplicate {
    final lower = trLower(_trimmed);
    return widget.others.any((s) => trLower(s.name) == lower);
  }

  bool get _valid => _trimmed.isNotEmpty && !_duplicate && _primary != null;

  void _leave() {
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/yetenekler');
    }
  }

  void _failed() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kaydedilemedi, tekrar dene.')),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      _failed();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() => _run(() async {
    final controller = ref.read(skillsControllerProvider);
    final description = _description.text.trim();
    final skill = widget.skill;
    if (skill == null) {
      await controller.create(
        name: _trimmed,
        primary: _primary!,
        secondary: _secondary,
        description: description.isEmpty ? null : description,
        links: _links,
      );
    } else {
      await controller.update(
        skill.copyWith(
          name: _trimmed,
          primary: _primary,
          secondary: _secondary,
          description: description.isEmpty ? null : description,
        ),
        links:
            _links.length == widget.initialLinks.length &&
                _links.containsAll(widget.initialLinks)
            ? null
            : _links,
      );
    }
    _leave();
  });

  Future<void> _archive() => _run(() async {
    final skill = widget.skill!;
    final timed = await ref
        .read(skillsControllerProvider)
        .activeTimedHabits(skill.id);
    if (!mounted) return;
    if (timed.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: MeskColors.surface,
          content: Text(
            'Bu yeteneğe bağlı ${timed.length} alışkanlık da arşivlenecek.',
            style: MeskType.body14.copyWith(fontWeight: FontWeight.w400),
          ),
          actions: [
            _DialogButton('Vazgeç', onPressed: () => Navigator.pop(context)),
            _DialogButton(
              'Arşivle',
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await ref.read(skillsControllerProvider).archive(skill.id);
    _leave();
  });

  Future<void> _unarchive() => _run(() async {
    await ref.read(skillsControllerProvider).unarchive(widget.skill!.id);
    _leave();
  });

  Future<void> _delete() async {
    final skill = widget.skill!;
    final bonus = await ref.read(pipelineProvider).bonusGivenBySkill(skill.id);
    if (!mounted) return;
    final choice = await showDialog<_DeleteChoice>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: MeskColors.surface,
        title: const Text('Silinsin mi?', style: MeskType.sectionTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Text(
              '${skill.name} ve bütün kayıtları silinecek.'
              '${bonus > 0 ? ' Bağlı yeteneklerden ${formatDuration(bonus)} '
                        'bonus da silinecek.' : ''}',
              style: MeskType.body14.copyWith(fontWeight: FontWeight.w400),
            ),
            const Text(
              'Silmek yerine arşivleyebilirsin.',
              style: MeskType.caption,
            ),
          ],
        ),
        actions: [
          _DialogButton(
            'Önce yedek al',
            onPressed: () => Navigator.pop(context, _DeleteChoice.backup),
          ),
          _DialogButton(
            'Arşivle',
            onPressed: () => Navigator.pop(context, _DeleteChoice.archive),
          ),
          _DialogButton(
            'Sil',
            color: _danger,
            onPressed: () => Navigator.pop(context, _DeleteChoice.delete),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case _DeleteChoice.backup:
        context.push('/ayarlar');
      case _DeleteChoice.archive:
        await _archive();
      case _DeleteChoice.delete:
        await _run(() async {
          await ref.read(skillsControllerProvider).delete(skill.id);
          if (mounted) context.go('/yetenekler');
        });
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final skill = widget.skill;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        TextField(
          controller: _name,
          maxLength: 40,
          textCapitalization: TextCapitalization.sentences,
          style: MeskType.body15,
          decoration: InputDecoration(
            labelText: 'Yetenek adı',
            counterText: '',
            errorText: _duplicate ? 'Bu yetenek zaten var' : null,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 24),
        const MeskLabel('Ana stat'),
        const SizedBox(height: 8),
        _statChips(
          keyPrefix: 'primary',
          selected: _primary,
          onChanged: (s) => setState(() {
            _primary = s;
            if (_secondary == s) _secondary = null;
          }),
        ),
        const SizedBox(height: 24),
        const MeskLabel('İkincil stat (isteğe bağlı)'),
        const SizedBox(height: 8),
        _statChips(
          keyPrefix: 'secondary',
          selected: _secondary,
          disabled: _primary,
          onChanged: (s) => setState(() => _secondary = s),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _description,
          maxLength: 200,
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          style: MeskType.body15,
          decoration: const InputDecoration(
            labelText: 'Açıklama (isteğe bağlı)',
          ),
        ),
        const SizedBox(height: 24),
        const MeskLabel('Bağlı yetenekler'),
        const SizedBox(height: 8),
        if (widget.others.isEmpty)
          const Text('Henüz başka yeteneğin yok.', style: MeskType.caption)
        else
          ChipTheme(
            data: _chipTheme,
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final o in widget.others)
                  FilterChip(
                    key: ValueKey('link-${o.id}'),
                    avatar: StatDot(o.primary),
                    label: Text(o.name),
                    selected: _links.contains(o.id),
                    side: _links.contains(o.id) ? _selectedSide : null,
                    onSelected: (v) => setState(
                      () => _links = {
                        for (final id in _links)
                          if (id != o.id) id,
                        if (v) o.id,
                      },
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 32),
        MeskPrimaryButton(
          label: 'Kaydet',
          onPressed: _valid && !_busy ? _save : null,
        ),
        if (skill != null) ...[
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              children: [
                _DialogButton(
                  skill.archived ? 'Arşivden çıkar' : 'Arşivle',
                  onPressed: _busy
                      ? null
                      : (skill.archived ? _unarchive : _archive),
                ),
                _DialogButton(
                  'Sil',
                  color: _danger,
                  onPressed: _busy ? null : _delete,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _statChips({
    required String keyPrefix,
    required Stat? selected,
    Stat? disabled,
    required void Function(Stat?) onChanged,
  }) => ChipTheme(
    data: _chipTheme,
    child: Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final s in skillStats)
          ChoiceChip(
            key: ValueKey('$keyPrefix-${s.name}'),
            avatar: StatDot(s),
            label: Text(s.label),
            selected: selected == s,
            side: selected == s ? _selectedSide : null,
            onSelected: disabled == s
                ? null
                : (v) => onChanged(v ? s : (keyPrefix == 'primary' ? s : null)),
          ),
      ],
    ),
  );
}

/// A text button at least 44 px tall.
class _DialogButton extends StatelessWidget {
  const _DialogButton(this.label, {required this.onPressed, this.color});

  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      minimumSize: const Size(44, 44),
      foregroundColor: color ?? MeskColors.accent,
      textStyle: MeskPrimaryButton.textStyle,
    ),
    child: Text(label),
  );
}
