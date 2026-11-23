import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../domain/format.dart';
import '../../domain/models.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/buttons.dart';
import '../../ui/widgets/section_header.dart';
import '../../ui/widgets/stat_dot.dart';
import '../celebrations/celebration_host.dart';
import 'habit_calendar.dart';
import 'habits_controller.dart';

const _weekdayNames = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

enum _Program {
  daily('Her gün'),
  weekdays('Belirli günler'),
  timesPerWeek('Haftada N kez');

  const _Program(this.label);
  final String label;
}

/// Creates a habit, or edits the one with [habitId]; an existing habit also
/// shows its calendar.
class HabitEditScreen extends ConsumerWidget {
  const HabitEditScreen({super.key, this.habitId});

  final String? habitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = habitId;
    final title = Text(
      id == null ? 'Yeni alışkanlık' : 'Alışkanlığı düzenle',
      style: MeskType.sectionTitle,
    );
    final habits = ref.watch(habitsProvider).value;
    final skills = ref.watch(skillsProvider).value;
    if (habits == null || skills == null) {
      return Scaffold(appBar: AppBar(title: title));
    }
    final habit = id == null
        ? null
        : habits.where((h) => h.id == id).firstOrNull;
    if (id != null && habit == null) {
      return Scaffold(
        appBar: AppBar(title: title),
        body: const Center(
          child: Text('Alışkanlık bulunamadı.', style: MeskType.caption),
        ),
      );
    }
    final choices = [
      for (final s in skills)
        if (!s.archived || s.id == habit?.skillId) s,
    ]..sort((a, b) => trCompare(a.name, b.name));
    return Scaffold(
      appBar: AppBar(title: title),
      body: SafeArea(
        child: _HabitForm(key: ValueKey(id), habit: habit, skills: choices),
      ),
    );
  }
}

class _HabitForm extends ConsumerStatefulWidget {
  const _HabitForm({super.key, required this.habit, required this.skills});

  /// Null when creating.
  final Habit? habit;
  final List<Skill> skills;

  @override
  ConsumerState<_HabitForm> createState() => _HabitFormState();
}

class _HabitFormState extends ConsumerState<_HabitForm> {
  late final _name = TextEditingController(text: widget.habit?.name);
  late final _target = TextEditingController(
    text: widget.habit?.targetMinutes?.toString(),
  );
  late HabitKind _kind = widget.habit?.kind ?? HabitKind.simple;
  late String? _skillId = widget.habit?.skillId;
  late _Program _program = switch (widget.habit?.schedule) {
    WeekdaysSchedule() => _Program.weekdays,
    TimesPerWeekSchedule() => _Program.timesPerWeek,
    _ => _Program.daily,
  };
  late Set<int> _weekdays = switch (widget.habit?.schedule) {
    WeekdaysSchedule(:final weekdays) => {...weekdays},
    _ => <int>{},
  };
  late int _times = switch (widget.habit?.schedule) {
    TimesPerWeekSchedule(:final times) => times,
    _ => 3,
  };
  late int? _reminder = widget.habit?.reminderMinuteOfDay;
  bool _overall = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  int? get _targetMinutes {
    final v = int.tryParse(_target.text.trim());
    return v != null && v > 0 && v <= 1440 ? v : null;
  }

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      (_kind == HabitKind.simple ||
          (_skillId != null && _targetMinutes != null)) &&
      (_program != _Program.weekdays || _weekdays.isNotEmpty);

  HabitSchedule get _schedule => switch (_program) {
    _Program.daily => const DailySchedule(),
    _Program.weekdays => WeekdaysSchedule({..._weekdays}),
    _Program.timesPerWeek => TimesPerWeekSchedule(_times),
  };

  void _leave() {
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/bugun');
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kaydedilemedi, tekrar dene.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() => _run(() async {
    final timed = _kind == HabitKind.timed;
    final existing = widget.habit;
    final habit = existing == null
        ? Habit(
            id: newId(),
            name: _name.text.trim(),
            kind: _kind,
            skillId: timed ? _skillId : null,
            targetMinutes: timed ? _targetMinutes : null,
            schedule: _schedule,
            reminderMinuteOfDay: _reminder,
            createdAt: ref.read(clockProvider).nowUtc(),
          )
        : existing.copyWith(
            name: _name.text.trim(),
            kind: _kind,
            skillId: timed ? _skillId : null,
            targetMinutes: timed ? _targetMinutes : null,
            schedule: _schedule,
            reminderMinuteOfDay: _reminder,
          );
    await runAndCelebrate(
      ref,
      () => ref.read(habitsControllerProvider).save(habit),
    );
    _leave();
  });

  Future<void> _archive() => _run(() async {
    final h = widget.habit!;
    await runAndCelebrate(ref, () {
      final c = ref.read(habitsControllerProvider);
      return h.archivedAt == null
          ? c.archive(h.id)
          : c.save(h.copyWith(archivedAt: null));
    });
    _leave();
  });

  Future<void> _delete() async {
    final h = widget.habit!;
    final ok = await showDialog<bool>(
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
              '${h.name} ve bütün işaretleri silinecek.',
              style: MeskType.body14.copyWith(fontWeight: FontWeight.w400),
            ),
            const Text(
              'Silmek yerine arşivleyebilirsin.',
              style: MeskType.caption,
            ),
          ],
        ),
        actions: [
          MeskTextButton('Vazgeç', onPressed: () => Navigator.pop(context)),
          MeskTextButton(
            'Sil',
            color: MeskColors.danger,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(() async {
      await runAndCelebrate(
        ref,
        () => ref.read(habitsControllerProvider).delete(h.id),
      );
      _leave();
    });
  }

  Future<void> _pickTime() async {
    final minute = _reminder ?? 9 * 60;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
    );
    if (picked != null && mounted) {
      setState(() => _reminder = picked.hour * 60 + picked.minute);
    }
  }

