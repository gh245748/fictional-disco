import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../data/db.dart';
import '../../data/kv_repo.dart';
import '../../data/presets_repo.dart';
import '../../domain/models.dart';
import '../focus/focus_screen.dart' show orderPresets;
import '../../ui/theme.dart';
import '../../ui/widgets/buttons.dart';

/// The route segment that opens the editor for a new set.
const String newPresetSegment = 'yeni';

/// Deletes the user's preset [id] and forgets it as any skill's last set.
/// Built-in presets are never deleted.
Future<void> deletePreset(MeskDb db, String id) =>
    db.database.transaction((txn) async {
      final presets = PresetsRepo(db);
      final p = await presets.get(id, txn: txn);
      if (p == null || p.builtIn) return;
      await presets.delete(id, txn: txn);
      final kv = KvRepo(db);
      final settings = await kv.settings(txn: txn);
      await kv.saveSettings(
        settings.copyWith(
          lastPresetBySkill: {
            for (final e in settings.lastPresetBySkill.entries)
              if (e.value != id) e.key: e.value,
          },
        ),
        txn: txn,
      );
    });

String presetSummary(TimerPreset p) =>
    '${p.workMinutes} / ${p.shortBreakMinutes} / ${p.longBreakMinutes} dk'
    ' · ${p.roundsBeforeLong} tur';

/// "Pomodoro setleri" (§5.7): the built-in sets, read-only, and the user's
/// own sets.
class PresetsScreen extends ConsumerWidget {
  const PresetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets = ref.watch(presetsProvider).value;
    void open(String id) => context.push('/ayarlar/setler/$id');
    final ordered = orderPresets(presets ?? const []);
    final builtIns = [
      for (final p in ordered)
        if (p.builtIn) p,
    ];
    final mine = [
      for (final p in ordered)
        if (!p.builtIn) p,
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pomodoro setleri', style: MeskType.sectionTitle),
      ),
      body: presets == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                const MeskLabel('Hazır setler'),
                for (final p in builtIns)
                  _PresetRow(preset: p, onTap: () => open(p.id)),
                const SizedBox(height: 24),
                const MeskLabel('Setlerim'),
                if (mine.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Kendi setini ekle: süreleri ve molaları sen belirle.',
                      style: MeskType.caption,
                    ),
                  )
                else
                  for (final p in mine)
                    _PresetRow(preset: p, onTap: () => open(p.id)),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: MeskPrimaryButton(
                    label: 'Yeni set',
                    icon: Icons.add,
                    onPressed: () => open(newPresetSegment),
                  ),
                ),
              ],
            ),
    );
  }
}

class _PresetRow extends StatelessWidget {
  const _PresetRow({required this.preset, required this.onTap});

  final TimerPreset preset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 60),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: MeskColors.divider)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        spacing: 12,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(preset.name, style: MeskType.body15),
                Text(presetSummary(preset), style: MeskType.caption),
              ],
            ),
          ),
          if (preset.builtIn)
            const Text('Hazır', style: MeskType.caption)
          else
            const Icon(Icons.chevron_right, color: MeskColors.muted),
        ],
      ),
    ),
  );
}

/// Creates ([presetId] == [newPresetSegment]) or edits a set. Built-in sets
/// are shown read-only.
class PresetEditScreen extends ConsumerWidget {
  const PresetEditScreen({super.key, required this.presetId});

  final String presetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creating = presetId == newPresetSegment;
    final title = Text(
      creating ? 'Yeni set' : 'Seti düzenle',
      style: MeskType.sectionTitle,
    );
    final presets = ref.watch(presetsProvider).value;
    if (presets == null) return Scaffold(appBar: AppBar(title: title));
    final preset = creating
        ? null
        : presets.where((p) => p.id == presetId).firstOrNull;
    if (!creating && preset == null) {
      return Scaffold(
        appBar: AppBar(title: title),
        body: const Center(
          child: Text('Set bulunamadı.', style: MeskType.caption),
        ),
      );
    }
    return _PresetForm(key: ValueKey(presetId), title: title, preset: preset);
  }
}

class _PresetForm extends ConsumerStatefulWidget {
  const _PresetForm({super.key, required this.title, required this.preset});

  final Widget title;

  /// Null for a new set.
  final TimerPreset? preset;

  @override
  ConsumerState<_PresetForm> createState() => _PresetFormState();
}

class _PresetFormState extends ConsumerState<_PresetForm> {
  /// Spec §5.7 defaults for a new set.
  static const TimerPreset _defaults = TimerPreset(
    '',
    '',
    25,
    5,
    15,
    4,
    true,
    false,
    false,
  );

