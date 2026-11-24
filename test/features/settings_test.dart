import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';
import 'package:mesk/app/providers.dart';
import 'package:mesk/data/backup.dart';
import 'package:mesk/data/db.dart';
import 'package:mesk/data/entries_repo.dart';
import 'package:mesk/data/kv_repo.dart';
import 'package:mesk/data/log_pipeline.dart';
import 'package:mesk/data/skills_repo.dart';
import 'package:mesk/domain/format.dart';
import 'package:mesk/domain/models.dart';
import 'package:mesk/domain/timer_machine.dart';
import 'package:mesk/features/focus/timer_controller.dart';
import 'package:mesk/features/settings/backup_actions.dart';
import 'package:mesk/features/settings/settings_screen.dart';
import 'package:mesk/services/notifications.dart';

import '../support/app_harness.dart';
import '../support/demo_data.dart';
import '../support/golden.dart';

/// Records what would have been shared.
class _FakeShare implements ShareAdapter {
  _FakeShare({this.fail = false, this.status = ShareResultStatus.success});

  final bool fail;
  final ShareResultStatus status;
  final List<(String name, String content)> shared = [];

  @override
  Future<ShareResult> shareJsonFile(String fileName, String content) async {
    if (fail) throw StateError('share failed');
    shared.add((fileName, content));
    return ShareResult('', status);
  }
}

/// Keeps the safety copy in memory; [fail] makes writing it throw.
class _FakeSafetyCopy implements SafetyCopyStore {
  _FakeSafetyCopy({this.fail = false});

  final bool fail;
  final List<String> written = [];

  @override
  Future<void> writeSafetyCopy(String content) async {
    if (fail) throw StateError('disk full');
    written.add(content);
  }
}

class _FakePicker implements BackupFilePicker {
  _FakePicker(this.content);

  final String? content;

  @override
  Future<String?> pickBackupJson() async => content;
}

/// Counts how often the habit-derived data was re-evaluated.
class _CountingPipeline extends LogPipeline {
  _CountingPipeline(super.db, super.clock);

  int habitChanges = 0;

  @override
  Future<PipelineResult> afterHabitChange() {
    habitChanges++;
    return super.afterHabitChange();
  }
}

class _Perm extends FakeNotificationService {
  _Perm({required super.permissionGranted});
}

Future<void> _pump(
  WidgetTester t,
  MeskDb db, {
  _FakeShare? share,
  _FakeSafetyCopy? safetyCopy,
  String? picked,
  FakeNotificationService? notifications,
  LogPipeline? pipeline,
}) async {
  setPhoneView(t);
  await pumpMeskApp(
    t,
    db,
    '/ayarlar',
    notifications: notifications,
    pipeline: pipeline,
    overrides: [
      shareAdapterProvider.overrideWithValue(share ?? _FakeShare()),
      safetyCopyStoreProvider.overrideWithValue(
        safetyCopy ?? _FakeSafetyCopy(),
      ),
      backupFilePickerProvider.overrideWithValue(_FakePicker(picked)),
    ],
  );
}

