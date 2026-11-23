import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../domain/day.dart';
import '../../domain/format.dart';
import '../../domain/models.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/buttons.dart';
import '../celebrations/celebration_host.dart';

const String priorHint =
    'Seviyene ve hedefine sayılır; bonus, alışkanlık ve günlük toplamlara '
    'sayılmaz.';

/// Why an entry of [seconds] starting at [startedAtUtc] cannot be saved, or
/// null when it can. Tracked time may neither start nor end in the future
/// (Ruling R18); [prior] experience is a lump sum of past time, so only its
/// start is checked.
String? entryError({
  required int seconds,
  required DateTime startedAtUtc,
  required DateTime nowUtc,
  bool prior = false,
}) {
  if (seconds <= 0) return 'Süre sıfırdan büyük olmalı.';
  if (startedAtUtc.isAfter(nowUtc)) return 'Gelecekteki bir zaman seçilemez.';
  if (!prior && startedAtUtc.add(Duration(seconds: seconds)).isAfter(nowUtc)) {
    return 'Kayıt gelecekte bitemez.';
  }
  return null;
}

/// The UTC instant of [minuteOfDay] on [day] at a UTC offset of
/// [offsetMinutes].
DateTime localToUtc(LocalDay day, int minuteOfDay, int offsetMinutes) =>
    DateTime.utc(
      day.year,
      day.month,
      day.day,
    ).add(Duration(minutes: minuteOfDay - offsetMinutes));

/// Asks before deleting [e]; true when the user confirmed.
Future<bool> confirmDeleteEntry(BuildContext context, TimeEntry e) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: MeskColors.surface,
      title: const Text('Kayıt silinsin mi?', style: MeskType.sectionTitle),
      content: Text(
        '${formatDuration(e.seconds)} süren bu kayıt silinecek.'
        '${e.isPrior ? '' : ' Bağlı yeteneklere verdiği bonus da silinir.'}',
        style: MeskType.body14.copyWith(fontWeight: FontWeight.w400),
      ),
      actions: [
        _TextAction('Vazgeç', onPressed: () => Navigator.pop(context, false)),
        _TextAction(
          'Sil',
          color: MeskColors.danger,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Manual entry (§5.8): a new entry, optionally prior experience, for
/// [skillId]; or the entry [entryId] to edit.
class EntryFormScreen extends ConsumerStatefulWidget {
  const EntryFormScreen({
    super.key,
    this.entryId,
    this.skillId,
    this.prior = false,
  });

  final String? entryId;
  final String? skillId;
  final bool prior;

  @override
  ConsumerState<EntryFormScreen> createState() => _EntryFormScreenState();
}

class _EntryFormScreenState extends ConsumerState<EntryFormScreen> {
  /// The edited entry as first loaded; kept while it is saved or deleted.
  TimeEntry? _entry;

  @override
  Widget build(BuildContext context) {
    final editing = widget.entryId != null;
    final title = Text(
      editing ? 'Kaydı düzenle' : 'Yeni kayıt',
      style: MeskType.sectionTitle,
    );
    final skills = ref.watch(skillsProvider).value;
    final settings = ref.watch(settingsProvider).value;
    final entries = editing
        ? ref.watch(entriesProvider).value
        : const <TimeEntry>[];
    if (skills == null || settings == null || entries == null) {
      return Scaffold(appBar: AppBar(title: title));
    }
    if (editing) {
      _entry ??= entries.where((e) => e.id == widget.entryId).firstOrNull;
    }
    final entry = _entry;
    if (editing && entry == null) {
      return Scaffold(
        appBar: AppBar(title: title),
        body: const Center(
          child: Text('Kayıt bulunamadı.', style: MeskType.caption),
        ),
      );
    }

    final keep = entry?.skillId ?? widget.skillId;
    final choices = [
      for (final s in skills)
        if (!s.archived || s.id == keep) s,
    ]..sort((a, b) => trCompare(a.name, b.name));
    if (choices.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: title),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: [
              const Text('Önce bir yetenek ekle.', style: MeskType.caption),
              MeskPrimaryButton(
                label: 'Yeni yetenek',
                icon: Icons.add,
                onPressed: () => context.push('/yetenekler/yeni'),
              ),
            ],
          ),
        ),
      );
    }
    bool offered(String? id) => choices.any((s) => s.id == id);
    final initialSkill = offered(keep)
        ? keep!
        : offered(settings.lastSkillId)
        ? settings.lastSkillId!
        : choices.first.id;
    return _EntryForm(
      title: title,
      entry: entry,
      skills: choices,
      initialSkillId: initialSkill,
      prior: entry?.isPrior ?? widget.prior,
      dayStartHour: settings.dayStartHour,
    );
  }
}

