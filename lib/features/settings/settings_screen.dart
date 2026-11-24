import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../data/backup.dart';
import '../../data/kv_repo.dart';
import '../../domain/format.dart';
import '../../domain/models.dart';
import '../../domain/timer_machine.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/buttons.dart';
import '../../ui/widgets/mesk_card.dart';
import '../celebrations/celebration_host.dart';
import '../focus/timer_controller.dart';
import '../habits/habits_controller.dart';
import 'backup_actions.dart';
import 'testflight_reminder.dart';

/// Shown in "Hakkında"; keep in step with `version:` in pubspec.yaml.
const String appVersion = '0.1.0';
const String appBuild = '1';

/// Largest bonus rate the slider offers, in percent.
const int maxBonusPercent = 25;

/// Latest hour the day can start at (the choices are 00:00 to 06:00).
const int maxDayStartHour = 6;

String _hour(int h) => '${h.toString().padLeft(2, '0')}:00';

/// "Son yedek: 3 gün önce" or "Henüz yedek yok".
String lastBackupLabel(DateTime? last, DateTime nowUtc) => last == null
    ? 'Henüz yedek yok'
    : 'Son yedek: ${nowUtc.difference(last).inDays} gün önce';

/// Ayarlar (§5.12): sets, rates, day start, sound, permission, backup, about.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// Last answer of the permission prompt; the app cannot read the status
  /// without asking.
  bool? _permission;
  bool _busy = false;

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _guard(Future<void> Function() action, String failure) async {
    try {
      await action();
    } on Object {
      _snack(failure);
    }
  }

  Future<void> _update(AppSettings Function(AppSettings s) change) {
    final kv = KvRepo(ref.read(dbProvider));
    return _guard(() async {
      await kv.saveSettings(change(await kv.settings()));
    }, 'Kaydedilemedi, tekrar dene.');
  }

  /// Sound and vibration also apply to the habit reminders already planned.
  Future<void> _updateAlerts(AppSettings Function(AppSettings s) change) async {
    await _update(change);
    await ref.read(habitsControllerProvider).rescheduleReminders();
  }

  Future<void> _setDayStart(int hour) => _guard(() async {
    final kv = KvRepo(ref.read(dbProvider));
    await kv.saveSettings((await kv.settings()).copyWith(dayStartHour: hour));
    // Streaks, İrade and achievements follow the new day boundary.
    final habits = ref.read(habitsControllerProvider);
    await runAndCelebrate(ref, ref.read(pipelineProvider).afterHabitChange);
    await habits.rescheduleReminders();
  }, 'Kaydedilemedi, tekrar dene.');

  Future<void> _askPermission() async {
    final granted = await ref.read(notificationsProvider).requestPermission();
    if (mounted) setState(() => _permission = granted);
  }

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(backupActionsProvider).export();
    } on Object {
      _snack('Yedek alınamadı, tekrar dene.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final text = await _pick();
    if (text != null) await _restore(text, undo: false);
  }

  Future<String?> _pick() async {
    if (_busy) return null;
    setState(() => _busy = true);
    try {
      return await ref.read(backupFilePickerProvider).pickBackupJson();
    } on BackupException catch (e) {
      await _showError(e.message);
    } on Object {
      _snack('Yedek geri yüklenemedi, tekrar dene.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    return null;
  }

  /// Confirms with the backup's date and counts, then restores [text]. For
  /// [undo] the text is the safety copy itself.
  Future<void> _restore(String text, {required bool undo}) async {
    if (_busy || !mounted) return;
    setState(() => _busy = true);
    try {
      final actions = ref.read(backupActionsProvider);
      final summary = actions.inspect(text);
      final sessionActive =
          ref.read(timerControllerProvider).status != TimerStatus.idle;
      final ok = await _confirmReplace(summary, sessionActive);
      if (!ok || !mounted) return;
      final outcome = await actions.restore(text);
      ref.invalidate(safetyCopyProvider);
      _snack(
        !outcome.derivedDataUpdated
            ? 'Yedek yüklendi ama bazı hesaplar güncellenemedi. Sorun '
                  'sürerse yedeği bir kez daha geri yükle.'
            : undo
            ? 'Önceki veriye dönüldü. Az önceki verilerinin kopyası '
                  'saklandı; istersen oraya geri dönebilirsin.'
            : 'Yedek geri yüklendi. Önceki verilerinin kopyası uygulama '
                  'klasörüne kaydedildi.',
      );
    } on BackupException catch (e) {
      await _showError(e.message);
    } on Object {
      _snack('Yedek geri yüklenemedi, tekrar dene.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// "21 Kasım 2026 tarihli yedek: 12 yetenek, 1.240 kayıt, 5 alışkanlık."
  static String _describe(BackupSummary b) {
    final at = b.exportedAt;
    final counts =
        '${formatCount(b.skills)} yetenek, ${formatCount(b.entries)} kayıt, '
        '${formatCount(b.habits)} alışkanlık';
    return at == null
        ? 'Tarihi bilinmeyen yedek: $counts.'
        : '${formatDate(at.toLocal())} tarihli yedek: $counts.';
  }

  Future<bool> _confirmReplace(
    BackupSummary summary,
    bool sessionActive,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MeskColors.surface,
        title: const Text('Yedekten geri yükle', style: MeskType.sectionTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Text(
              _describe(summary),
              style: MeskType.body14.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              'Bütün mevcut veriler bu yedekteki verilerle değiştirilecek.',
              style: MeskType.body14.copyWith(fontWeight: FontWeight.w400),
            ),
            if (sessionActive)
              Text(
                'Şu an çalışan zamanlayıcı oturumu da sona erecek.',
                style: MeskType.body14.copyWith(fontWeight: FontWeight.w400),
              ),
            const Text(
              'Geri yüklemeden önce şu anki verilerinin bir kopyası uygulama '
              'klasörüne kaydedilir.',
              style: MeskType.caption,
            ),
          ],
        ),
        actions: [
          MeskTextButton(
            'Vazgeç',
            onPressed: () => Navigator.pop(context, false),
          ),
          MeskTextButton(
            'Geri yükle',
            color: MeskColors.danger,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _showError(String message) {
    if (!mounted) return Future.value();
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MeskColors.surface,
        content: Text(
          message,
          style: MeskType.body14.copyWith(fontWeight: FontWeight.w400),
        ),
        actions: [
          MeskTextButton('Tamam', onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).value;
    final now = ref.watch(clockProvider).nowUtc();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar', style: MeskType.sectionTitle),
      ),
      body: settings == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                const TestflightReminder(bottomGap: 16),
                MeskCard(
                  padding: EdgeInsets.zero,
                  onTap: () => context.push('/ayarlar/setler'),
                  child: const _NavRow('Pomodoro setleri'),
                ),
                const _Gap(),
                const MeskLabel('Bağ bonusu'),
                const SizedBox(height: 8),
                MeskCard(
                  child: _BonusRate(
                    percent: settings.bonusRateBp ~/ 100,
                    onChanged: (p) =>
                        _update((s) => s.copyWith(bonusRateBp: p * 100)),
                  ),
                ),
                const _Gap(),
                const MeskLabel('Günün başlangıcı'),
                const SizedBox(height: 8),
                MeskCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 12,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (var h = 0; h <= maxDayStartHour; h++)
                            ChoiceChip(
                              key: ValueKey('daystart-$h'),
                              label: Text(_hour(h)),
                              selected: settings.dayStartHour == h,
                              side: settings.dayStartHour == h
                                  ? meskSelectedChipSide
                                  : null,
                              onSelected: (_) => _setDayStart(h),
                            ),
                        ],
                      ),
                      const Text(
                        'Gece geç saatte çalışanlar için: bu saatten önceki '
                        'kayıtlar bir önceki güne sayılır.',
                        style: MeskType.caption,
                      ),
                    ],
                  ),
                ),
                const _Gap(),
                const MeskLabel('Bildirimler'),
                const SizedBox(height: 8),
                MeskCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _SwitchRow(
                        keyName: 'sound',
                        label: 'Ses',
                        value: settings.sound,
                        onChanged: (v) =>
                            _updateAlerts((s) => s.copyWith(sound: v)),
                      ),
                      const Divider(),
                      _SwitchRow(
                        keyName: 'vibration',
                        label: 'Titreşim',
                        value: settings.vibration,
                        onChanged: (v) =>
                            _updateAlerts((s) => s.copyWith(vibration: v)),
                      ),
                      const Divider(),
                      _PermissionRow(
                        granted: _permission,
                        onAsk: _askPermission,
                      ),
                    ],
                  ),
                ),
                const _Gap(),
                const MeskLabel('Yedekleme'),
                const SizedBox(height: 8),
                MeskCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 12,
                    children: [
                      Text(
                        lastBackupLabel(settings.lastBackupAt, now),
                        style: MeskType.body15,
                      ),
                      const Text(
                        'Yedek, bütün verilerini tek bir dosyada toplar. '
                        'Dosyayı Dosyalar, iCloud Drive ya da Google Drive\'a '
                        'kaydedebilirsin.',
                        style: MeskType.caption,
                      ),
                      MeskPrimaryButton(
                        label: 'Yedek al',
                        onPressed: _busy ? null : _export,
                      ),
                      MeskSecondaryButton(
                        label: 'Yedekten geri yükle',
                        onPressed: _busy ? null : _import,
                      ),
                      if (ref.watch(safetyCopyProvider).value
                          case final copy?) ...[
                        MeskSecondaryButton(
                          label: 'Geri yüklemeden önceki veriye dön',
                          onPressed: _busy
                              ? null
                              : () => _restore(copy.text, undo: true),
                        ),
                        Text(
                          copy.summary.exportedAt == null
                              ? 'Tarihi bilinmeyen kopya'
                              : '${formatDate(copy.summary.exportedAt!.toLocal())} '
                                    'tarihli kopya',
                          style: MeskType.caption,
                        ),
                      ],
                    ],
                  ),
                ),
                const _Gap(),
                const MeskLabel('Hakkında'),
                const SizedBox(height: 8),
                MeskCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      const Text('Meşk', style: MeskType.sectionTitle),
                      const Text(
                        'Sürüm $appVersion ($appBuild)',
                        style: MeskType.body14,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          'Verilerin bu cihazda durur; telefonunun kendi iCloud ya '
                          'da Google cihaz yedeği açıksa o yedeğe de dahil '
                          'olabilir.',
                          style: MeskType.caption,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: MeskTextButton(
                          'Lisanslar',
                          onPressed: () => showLicensePage(
                            context: context,
                            applicationName: 'Meşk',
                            applicationVersion: appVersion,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _Gap extends StatelessWidget {
  const _Gap();

  @override
  Widget build(BuildContext context) => const SizedBox(height: 24);
}

/// A tappable row with a chevron, at least 56 px tall.
class _NavRow extends StatelessWidget {
  const _NavRow(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 56),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: MeskType.body15)),
          const Icon(Icons.chevron_right, color: MeskColors.faint),
        ],
      ),
    ),
  );
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.keyName,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String keyName;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 56),
    child: MergeSemantics(
      child: Row(
        children: [
          Expanded(child: Text(label, style: MeskType.body15)),
          Switch(
            key: ValueKey('switch-$keyName'),
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    ),
  );
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({required this.granted, required this.onAsk});

  final bool? granted;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    final (status, color) = switch (granted) {
      true => ('Açık', MeskColors.muted),
      false => ('Kapalı · cihaz ayarlarından açabilirsin', MeskColors.muted),
      null => ('Henüz kontrol edilmedi', MeskColors.muted),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Bildirim izni', style: MeskType.body15),
                Text(status, style: MeskType.caption.copyWith(color: color)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          MeskTextButton(
            'İzin iste',
            key: const ValueKey('ask-permission'),
            onPressed: onAsk,
          ),
        ],
      ),
    );
  }
}