  static String _clock(int minute) =>
      '${(minute ~/ 60).toString().padLeft(2, '0')}:'
      '${(minute % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final habit = widget.habit;
    final reminder = _reminder;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        TextField(
          key: const ValueKey('habit-name'),
          controller: _name,
          maxLength: 40,
          textCapitalization: TextCapitalization.sentences,
          style: MeskType.body15,
          decoration: const InputDecoration(
            labelText: 'Alışkanlık adı',
            counterText: '',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 24),
        const MeskLabel('Tür'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final (kind, label) in [
              (HabitKind.timed, 'Süreli'),
              (HabitKind.simple, 'Basit'),
            ])
              ChoiceChip(
                label: Text(label),
                selected: _kind == kind,
                side: _kind == kind ? meskSelectedChipSide : null,
                onSelected: (_) => setState(() => _kind = kind),
              ),
          ],
        ),
        if (_kind == HabitKind.timed) ...[
          const SizedBox(height: 24),
          const MeskLabel('Yetenek'),
          const SizedBox(height: 8),
          if (widget.skills.isEmpty) ...[
            const Text(
              'Süreli alışkanlık bir yeteneğe bağlanır. Önce bir yetenek ekle.',
              style: MeskType.caption,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: MeskSecondaryButton(
                label: 'Yetenek ekle',
                onPressed: () => context.push('/yetenekler/yeni'),
              ),
            ),
          ] else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final s in widget.skills)
                  ChoiceChip(
                    key: ValueKey('habit-skill-${s.id}'),
                    avatar: StatDot(s.primary),
                    label: Text(s.name),
                    selected: _skillId == s.id,
                    side: _skillId == s.id ? meskSelectedChipSide : null,
                    onSelected: (_) => setState(() => _skillId = s.id),
                  ),
              ],
            ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('habit-target'),
            controller: _target,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 4,
            style: MeskType.body15,
            decoration: const InputDecoration(
              labelText: 'Günlük hedef (dk)',
              counterText: '',
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
        const SizedBox(height: 24),
        const MeskLabel('Program'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final p in _Program.values)
              ChoiceChip(
                label: Text(p.label),
                selected: _program == p,
                side: _program == p ? meskSelectedChipSide : null,
                onSelected: (_) => setState(() => _program = p),
              ),
          ],
        ),
        if (_program == _Program.weekdays) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (var d = 1; d <= 7; d++)
                FilterChip(
                  key: ValueKey('weekday-$d'),
                  label: Text(_weekdayNames[d - 1]),
                  selected: _weekdays.contains(d),
                  side: _weekdays.contains(d) ? meskSelectedChipSide : null,
                  onSelected: (v) => setState(
                    () => _weekdays = {
                      for (final w in _weekdays)
                        if (w != d) w,
                      if (v) d,
                    },
                  ),
                ),
            ],
          ),
          if (_weekdays.isEmpty) ...[
            const SizedBox(height: 4),
            const Text('En az bir gün seç.', style: MeskType.caption),
          ],
        ],
        if (_program == _Program.timesPerWeek) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (var n = 1; n <= 7; n++)
                ChoiceChip(
                  key: ValueKey('times-$n'),
                  label: Text('$n'),
                  selected: _times == n,
                  side: _times == n ? meskSelectedChipSide : null,
                  onSelected: (_) => setState(() => _times = n),
                ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        const MeskLabel('Hatırlatıcı saati (isteğe bağlı)'),
        const SizedBox(height: 8),
        Row(
          spacing: 8,
          children: [
            MeskSecondaryButton(
              label: reminder == null ? 'Saat seç' : _clock(reminder),
              icon: Icons.schedule,
              onPressed: _pickTime,
            ),
            if (reminder != null)
              IconButton(
                tooltip: 'Hatırlatıcıyı kaldır',
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                icon: const Icon(Icons.close, color: MeskColors.muted),
                onPressed: () => setState(() => _reminder = null),
              ),
          ],
        ),
        const SizedBox(height: 32),
        MeskPrimaryButton(
          label: 'Kaydet',
          onPressed: _valid && !_busy ? _save : null,
        ),
        if (habit != null) ...[
          const SizedBox(height: 32),
          SectionHeader(
            title: 'Takvim',
            trailing: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Bu alışkanlık'),
                  selected: !_overall,
                  side: !_overall ? meskSelectedChipSide : null,
                  onSelected: (_) => setState(() => _overall = false),
                ),
                ChoiceChip(
                  label: const Text('Genel'),
                  selected: _overall,
                  side: _overall ? meskSelectedChipSide : null,
                  onSelected: (_) => setState(() => _overall = true),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          HabitCalendar(
            key: ValueKey(_overall),
            habit: _overall ? null : habit,
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              children: [
                MeskTextButton(
                  habit.archivedAt == null ? 'Arşivle' : 'Arşivden çıkar',
                  onPressed: _busy ? null : _archive,
                ),
                MeskTextButton(
                  'Sil',
                  color: MeskColors.danger,
                  onPressed: _busy ? null : _delete,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