  late final TimerPreset _initial = widget.preset ?? _defaults;
  late final TextEditingController _name = TextEditingController(
    text: _initial.name,
  );
  late final TextEditingController _work = _number(_initial.workMinutes);
  late final TextEditingController _short = _number(_initial.shortBreakMinutes);
  late final TextEditingController _long = _number(_initial.longBreakMinutes);
  late final TextEditingController _rounds = _number(_initial.roundsBeforeLong);
  late bool _autoBreaks = _initial.autoStartBreaks;
  late bool _autoWork = _initial.autoStartWork;
  String? _error;
  bool _busy = false;

  bool get _readOnly => widget.preset?.builtIn ?? false;

  static TextEditingController _number(int v) =>
      TextEditingController(text: '$v');

  @override
  void dispose() {
    for (final c in [_name, _work, _short, _long, _rounds]) {
      c.dispose();
    }
    super.dispose();
  }

  int _read(TextEditingController c) => int.tryParse(c.text) ?? 0;

  void _leave() {
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/ayarlar/setler');
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      _leave();
    } on Object {
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
    final name = _name.text.trim();
    final preset = TimerPreset(
      widget.preset?.id ?? newId(),
      name,
      _read(_work),
      _read(_short),
      _read(_long),
      _read(_rounds),
      _autoBreaks,
      _autoWork,
      false,
    );
    final error = name.isEmpty ? 'Sete bir ad ver.' : preset.validate();
    setState(() => _error = error);
    if (error != null) return;
    await _run(() => PresetsRepo(ref.read(dbProvider)).put(preset));
  }

  Future<void> _delete() async {
    final p = widget.preset!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MeskColors.surface,
        title: const Text('Set silinsin mi?', style: MeskType.sectionTitle),
        content: Text(
          '"${p.name}" silinecek. Kayıtların etkilenmez.',
          style: MeskType.body14.copyWith(fontWeight: FontWeight.w400),
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
    if (!(ok ?? false) || !mounted) return;
    await _run(() => deletePreset(ref.read(dbProvider), p.id));
  }

  Widget _numberField(Key key, TextEditingController c, String label) =>
      TextField(
        key: key,
        controller: c,
        enabled: !_readOnly,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        maxLength: 3,
        style: MeskType.body15,
        decoration: InputDecoration(labelText: label, counterText: ''),
      );

  Widget _switch(String label, bool value, ValueChanged<bool> onChanged) =>
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: value,
        activeThumbColor: MeskColors.accent,
        title: Text(label, style: MeskType.body15),
        onChanged: _readOnly ? null : onChanged,
      );

  @override
  Widget build(BuildContext context) {
    final editable = widget.preset != null && !_readOnly;
    return Scaffold(
      appBar: AppBar(
        title: widget.title,
        actions: [
          if (editable)
            IconButton(
              tooltip: 'Seti sil',
              icon: const Icon(Icons.delete_outline),
              onPressed: _busy ? null : _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            if (_readOnly)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Hazır set, değiştirilemez.',
                  style: MeskType.caption,
                ),
              ),
            TextField(
              key: const ValueKey('preset-name'),
              controller: _name,
              enabled: !_readOnly,
              maxLength: 40,
              textCapitalization: TextCapitalization.sentences,
              style: MeskType.body15,
              decoration: const InputDecoration(labelText: 'Ad'),
            ),
            const SizedBox(height: 8),
            _numberField(
              const ValueKey('preset-work'),
              _work,
              'Çalışma süresi (dk)',
            ),
            const SizedBox(height: 16),
            _numberField(
              const ValueKey('preset-short'),
              _short,
              'Kısa mola (dk)',
            ),
            const SizedBox(height: 16),
            _numberField(
              const ValueKey('preset-long'),
              _long,
              'Uzun mola (dk)',
            ),
            const SizedBox(height: 16),
            _numberField(
              const ValueKey('preset-rounds'),
              _rounds,
              'Uzun moladan önceki pomodoro sayısı',
            ),
            const SizedBox(height: 8),
            _switch(
              'Molaları otomatik başlat',
              _autoBreaks,
              (v) => setState(() => _autoBreaks = v),
            ),
            _switch(
              'Çalışmayı otomatik başlat',
              _autoWork,
              (v) => setState(() => _autoWork = v),
            ),
            if (_error case final error?) ...[
              const SizedBox(height: 8),
              Text(
                error,
                style: MeskType.caption.copyWith(color: MeskColors.danger),
              ),
            ],
            if (!_readOnly) ...[
              const SizedBox(height: 24),
              MeskPrimaryButton(
                label: 'Kaydet',
                onPressed: _busy ? null : _save,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