/// The bonus slider: %0 to %25 in 1 % steps. Saves when the thumb is
/// released.
class _BonusRate extends StatefulWidget {
  const _BonusRate({required this.percent, required this.onChanged});

  final int percent;
  final ValueChanged<int> onChanged;

  @override
  State<_BonusRate> createState() => _BonusRateState();
}

class _BonusRateState extends State<_BonusRate> {
  late int _value = widget.percent;

  @override
  void didUpdateWidget(_BonusRate old) {
    super.didUpdateWidget(old);
    if (old.percent != widget.percent) _value = widget.percent;
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Expanded(child: Text('Bonus oranı', style: MeskType.body15)),
          Text(
            formatPercent(_value / 100),
            style: MeskType.sectionTitle.copyWith(color: MeskColors.accent),
          ),
        ],
      ),
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          activeTrackColor: MeskColors.accent,
          inactiveTrackColor: MeskColors.track,
          thumbColor: MeskColors.accent,
          overlayColor: const Color(0x22DEC089),
          activeTickMarkColor: Colors.transparent,
          inactiveTickMarkColor: Colors.transparent,
        ),
        child: Semantics(
          label: 'Bonus oranı',
          child: Slider(
            min: 0,
            max: maxBonusPercent.toDouble(),
            divisions: maxBonusPercent,
            value: _value.toDouble(),
            label: formatPercent(_value / 100),
            onChanged: (v) => setState(() => _value = v.round()),
            onChangeEnd: (v) => widget.onChanged(v.round()),
          ),
        ),
      ),
      const Text('Yeni kayıtlardan itibaren geçerli.', style: MeskType.caption),
    ],
  );
}
