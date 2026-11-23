import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../data/log_pipeline.dart';
import '../../domain/format.dart';
import '../../domain/models.dart';
import '../../domain/timer_machine.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/buttons.dart';
import '../celebrations/celebration_host.dart';
import 'timer_controller.dart';

enum SummaryOutcome { saved, tooShort, discarded }

/// The "Oturum özeti" sheet (§5.7) for the active session. Returns what
/// happened, or null when the sheet was dismissed and the session goes on.
Future<SummaryOutcome?> showSessionSummarySheet(BuildContext context) =>
    showModalBottomSheet<SummaryOutcome>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: MeskColors.surface,
      builder: (_) => const SessionSummarySheet(),
    );

class SessionSummarySheet extends ConsumerStatefulWidget {
  const SessionSummarySheet({super.key});

  @override
  ConsumerState<SessionSummarySheet> createState() =>
      _SessionSummarySheetState();
}

class _SessionSummarySheetState extends ConsumerState<SessionSummarySheet> {
  late final TimerMode _mode;
  late final SessionSummary _summary;
  late String _skillId;
  late int _minutes;
  final TextEditingController _note = TextEditingController();
  bool _busy = false;

  /// Whole minutes of work the slider can reach.
  int get _maxMinutes => _summary.workSeconds ~/ 60;

  /// The work time to save: the slider's minutes, or every second when the
  /// slider is at its end.
  int get _seconds =>
      _minutes >= _maxMinutes ? _summary.workSeconds : _minutes * 60;

  @override
  void initState() {
    super.initState();
    _mode = ref.read(timerControllerProvider).mode;
    _summary = ref.read(timerControllerProvider.notifier).preview();
    _skillId = _summary.skillId;
    _minutes = _maxMinutes;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ctl = ref.read(timerControllerProvider.notifier);
    PipelineResult? saved;
    try {
      await runAndCelebrate(ref, () async {
        // Capped at what the sheet shows, though the timer kept running.
        saved = await ctl.finishAndSave(
          skillId: _skillId,
          trimToSeconds: _seconds,
          note: _note.text,
        );
        return saved ?? const PipelineResult([]);
      });
    } on Object {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kaydedilemedi, tekrar dene.')),
      );
      return;
    }
    if (!mounted) return;
    Navigator.pop(
      context,
      saved == null ? SummaryOutcome.tooShort : SummaryOutcome.saved,
    );
  }

  Future<void> _discard() async {
    if (_busy) return;
    if (!_summary.tooShort) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: MeskColors.surface,
          title: const Text(
            'Oturum kaydedilmeden bitsin mi?',
            style: MeskType.sectionTitle,
          ),
          content: Text(
            '${formatDuration(_summary.workSeconds)} çalışma kaydedilmeyecek.',
            style: MeskType.body14.copyWith(fontWeight: FontWeight.w400),
          ),
          actions: [
            MeskTextButton(
              'Geri dön',
              onPressed: () => Navigator.pop(context, false),
            ),
            MeskTextButton(
              'Bitir',
              color: MeskColors.danger,
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      );
      if (!(ok ?? false) || !mounted) return;
    }
    setState(() => _busy = true);
    await ref.read(timerControllerProvider.notifier).discard();
    if (mounted) Navigator.pop(context, SummaryOutcome.discarded);
  }

  @override
  Widget build(BuildContext context) {
    final skills = ref.watch(skillsProvider).value ?? const <Skill>[];
    final choices = [
      for (final s in skills)
        if (!s.archived || s.id == _summary.skillId) s,
    ]..sort((a, b) => trCompare(a.name, b.name));
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        24,
        20,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: const Text('Oturum özeti', style: MeskType.sectionTitle),
          ),
          const SizedBox(height: 16),
          if (choices.any((s) => s.id == _skillId))
            DropdownButtonFormField<String>(
              key: const ValueKey('summary-skill'),
              initialValue: _skillId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Yetenek'),
              dropdownColor: MeskColors.surface,
              style: MeskType.body15,
              items: [
                for (final s in choices)
                  DropdownMenuItem(value: s.id, child: Text(s.name)),
              ],
              onChanged: (id) => setState(() => _skillId = id ?? _skillId),
            ),
          const SizedBox(height: 20),
          _Row(
            label: 'Çalışma süresi',
            value: Text(formatDuration(_seconds), style: MeskType.body15),
          ),
          if (_maxMinutes > 1)
            SliderTheme(
              data: SliderTheme.of(context)
                  .copyWith(tickMarkShape: SliderTickMarkShape.noTickMark),
              child: Slider(
                key: const ValueKey('summary-trim'),
                value: _minutes.toDouble(),
                min: 1,
                max: _maxMinutes.toDouble(),
                divisions: _maxMinutes - 1,
                activeColor: MeskColors.accent,
                inactiveColor: MeskColors.track,
                semanticFormatterCallback: (v) =>
                    formatDuration(v.round() * 60),
                onChanged: (v) => setState(() => _minutes = v.round()),
              ),
            ),
          if (_mode == TimerMode.pomodoro) ...[
            const SizedBox(height: 8),
            _Row(
              label: 'Tamamlanan pomodoro',
              value: Text('${_summary.pomodoros}', style: MeskType.levelNumber),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('summary-note'),
            controller: _note,
            maxLength: 200,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            style: MeskType.body15,
            decoration: const InputDecoration(labelText: 'Not (isteğe bağlı)'),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            spacing: 8,
            children: [
              MeskTextButton('Vazgeç', onPressed: _busy ? null : _discard),
              MeskPrimaryButton(
                label: 'Kaydet',
                onPressed: _busy ? null : _save,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 32),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: MeskType.body14.copyWith(
              color: MeskColors.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        value,
      ],
    ),
  );
}
