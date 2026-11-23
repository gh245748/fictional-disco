import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../domain/format.dart';
import '../../domain/models.dart';
import '../../domain/timer_machine.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/buttons.dart';
import '../../ui/widgets/progress_ring.dart';
import 'session_summary_sheet.dart';
import 'timer_controller.dart';
import 'unattended_sheet.dart';

const String busyMessage = 'Önce mevcut oturumu bitir ya da kaydet.';
const String tooShortMessage = '1 dakikadan kısa oturumlar kaydedilmez.';

/// "25:00", "03:07" or, from an hour, "1:05:03". Negative values show 0.
String formatTimer(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  String two(int n) => n.toString().padLeft(2, '0');
  final h = s ~/ 3600;
  final m = s % 3600 ~/ 60;
  final rest = '${two(m)}:${two(s % 60)}';
  return h == 0 ? rest : '$h:$rest';
}

String phaseLabel(TimerMode mode, TimerPhase phase) => mode == TimerMode.free
    ? 'Serbest'
    : switch (phase) {
        TimerPhase.work => 'Çalışma',
        TimerPhase.shortBreak => 'Kısa mola',
        TimerPhase.longBreak => 'Uzun mola',
      };

/// Built-ins first in their fixed order, then the user's sets by name.
List<TimerPreset> orderPresets(Iterable<TimerPreset> presets) {
  final builtInIds = [for (final p in TimerPreset.builtIns) p.id];
  return [
    for (final id in builtInIds) ...presets.where((p) => p.id == id),
    ...presets.where((p) => !builtInIds.contains(p.id)).toList()
      ..sort((a, b) => trCompare(a.name, b.name)),
  ];
}