/// Scrolls [f] into view, then taps it (unlike `tapVisible`, the scroll
/// settles before the tap).
Future<void> _tap(WidgetTester t, Finder f) async {
  await t.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<T> _db<T>(WidgetTester t, Future<T> Function() f) async =>
    (await t.runAsync(f)) as T;

Future<AppSettings> _settings(WidgetTester t, MeskDb db) =>
    _db(t, () => KvRepo(db).settings());

Future<String> _emptyBackup(WidgetTester t) => _db(t, () async {
  final other = await MeskDb.openMemory();
  await KvRepo(other).saveSettings(const AppSettings(onboarded: true));
  final json = await exportBackup(other, DateTime.utc(2026, 11, 1));
  await other.close();
  return json;
});

/// A backup of the demo data, made at [at].
Future<String> _demoBackup(WidgetTester t, DateTime at) => _db(t, () async {
  final other = await MeskDb.openMemory();
  await seedDemo(other);
  final json = await exportBackup(other, at);
  await other.close();
  return json;
});

class _FailingRecompute extends LogPipeline {
  _FailingRecompute(super.db, super.clock);

  @override
  Future<void> recomputeAll() => throw StateError('recompute failed');
}

/// The demo data with a free-mode session running on Okuma.
Future<MeskDb> _dbWithTimer(WidgetTester t) => openTestDb(
  t,
  seed: (db) async {
    await seedDemo(db);
    await KvRepo(db).saveTimer(
      TimerMachine.start(
        mode: TimerMode.free,
        skillId: 'okuma',
        now: demoClock().nowUtc().subtract(const Duration(minutes: 20)),
      ),
    );
  },
);

void main() {
  group('sections', () {
    testWidgets('shows every section with the current values', (t) async {
      final db = await openTestDb(t);
      await _pump(t, db);
      expect(find.text('Ayarlar'), findsWidgets);
      expect(find.text('Pomodoro setleri'), findsOneWidget);
      expect(find.text('%10'), findsOneWidget);
      expect(find.text('Yeni kayıtlardan itibaren geçerli.'), findsOneWidget);
      expect(find.text('Son yedek: 3 gün önce'), findsOneWidget);
      for (final label in [
        trUpper('Günün başlangıcı'),
        trUpper('Bağ bonusu'),
        trUpper('Yedekleme'),
        trUpper('Hakkında'),
        'Ses',
        'Titreşim',
        'Bildirim izni',
        'Yedek al',
        'Yedekten geri yükle',
        'Meşk',
        'Sürüm $appVersion ($appBuild)',
      ]) {
        expect(
          find.text(label, skipOffstage: false),
          findsWidgets,
          reason: label,
        );
      }
    });

    testWidgets('Pomodoro setleri opens the presets page', (t) async {
      final db = await openTestDb(t);
      await _pump(t, db);
      await t.tap(find.text('Pomodoro setleri'));
      await t.pumpAndSettle();
      expect(currentLocation(t), '/ayarlar/setler');
    });

    testWidgets('no backup yet', (t) async {
      final db = await openTestDb(
        t,
        seed: (db) async {
          await seedDemo(db);
          final kv = KvRepo(db);
          await kv.saveSettings(
            (await kv.settings()).copyWith(lastBackupAt: null),
          );
        },
      );
      await _pump(t, db);
      expect(find.text('Henüz yedek yok'), findsOneWidget);
    });

    testWidgets('sound and vibration switches are saved', (t) async {
      final db = await openTestDb(t);
      await _pump(t, db);
      await _tap(t, find.byKey(const ValueKey('switch-sound')));
      await _tap(t, find.byKey(const ValueKey('switch-vibration')));
      final s = await _settings(t, db);
      expect(s.sound, isFalse);
      expect(s.vibration, isFalse);
    });

    testWidgets('sound and vibration changes re-plan habit reminders', (
      t,
    ) async {
      final db = await openTestDb(t);
      final n = FakeNotificationService();
      await _pump(t, db, notifications: n);
      int plans() => n.calls.where((c) => c == 'scheduleHabitReminders').length;
      final before = plans();
      await _tap(t, find.byKey(const ValueKey('switch-sound')));
      expect(plans(), before + 1);
      await _tap(t, find.byKey(const ValueKey('switch-vibration')));
      expect(plans(), before + 2);
    });

    testWidgets('notification permission is asked again and shown', (t) async {
      final db = await openTestDb(t);
      final n = _Perm(permissionGranted: false);
      await _pump(t, db, notifications: n);
      await _tap(t, find.byKey(const ValueKey('ask-permission')));
      expect(n.calls, contains('requestPermission'));
      expect(find.textContaining('Kapalı'), findsOneWidget);

      n.permissionGranted = true;
      await _tap(t, find.byKey(const ValueKey('ask-permission')));
      expect(find.textContaining('Açık'), findsOneWidget);
    });

    testWidgets('licenses page opens', (t) async {
      final db = await openTestDb(t);
      await _pump(t, db);
      await _tap(t, find.text('Lisanslar'));
      expect(find.byType(LicensePage), findsOneWidget);
    });
  });

  group('rates', () {
    testWidgets('bonus rate change applies only to new entries', (t) async {
      final db = await openTestDb(t);
      await _pump(t, db);
      final oldAwards = await _db(t, () => AwardsRepo(db).all());
      expect(oldAwards.map((a) => a.rateBp).toSet(), {1000});

      final slider = t.widget<Slider>(find.byType(Slider));
      expect(slider.min, 0);
      expect(slider.max, 25);
      expect(slider.divisions, 25);
      slider.onChanged!(20);
      slider.onChangeEnd!(20);
      await t.pumpAndSettle();
      expect(find.text('%20'), findsOneWidget);
      expect((await _settings(t, db)).bonusRateBp, 2000);
      // Existing awards keep the rate they were written with.
      expect(await _db(t, () => AwardsRepo(db).all()), oldAwards);

      // A new entry earns the bonus at the new rate.
      final now = DateTime.utc(2026, 11, 21, 17);
      await _db(
        t,
        () => t
            .container()
            .read(pipelineProvider)
            .saveEntry(
              TimeEntry(
                id: 'yeni-okuma',
                skillId: 'okuma',
                startedAt: now,
                endedAt: now.add(const Duration(hours: 1)),
                offsetMinutes: 180,
                seconds: 3600,
                source: EntrySource.manual,
                pomodoros: 0,
              ),
            ),
      );
      final fresh = (await _db(
        t,
        () => AwardsRepo(db).all(),
      )).where((a) => a.entryId == 'yeni-okuma').toList();
      expect(fresh, isNotEmpty);
      expect(fresh.every((a) => a.rateBp == 2000), isTrue);
    });

    testWidgets('day start offers 00:00 to 06:00 and re-runs streaks', (
      t,
    ) async {
      final db = await openTestDb(t);
      final pipeline = _CountingPipeline(db, demoClock());
      await _pump(t, db, pipeline: pipeline);
      for (var h = 0; h <= 6; h++) {
        expect(
          find.byKey(ValueKey('daystart-$h'), skipOffstage: false),
          findsOneWidget,
        );
      }
      expect(find.text('06:00', skipOffstage: false), findsOneWidget);
      expect(find.text('07:00', skipOffstage: false), findsNothing);

      await _tap(t, find.byKey(const ValueKey('daystart-4')));
      expect((await _settings(t, db)).dayStartHour, 4);
      expect(t.container().read(settingsProvider).value!.dayStartHour, 4);
      expect(pipeline.habitChanges, 1);
    });
  });

  group('backup', () {
    testWidgets('export sets lastBackupAt', (t) async {
      final db = await openTestDb(t);
      final share = _FakeShare();
      await _pump(t, db, share: share);
      await _tap(t, find.text('Yedek al'));
      expect(share.shared, hasLength(1));
      expect(share.shared.single.$1, 'mesk-yedek-2026-11-21.json');
      expect(share.shared.single.$2, contains('"format":"mesk-backup"'));
      expect((await _settings(t, db)).lastBackupAt, demoClock().nowUtc());
      expect(find.text('Son yedek: 0 gün önce'), findsOneWidget);
    });

    testWidgets('failed share leaves lastBackupAt alone and says so', (
      t,
    ) async {
      final db = await openTestDb(t);
      final before = (await _settings(t, db)).lastBackupAt;
      await _pump(t, db, share: _FakeShare(fail: true));
      await _tap(t, find.text('Yedek al'));
      expect((await _settings(t, db)).lastBackupAt, before);
      expect(find.text('Yedek alınamadı, tekrar dene.'), findsOneWidget);
    });

    testWidgets('import error shows Turkish message and keeps data', (t) async {
      final db = await openTestDb(t);
      final skillsBefore = await _db(t, () => SkillsRepo(db).all());
      await _pump(t, db, picked: 'bu bir yedek değil');
      await _tap(t, find.text('Yedekten geri yükle'));
      // The file is rejected before the confirmation is shown.
      expect(find.text('Geri yükle'), findsNothing);
      expect(find.text('Yedek dosyası okunamadı.'), findsOneWidget);
      await t.tap(find.text('Tamam'));
      await t.pumpAndSettle();
      expect(await _db(t, () => SkillsRepo(db).all()), skillsBefore);
      expect(find.text('Yedek geri yüklendi.'), findsNothing);
    });

    testWidgets('cancelling the confirmation keeps data', (t) async {
      final db = await openTestDb(t);
      final json = await _emptyBackup(t);
      await _pump(t, db, picked: json);
      await _tap(t, find.text('Yedekten geri yükle'));
      await t.tap(find.text('Vazgeç'));
      await t.pumpAndSettle();
      expect(await _db(t, () => SkillsRepo(db).all()), isNotEmpty);
    });

    testWidgets('no file picked does nothing', (t) async {
      final db = await openTestDb(t);
      await _pump(t, db, picked: null);
      await _tap(t, find.text('Yedekten geri yükle'));
      expect(find.text('Geri yükle'), findsNothing);
      expect(await _db(t, () => SkillsRepo(db).all()), isNotEmpty);
    });

    testWidgets('import replaces data, reschedules reminders, shows snackbar', (
      t,
    ) async {
      final db = await openTestDb(t);
      final json = await _emptyBackup(t);
      final n = FakeNotificationService();
      await _pump(t, db, picked: json, notifications: n);
      await _tap(t, find.text('Yedekten geri yükle'));
      await t.tap(find.text('Geri yükle'));
      await t.pumpAndSettle();

      expect(await _db(t, () => SkillsRepo(db).all()), isEmpty);
      expect(await _db(t, () => EntriesRepo(db).all()), isEmpty);
      expect(n.calls, contains('scheduleHabitReminders'));
      expect(find.textContaining('Yedek geri yüklendi.'), findsOneWidget);
    });

    testWidgets('a dismissed share sheet does not count as a backup', (
      t,
    ) async {
      final db = await openTestDb(t);
      final before = (await _settings(t, db)).lastBackupAt;
      final share = _FakeShare(status: ShareResultStatus.dismissed);
      await _pump(t, db, share: share);
      await _tap(t, find.text('Yedek al'));
      expect(share.shared, hasLength(1));
      expect((await _settings(t, db)).lastBackupAt, before);
      expect(find.text('Son yedek: 3 gün önce'), findsOneWidget);
    });

    testWidgets('an unknown share result still counts (Android)', (t) async {
      final db = await openTestDb(t);
      await _pump(
        t,
        db,
        share: _FakeShare(status: ShareResultStatus.unavailable),
      );
      await _tap(t, find.text('Yedek al'));
      expect((await _settings(t, db)).lastBackupAt, demoClock().nowUtc());
    });

    testWidgets('the confirmation shows the backup date and counts', (t) async {
      final db = await openTestDb(t);
      final json = await _demoBackup(t, DateTime.utc(2026, 11, 1, 10));
      final s = inspectBackup(json);
      await _pump(t, db, picked: json);
      await _tap(t, find.text('Yedekten geri yükle'));
      expect(
        find.text(
          '1 Kasım 2026 tarihli yedek: ${formatCount(s.skills)} yetenek, '
          '${formatCount(s.entries)} kayıt, ${formatCount(s.habits)} alışkanlık.',
        ),
        findsOneWidget,
      );
      expect(s.skills, greaterThan(0));
      expect(find.textContaining('çalışan zamanlayıcı'), findsNothing);
      expect(find.textContaining('kopyası uygulama klasörüne'), findsOneWidget);
    });

    testWidgets('the confirmation warns about a running session', (t) async {
      final db = await _dbWithTimer(t);
      await _pump(t, db, picked: await _emptyBackup(t));
      await _tap(t, find.text('Yedekten geri yükle'));
      expect(
        find.text('Şu an çalışan zamanlayıcı oturumu da sona erecek.'),
        findsOneWidget,
      );
    });

    testWidgets('restore saves a safety copy of the current data first', (
      t,
    ) async {
      final db = await openTestDb(t);
      final copy = _FakeSafetyCopy();
      final skillsBefore = await _db(t, () => SkillsRepo(db).all());
      await _pump(t, db, picked: await _emptyBackup(t), safetyCopy: copy);
      await _tap(t, find.text('Yedekten geri yükle'));
      await t.tap(find.text('Geri yükle'));
      await t.pumpAndSettle();

      expect(await _db(t, () => SkillsRepo(db).all()), isEmpty);
      expect(copy.written, hasLength(1));
      final saved = inspectBackup(copy.written.single);
      expect(saved.skills, skillsBefore.length);
      expect(
        find.text(
          'Yedek geri yüklendi. Önceki verilerinin kopyası uygulama '
          'klasörüne kaydedildi.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('no restore when the safety copy cannot be written', (t) async {
      final db = await openTestDb(t);
      final skillsBefore = await _db(t, () => SkillsRepo(db).all());
      await _pump(
        t,
        db,
        picked: await _emptyBackup(t),
        safetyCopy: _FakeSafetyCopy(fail: true),
      );
      await _tap(t, find.text('Yedekten geri yükle'));
      await t.tap(find.text('Geri yükle'));
      await t.pumpAndSettle();
      expect(await _db(t, () => SkillsRepo(db).all()), skillsBefore);
      expect(find.textContaining('geri yükleme yapılmadı'), findsOneWidget);
    });

    testWidgets('a restored backup counts as a backup of its own date', (
      t,
    ) async {
      final db = await openTestDb(t);
      final json = await _emptyBackup(t); // exportedAt 2026-11-01
      await _pump(t, db, picked: json);
      await _tap(t, find.text('Yedekten geri yükle'));
      await t.tap(find.text('Geri yükle'));
      await t.pumpAndSettle();
      expect((await _settings(t, db)).lastBackupAt, DateTime.utc(2026, 11, 1));
      expect(find.text('Son yedek: 20 gün önce'), findsOneWidget);
    });

    testWidgets('restore ends a running session', (t) async {
      final db = await _dbWithTimer(t);
      await _pump(t, db, picked: await _emptyBackup(t));
      await _tap(t, find.text('Yedekten geri yükle'));
      await t.tap(find.text('Geri yükle'));
      await t.pumpAndSettle();
      expect(
        t.container().read(timerControllerProvider).status,
        TimerStatus.idle,
      );
    });

    testWidgets('a failure after the data was replaced says so', (t) async {
      final db = await openTestDb(t);
      await _pump(
        t,
        db,
        picked: await _emptyBackup(t),
        pipeline: _FailingRecompute(db, demoClock()),
      );
      await _tap(t, find.text('Yedekten geri yükle'));
      await t.tap(find.text('Geri yükle'));
      await t.pumpAndSettle();
      expect(await _db(t, () => SkillsRepo(db).all()), isEmpty);
      expect(find.textContaining('Yedek yüklendi ama'), findsOneWidget);
      expect(find.text('Yedek geri yüklenemedi, tekrar dene.'), findsNothing);
    });

    testWidgets('about says where the data lives', (t) async {
      final db = await openTestDb(t);
      await _pump(t, db);
      expect(
        find.textContaining(
          'iCloud ya da Google cihaz yedeği',
          skipOffstage: false,
        ),
        findsOneWidget,
      );
    });
  });

  group('goldens', () {
    testWidgets('settings', (t) async {
      final db = await openTestDb(t);
      await pumpPhone(
        t,
        const SettingsScreen(),
        overrides: appOverrides(db, demoClock()),
      );
      // Tall enough to show the backup and about sections too.
      t.view.physicalSize = const Size(780, 2400);
      await t.pumpAndSettle();
      await expectGolden(t, 'settings');
    }, tags: 'golden');
  });
}