class _EntryForm extends ConsumerStatefulWidget {
  const _EntryForm({
    required this.title,
    required this.entry,
    required this.skills,
    required this.initialSkillId,
    required this.prior,
    required this.dayStartHour,
  });

  final Widget title;

  /// Null for a new entry.
  final TimeEntry? entry;
  final List<Skill> skills;
  final String initialSkillId;
  final bool prior;
  final int dayStartHour;

  @override
  ConsumerState<_EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends ConsumerState<_EntryForm> {
  late final String _id = widget.entry?.id ?? newId();
  late String _skillId = widget.initialSkillId;
  late bool _prior = widget.prior;

  late final LocalDay _initialDay;
  late final TimeOfDay? _initialStart;
  late final (int, int) _initialDuration;
  late LocalDay _day;
  late TimeOfDay? _start;
  late final TextEditingController _hours;
  late final TextEditingController _minutes;
  late final TextEditingController _note;

  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    if (e == null) {
      _initialDay = todayOf(ref.read(clockProvider), widget.dayStartHour);
      _initialStart = null;
      _initialDuration = (0, 0);
    } else {
      final local = e.startedAt.add(Duration(minutes: e.offsetMinutes));
      _initialDay = LocalDay(local.year, local.month, local.day);
      _initialStart = TimeOfDay(hour: local.hour, minute: local.minute);
      _initialDuration = (e.seconds ~/ 3600, e.seconds % 3600 ~/ 60);
    }
    _day = _initialDay;
    _start = _initialStart;
    _hours = TextEditingController(text: '${_initialDuration.$1}');
    _minutes = TextEditingController(text: '${_initialDuration.$2}');
    _note = TextEditingController(text: e?.note);
  }

  @override
  void dispose() {
    _hours.dispose();
    _minutes.dispose();
    _note.dispose();
    super.dispose();
  }

  int _read(TextEditingController c) => int.tryParse(c.text) ?? 0;

  (int, int) get _duration => (_read(_hours), _read(_minutes));

  /// The user's calendar date right now.
  LocalDay _calendarToday() {
    final clock = ref.read(clockProvider);
    final now = clock.nowUtc();
    return dayOfInstant(now, clock.offsetMinutesAt(now), 0);
  }