/// The Odak tab (§5.7, §5.12): a ring with the phase and its time, skill and
/// preset selectors and the controls. [skillId] preselects a skill (from a
/// skill's "Başlat").
class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key, this.skillId});

  final String? skillId;

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  late final AppLifecycleListener _lifecycle;
  Timer? _ticker;
  int _shownSecond = 0;
  bool _checkingIn = false;
  bool _reconciling = false;

  /// The user's picks before starting; null means the remembered default.
  String? _skillId;
  String? _presetId;
  TimerMode _mode = TimerMode.pomodoro;

  TimerController get _ctl => ref.read(timerControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    _skillId = widget.skillId;
    _lifecycle = AppLifecycleListener(onResume: _checkIn);
    // The display is derived from the clock; this only redraws it.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkIn();
      if (mounted) _warnIfBusy(widget.skillId);
    });
  }

  @override
  void didUpdateWidget(FocusScreen old) {
    super.didUpdateWidget(old);
    final requested = widget.skillId;
    if (requested != null && requested != old.skillId) {
      _skillId = requested;
      _presetId = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _warnIfBusy(requested);
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  void _tick() {
    final now = ref.read(clockProvider).nowUtc();
    final s = ref.read(timerControllerProvider);
    if (s.status != TimerStatus.running) return;
    // A phase ended: store it and reschedule notifications.
    if (!_reconciling && TimerMachine.advance(s, now) != s) {
      _reconciling = true;
      _ctl.reconcile().catchError((Object _) {}).whenComplete(() {
        _reconciling = false;
      });
    }
    final second = now.millisecondsSinceEpoch ~/ 1000;
    if (second != _shownSecond) setState(() => _shownSecond = second);
  }

  /// Reloads the timer and asks about phases that ran without the user.
  Future<void> _checkIn() async {
    if (_checkingIn) return;
    _checkingIn = true;
    try {
      await _ctl.reconcile();
      if (!mounted) return;
      final phases = _ctl.unattendedPhases();
      if (phases.isEmpty) return;
      final kept = await showUnattendedSheet(
        context,
        phases: phases,
        clock: ref.read(clockProvider),
      );
      await _ctl.keepUnattended(kept);
    } on Object {
      // The stored timer stays as it was; the next check-in retries.
    } finally {
      _checkingIn = false;
    }
  }

  void _say(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  bool get _active =>
      ref.read(timerControllerProvider).status != TimerStatus.idle;

  /// "Aynı anda tek oturum": a request for another skill while one runs.
  void _warnIfBusy(String? skillId) {
    if (skillId == null) return;
    final s = ref.read(timerControllerProvider);
    if (s.status != TimerStatus.idle && s.skillId != skillId) {
      _say(busyMessage);
    }
  }

  void _haptic() {
    if (ref.read(settingsProvider).value?.vibration ?? true) {
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on TimerBusyException {
      if (mounted) _say(busyMessage);
    } on Object {
      if (mounted) _say('Zamanlayıcı güncellenemedi, tekrar dene.');
    }
  }

  Future<void> _start(String skillId, String? presetId) => _run(() async {
    if (_active) throw const TimerBusyException();
    _haptic();
    await _ctl.start(
      mode: _mode,
      skillId: skillId,
      presetId: _mode == TimerMode.pomodoro ? presetId : null,
    );
  });

  Future<void> _finish() async {
    _haptic();
    await _checkIn();
    if (!mounted || !_active) return;
    final outcome = await showSessionSummarySheet(context);
    if (!mounted) return;
    if (outcome == SummaryOutcome.tooShort) _say(tooShortMessage);
  }

  Future<void> _pickSkill(List<Skill> choices, String selected) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: MeskColors.surface,
      builder: (context) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          for (final s in choices)
            ListTile(
              minTileHeight: 48,
              title: Text(s.name, style: MeskType.body15),
              trailing: s.id == selected
                  ? const Icon(Icons.check, color: MeskColors.accent)
                  : null,
              onTap: () => Navigator.pop(context, s.id),
            ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _skillId = picked;
      _presetId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final timer = ref.watch(timerControllerProvider);
    final settings = ref.watch(settingsProvider).value;
    final skills = ref.watch(skillsProvider).value;
    final presets = ref.watch(presetsProvider).value;
    if (settings == null || skills == null || presets == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final active = timer.status != TimerStatus.idle;
    final choices = [
      for (final s in skills)
        if (!s.archived || s.id == timer.skillId) s,
    ]..sort((a, b) => trCompare(a.name, b.name));

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            const Text('Odak', style: MeskType.screenTitle),
            if (!active && choices.isEmpty)
              _empty()
            else
              ..._content(timer, settings, choices, orderPresets(presets)),
          ],
        ),
      ),
    );
  }

  Widget _empty() => Padding(
    padding: const EdgeInsets.only(top: 48),
    child: Column(
      spacing: 16,
      children: [
        const Text(
          'Odaklanmak için önce bir yetenek ekle.',
          textAlign: TextAlign.center,
          style: MeskType.caption,
        ),
        MeskPrimaryButton(
          label: 'Yeni yetenek',
          icon: Icons.add,
          onPressed: () => context.push('/yetenekler/yeni'),
        ),
      ],
    ),
  );

  List<Widget> _content(
    TimerState timer,
    AppSettings settings,
    List<Skill> choices,
    List<TimerPreset> presets,
  ) {
    final active = timer.status != TimerStatus.idle;
    bool offered(String? id) => choices.any((s) => s.id == id);
    final skillId = active
        ? timer.skillId!
        : offered(_skillId)
        ? _skillId!
        : offered(settings.lastSkillId)
        ? settings.lastSkillId!
        : choices.first.id;
    final skillName =
        choices.where((s) => s.id == skillId).firstOrNull?.name ?? '';

    TimerPreset? byId(String? id) =>
        presets.where((p) => p.id == id).firstOrNull;
    final preset = active
        ? timer.preset
        : byId(_presetId) ??
              byId(settings.lastPresetBySkill[skillId]) ??
              presets.firstOrNull;
    final mode = active ? timer.mode : _mode;

    return [
      const SizedBox(height: 24),
      Center(
        child: _Dial(timer: timer, idlePreset: preset, idleMode: mode),
      ),
      const SizedBox(height: 28),
      _controls(timer, skillId, preset),
      const SizedBox(height: 32),
      const MeskLabel('Yetenek'),
      _SelectorTile(
        value: skillName,
        onTap: active
            ? () => _say(busyMessage)
            : () => _pickSkill(choices, skillId),
      ),
      const SizedBox(height: 20),
      const MeskLabel('Mod'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: [
          for (final (m, label) in const [
            (TimerMode.pomodoro, 'Pomodoro'),
            (TimerMode.free, 'Serbest'),
          ])
            ChoiceChip(
              label: Text(label),
              selected: mode == m,
              side: mode == m ? meskSelectedChipSide : null,
              onSelected: (_) =>
                  active ? _say(busyMessage) : setState(() => _mode = m),
            ),
        ],
      ),
      if (mode == TimerMode.pomodoro) ...[
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(child: MeskLabel('Ayar seti')),
            IconButton(
              tooltip: 'Setleri düzenle',
              icon: const Icon(Icons.tune, size: 20),
              color: MeskColors.muted,
              onPressed: () => context.push('/ayarlar/setler'),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final p in active && preset != null ? [preset] : presets)
              ChoiceChip(
                label: Text(p.name),
                selected: p.id == preset?.id,
                side: p.id == preset?.id ? meskSelectedChipSide : null,
                onSelected: (_) => active
                    ? _say(busyMessage)
                    : setState(() => _presetId = p.id),
              ),
          ],
        ),
      ],
    ];
  }

  Widget _controls(TimerState timer, String skillId, TimerPreset? preset) {
    final pomodoro = timer.mode == TimerMode.pomodoro;
    final onBreak = timer.phase != TimerPhase.work;
    final buttons = <Widget>[
      ...switch (timer.status) {
        TimerStatus.idle => [
          MeskPrimaryButton(
            label: 'Başlat',
            icon: Icons.play_arrow,
            onPressed: () => _start(skillId, preset?.id),
          ),
        ],
        TimerStatus.running => [
          MeskPrimaryButton(
            label: 'Duraklat',
            icon: Icons.pause,
            onPressed: () => _run(() async {
              _haptic();
              await _ctl.pause();
            }),
          ),
        ],
        TimerStatus.paused => [
          MeskPrimaryButton(
            label: 'Devam',
            icon: Icons.play_arrow,
            onPressed: () => _run(() async {
              _haptic();
              await _ctl.resume();
            }),
          ),
        ],
        TimerStatus.waiting => [
          MeskPrimaryButton(
            label: 'Sonraki aşama',
            icon: Icons.skip_next,
            onPressed: () => _run(_ctl.startNextPhase),
          ),
        ],
      },
      if (pomodoro && timer.status != TimerStatus.idle) ...[
        if (onBreak)
          MeskSecondaryButton(
            label: 'Molayı atla',
            onPressed: () => _run(_ctl.skipPhase),
          )
        else if (timer.status != TimerStatus.waiting)
          MeskSecondaryButton(
            label: 'Sonraki aşama',
            onPressed: () => _run(_ctl.startNextPhase),
          ),
      ],
      if (timer.status != TimerStatus.idle)
        MeskSecondaryButton(label: 'Bitir', onPressed: _finish),
    ];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: buttons,
    );
  }
}