  TimeEntry _build() {
    final clock = ref.read(clockProvider);
    final now = clock.nowUtc();
    final old = widget.entry;
    final (h, m) = _duration;
    final durationKept = old != null && (h, m) == _initialDuration;
    final seconds = durationKept ? old.seconds : h * 3600 + m * 60;
    final timeKept =
        old != null && _day == _initialDay && _start == _initialStart;

    final DateTime startedAt;
    final int offset;
    if (timeKept) {
      startedAt = old.startedAt;
      offset = old.offsetMinutes;
    } else {
      final start = _start;
      // Without a start time the entry counts from the start of the day.
      final minuteOfDay = start == null
          ? widget.dayStartHour * 60
          : start.hour * 60 + start.minute;
      offset =
          old?.offsetMinutes ??
          clock.offsetMinutesAt(
            localToUtc(_day, minuteOfDay, clock.offsetMinutesAt(now)),
          );
      final at = localToUtc(_day, minuteOfDay, offset);
      // Before today's day-start hour the day has not begun yet.
      startedAt = start == null && at.isAfter(now) ? now : at;
    }
    final endedAt = timeKept && durationKept
        ? old.endedAt
        : startedAt.add(Duration(seconds: seconds));

    final note = _note.text.trim();
    final EntrySource source = _prior
        ? EntrySource.prior
        : old == null || old.isPrior
        ? EntrySource.manual
        : old.source;
    return TimeEntry(
      id: _id,
      skillId: _skillId,
      startedAt: startedAt,
      endedAt: endedAt,
      offsetMinutes: offset,
      seconds: seconds,
      source: source,
      pomodoros: _prior ? 0 : old?.pomodoros ?? 0,
      note: note.isEmpty ? null : note,
    );
  }

  void _leave(String skillId) {
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/yetenekler/$skillId');
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

  Future<void> _save() async {
    final e = _build();
    final error = entryError(
      seconds: e.seconds,
      startedAtUtc: e.startedAt,
      nowUtc: ref.read(clockProvider).nowUtc(),
      prior: e.isPrior,
    );
    setState(() => _error = error);
    if (error != null) return;
    await _run(() async {
      final pipeline = ref.read(pipelineProvider);
      await runAndCelebrate(
        ref,
        () => widget.entry == null
            ? pipeline.saveEntry(e)
            : pipeline.updateEntry(e),
      );
      _leave(e.skillId);
    });
  }

  Future<void> _delete() async {
    final e = widget.entry!;
    if (!await confirmDeleteEntry(context, e)) return;
    await _run(() async {
      await runAndCelebrate(
        ref,
        () => ref.read(pipelineProvider).deleteEntry(e.id),
      );
      _leave(e.skillId);
    });
  }

  Future<void> _pickDate() async {
    final last = _calendarToday().toDateTime();
    final initial = _day.toDateTime();
    final first = DateTime(2000);
    final picked = await showDatePicker(
      context: context,
      locale: const Locale('tr', 'TR'),
      initialDate: initial.isAfter(last) ? last : initial,
      firstDate: initial.isBefore(first) ? initial : first,
      lastDate: last,
    );
    if (picked == null || !mounted) return;
    setState(() => _day = LocalDay(picked.year, picked.month, picked.day));
  }

  Future<void> _pickStart() async {
    final clock = ref.read(clockProvider);
    final now = clock.nowUtc().add(
      Duration(minutes: clock.offsetMinutesAt(clock.nowUtc())),
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: _start ?? TimeOfDay(hour: now.hour, minute: now.minute),
    );
    if (picked == null || !mounted) return;
    setState(() => _start = picked);
  }

  void _step(TextEditingController c, int delta, {int? max}) {
    var v = _read(c) + delta;
    if (v < 0) v = 0;
    if (max != null && v > max) v = max;
    setState(() => c.text = '$v');
  }

  @override
  Widget build(BuildContext context) {
    final start = _start;
    return Scaffold(
      appBar: AppBar(
        title: widget.title,
        actions: [
          if (widget.entry != null)
            IconButton(
              tooltip: 'Kaydı sil',
              icon: const Icon(Icons.delete_outline),
              onPressed: _busy ? null : _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            DropdownButtonFormField<String>(
              key: const ValueKey('entry-skill'),
              initialValue: _skillId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Yetenek'),
              dropdownColor: MeskColors.surface,
              style: MeskType.body15,
              items: [
                for (final s in widget.skills)
                  DropdownMenuItem(value: s.id, child: Text(s.name)),
              ],
              onChanged: (id) => setState(() => _skillId = id ?? _skillId),
            ),
            const SizedBox(height: 16),
            _FieldTile(
              key: const ValueKey('entry-date'),
              label: 'Tarih',
              value: formatDate(_day.toDateTime()),
              icon: Icons.calendar_today_outlined,
              onTap: _pickDate,
            ),
            const SizedBox(height: 24),
            const MeskLabel('Süre'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _NumberStepper(
                  fieldKey: const ValueKey('entry-hours'),
                  controller: _hours,
                  unit: 'saat',
                  maxDigits: 5,
                  onStep: (d) => _step(_hours, d),
                ),
                _NumberStepper(
                  fieldKey: const ValueKey('entry-minutes'),
                  controller: _minutes,
                  unit: 'dakika',
                  maxDigits: 2,
                  step: 5,
                  onStep: (d) => _step(_minutes, d, max: 59),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _FieldTile(
              key: const ValueKey('entry-start'),
              label: 'Başlangıç saati (isteğe bağlı)',
              value: start == null
                  ? 'Seçilmedi'
                  : '${start.hour.toString().padLeft(2, '0')}:'
                        '${start.minute.toString().padLeft(2, '0')}',
              icon: Icons.schedule,
              onTap: _pickStart,
              onClear: start == null
                  ? null
                  : () => setState(() => _start = null),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('entry-note'),
              controller: _note,
              maxLength: 200,
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              style: MeskType.body15,
              decoration: const InputDecoration(
                labelText: 'Not (isteğe bağlı)',
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              key: const ValueKey('entry-prior'),
              contentPadding: EdgeInsets.zero,
              value: _prior,
              activeThumbColor: MeskColors.accent,
              title: const Text('Önceki deneyim', style: MeskType.body15),
              subtitle: _prior
                  ? const Text(priorHint, style: MeskType.caption)
                  : null,
              onChanged: (v) => setState(() => _prior = v),
            ),
            if (_error case final error?) ...[
              const SizedBox(height: 8),
              Text(
                error,
                style: MeskType.caption.copyWith(color: MeskColors.danger),
              ),
            ],
            const SizedBox(height: 24),
            MeskPrimaryButton(label: 'Kaydet', onPressed: _busy ? null : _save),
          ],
        ),
      ),
    );
  }
}

/// A tappable row showing a label and its current value.
class _FieldTile extends StatelessWidget {
  const _FieldTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    value: value,
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          spacing: 12,
          children: [
            Icon(icon, size: 20, color: MeskColors.muted),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                spacing: 2,
                children: [
                  Text(label, style: MeskType.caption),
                  Text(value, style: MeskType.body15),
                ],
              ),
            ),
            if (onClear != null)
              IconButton(
                tooltip: 'Başlangıç saatini kaldır',
                icon: const Icon(Icons.close, size: 20),
                color: MeskColors.muted,
                onPressed: onClear,
              ),
          ],
        ),
      ),
    ),
  );
}

/// A number field between "−" and "+" buttons.
class _NumberStepper extends StatelessWidget {
  const _NumberStepper({
    required this.fieldKey,
    required this.controller,
    required this.unit,
    required this.maxDigits,
    required this.onStep,
    this.step = 1,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String unit;
  final int maxDigits;
  final int step;
  final void Function(int delta) onStep;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: '$step $unit azalt',
        icon: const Icon(Icons.remove),
        color: MeskColors.accent,
        onPressed: () => onStep(-step),
      ),
      SizedBox(
        width: 64,
        child: TextField(
          key: fieldKey,
          controller: controller,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: maxDigits,
          style: MeskType.levelNumber,
          decoration: InputDecoration(counterText: '', helperText: unit),
        ),
      ),
      IconButton(
        tooltip: '$step $unit artır',
        icon: const Icon(Icons.add),
        color: MeskColors.accent,
        onPressed: () => onStep(step),
      ),
    ],
  );
}

/// A text button at least 44 px tall.
class _TextAction extends StatelessWidget {
  const _TextAction(this.label, {required this.onPressed, this.color});

  final String label;
  final VoidCallback onPressed;
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