/// The 240 px ring with the phase, its time and the pomodoro number.
class _Dial extends ConsumerWidget {
  const _Dial({
    required this.timer,
    required this.idlePreset,
    required this.idleMode,
  });

  final TimerState timer;

  /// What starting now would use; shown while idle.
  final TimerPreset? idlePreset;
  final TimerMode idleMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.read(clockProvider).nowUtc();
    final String label;
    final String time;
    final double progress;
    String? counter;
    var work = true;
    if (timer.status == TimerStatus.idle) {
      final pomodoro = idleMode == TimerMode.pomodoro && idlePreset != null;
      label = phaseLabel(idleMode, TimerPhase.work);
      time = formatTimer(pomodoro ? idlePreset!.workMinutes * 60 : 0);
      progress = 0;
      if (pomodoro) counter = '1. pomodoro';
    } else if (timer.mode == TimerMode.free) {
      final elapsed = TimerMachine.elapsedInPhase(timer, now);
      label = phaseLabel(TimerMode.free, timer.phase);
      time = formatTimer(elapsed);
      progress = elapsed % 3600 / 3600;
    } else {
      // Display only; the screen's ticker stores the advanced state.
      final view = TimerMachine.advance(timer, now);
      final preset = view.preset!;
      final length =
          switch (view.phase) {
            TimerPhase.work => preset.workMinutes,
            TimerPhase.shortBreak => preset.shortBreakMinutes,
            TimerPhase.longBreak => preset.longBreakMinutes,
          } *
          60;
      work = view.phase == TimerPhase.work;
      label = phaseLabel(TimerMode.pomodoro, view.phase);
      final remaining = TimerMachine.remainingInPhase(view, now) ?? length;
      time = formatTimer(remaining);
      progress = view.status == TimerStatus.waiting
          ? 0
          : (length - remaining) / length;
      final full = view.completedWork.where((r) => r.full).length;
      final n = work ? full + 1 : (full < 1 ? 1 : full);
      counter = '$n. pomodoro';
    }
    final paused = timer.status == TimerStatus.paused;
    return Semantics(
      container: true,
      label: [label, time, ?counter, if (paused) 'Duraklatıldı'].join(', '),
      excludeSemantics: true,
      child: ProgressRing(
        value: progress,
        size: 240,
        strokeWidth: 3,
        color: work ? MeskColors.accent : MeskColors.muted,
        child: SizedBox(
          width: 196,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: MeskType.body14.copyWith(color: MeskColors.muted),
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(time, style: MeskType.bigNumber),
              ),
              const SizedBox(height: 10),
              Text(
                paused ? 'Duraklatıldı' : counter ?? '',
                style: MeskType.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A row showing the selected value, opening a picker on tap.
class _SelectorTile extends StatelessWidget {
  const _SelectorTile({required this.value, required this.onTap});

  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Yetenek',
    value: value,
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            Expanded(child: Text(value, style: MeskType.body15)),
            const Icon(Icons.expand_more, color: MeskColors.muted),
          ],
        ),
      ),
    ),
  );
}
