import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mesk/app/router.dart';
import 'package:mesk/data/db.dart';
import 'package:mesk/data/entries_repo.dart';
import 'package:mesk/data/kv_repo.dart';
import 'package:mesk/data/presets_repo.dart';
import 'package:mesk/domain/day.dart';
import 'package:mesk/domain/models.dart';
import 'package:mesk/domain/timer_machine.dart';
import 'package:mesk/features/focus/focus_screen.dart';
import 'package:mesk/features/focus/timer_controller.dart';
import 'package:mesk/features/settings/presets_screen.dart';

import '../support/app_harness.dart';
import '../support/demo_data.dart';
import '../support/golden.dart';

const _busy = 'Önce mevcut oturumu bitir ya da kaydet.';

/// 25/5/15/4 with both auto-start flags on.
const _autoAll = TimerPreset(
  'oto',
  'Otomatik',
  25,
  5,
  15,
  4,
  true,
  true,
  false,
);

Future<TimerState> _storedTimer(WidgetTester t, MeskDb db) async =>
    (await t.runAsync(() => KvRepo(db).timer()))!;

Future<List<TimeEntry>> _newEntries(
  WidgetTester t,
  MeskDb db,
  String skillId,
) async => [
  for (final e in (await t.runAsync(() => EntriesRepo(db).forSkill(skillId)))!)
    if (!e.id.startsWith('$skillId-')) e,
];

/// Lets the clock move on by [d] and the screen's ticker catch up.
Future<void> _wait(WidgetTester t, FixedClock clock, Duration d) async {
  clock.advance(d);
  await t.pump(const Duration(seconds: 1));
  await t.pumpAndSettle();
}

/// A demo database whose stored timer is [timer].
Future<MeskDb> _dbWithTimer(
  WidgetTester t,
  TimerState Function(DateTime now) timer, {
  List<TimerPreset> presets = const [],
}) => openTestDb(
  t,
  seed: (db) async {
    await seedDemo(db);
    for (final p in presets) {
      await PresetsRepo(db).put(p);
    }
    await KvRepo(db).saveTimer(timer(demoClock().utc));
  },
);

/// Klasik on İngilizce: one full pomodoro, a break, then 8 minutes of the
/// second work phase.
TimerState _secondPomodoro(DateTime now) {
  final s = TimerMachine.start(
    mode: TimerMode.pomodoro,
    skillId: 'ingilizce',
    preset: TimerPreset.builtIns.first,
    now: now.subtract(const Duration(minutes: 38)),
  );
  return TimerMachine.startNextPhase(
    s,
    now.subtract(const Duration(minutes: 8)),
  );
}

void main() {
  testWidgets('focus tab starts, pauses and resumes', (t) async {
    final db = await openTestDb(t);
    final clock = demoClock();
    await pumpMeskApp(t, db, '/odak', clock: clock);

    // Last skill and its preset are preselected.
    expect(find.text('İngilizce'), findsOneWidget);
    expect(
      t
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Klasik 25/5'))
          .selected,
      isTrue,
    );
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('Çalışma'), findsOneWidget);
    expect(find.text('1. pomodoro'), findsOneWidget);

    await tapVisible(t, find.text('Başlat'));
    final started = await _storedTimer(t, db);
    expect(started.status, TimerStatus.running);
    expect(started.skillId, 'ingilizce');
    expect(started.preset!.id, 'klasik');
    expect(find.text('Duraklat'), findsOneWidget);
    expect(find.text('Sonraki aşama'), findsOneWidget);
    expect(find.text('Bitir'), findsOneWidget);

    await _wait(t, clock, const Duration(minutes: 1, seconds: 30));
    expect(find.text('23:30'), findsOneWidget);

    await tapVisible(t, find.text('Duraklat'));
    expect((await _storedTimer(t, db)).status, TimerStatus.paused);
    await _wait(t, clock, const Duration(minutes: 5));
    expect(find.text('23:30'), findsOneWidget);
    await tapVisible(t, find.text('Devam'));
    expect((await _storedTimer(t, db)).status, TimerStatus.running);
  });

  testWidgets('skill route preselects the skill', (t) async {
    final db = await openTestDb(t);
    await pumpMeskApp(t, db, '/odak?skill=okuma');
    expect(find.text('Okuma'), findsOneWidget);
    await tapVisible(t, find.text('Serbest'));
    expect(find.text('00:00'), findsOneWidget);
    await tapVisible(t, find.text('Başlat'));
    final started = await _storedTimer(t, db);
    expect(started.skillId, 'okuma');
    expect(started.mode, TimerMode.free);
  });

  testWidgets('one session at a time', (t) async {
    final db = await openTestDb(t);
    await pumpMeskApp(t, db, '/odak');
    await tapVisible(t, find.text('Başlat'));
    expect(find.text(_busy), findsNothing);

    // "Başlat" on another skill while İngilizce runs.
    t.container().read(routerProvider).go('/odak?skill=okuma');
    await t.pumpAndSettle();
    expect(find.text(_busy), findsOneWidget);
    expect((await _storedTimer(t, db)).skillId, 'ingilizce');
    expect(find.text('İngilizce'), findsOneWidget);
    expect(find.text('Başlat'), findsNothing);
  });

  testWidgets('clock jump backwards shows 00:00 not negative', (t) async {
    final db = await openTestDb(t);
    final clock = demoClock();
    await pumpMeskApp(t, db, '/odak', clock: clock);
    await tapVisible(t, find.text('Serbest'));
    await tapVisible(t, find.text('Başlat'));
    expect(find.text('Serbest'), findsWidgets);
    await _wait(t, clock, const Duration(seconds: 5));
    expect(find.text('00:05'), findsOneWidget);

    await _wait(t, clock, const Duration(minutes: -10));
    expect(find.text('00:00'), findsOneWidget);
    expect(find.textContaining('-'), findsNothing);
  });

  testWidgets('finish saves the session through the summary', (t) async {
    final db = await openTestDb(t);
    final clock = demoClock();
    await pumpMeskApp(t, db, '/odak', clock: clock);
    await tapVisible(t, find.text('Başlat'));
    // Work 0-25 and the break 25-30 have passed; the timer waits.
    await _wait(t, clock, const Duration(minutes: 31));
    expect(find.text('Çalışma'), findsOneWidget);
    expect(find.text('Sonraki aşama'), findsOneWidget);

    await tapVisible(t, find.text('Bitir'));
    expect(find.text('Oturum özeti'), findsOneWidget);
    expect(find.text('25 dk'), findsOneWidget);
    expect(find.text('Tamamlanan pomodoro'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('summary-note')), 'Dinleme');
    await tapVisible(t, find.text('Kaydet'));

    final saved = (await _newEntries(t, db, 'ingilizce')).single;
    expect(saved.source, EntrySource.pomodoro);
    expect(saved.seconds, 1500);
    expect(saved.pomodoros, 1);
    expect(saved.note, 'Dinleme');
    expect((await _storedTimer(t, db)).status, TimerStatus.idle);
    expect(find.text('Oturum özeti'), findsNothing);
  });

  testWidgets('summary trims and changes the skill', (t) async {
    final db = await openTestDb(t);
    final clock = demoClock();
    await pumpMeskApp(t, db, '/odak', clock: clock);
    await tapVisible(t, find.text('Serbest'));
    await tapVisible(t, find.text('Başlat'));
    await _wait(t, clock, const Duration(minutes: 90));

    await tapVisible(t, find.text('Bitir'));
    expect(find.text('1 sa 30 dk'), findsOneWidget);
    expect(find.text('Tamamlanan pomodoro'), findsNothing);
    final slider = find.byKey(const ValueKey('summary-trim'));
    await t.drag(slider, const Offset(-2000, 0));
    await t.pumpAndSettle();
    expect(find.text('1 dk'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('summary-skill')));
    await t.pumpAndSettle();
    await t.tap(find.text('Satranç').last);
    await t.pumpAndSettle();
    await tapVisible(t, find.text('Kaydet'));

    expect(await _newEntries(t, db, 'ingilizce'), isEmpty);
    final saved = (await _newEntries(t, db, 'satranc')).single;
    expect(saved.source, EntrySource.free);
    expect(saved.seconds, 60);
  });

  testWidgets('too short shows the snackbar and saves nothing', (t) async {
    final db = await openTestDb(t);
    final clock = demoClock();
    await pumpMeskApp(t, db, '/odak', clock: clock);
    await tapVisible(t, find.text('Başlat'));
    await _wait(t, clock, const Duration(seconds: 40));
    await tapVisible(t, find.text('Bitir'));
    await tapVisible(t, find.text('Kaydet'));
    expect(
      find.text('1 dakikadan kısa oturumlar kaydedilmez.'),
      findsOneWidget,
    );
    expect(await _newEntries(t, db, 'ingilizce'), isEmpty);
    expect((await _storedTimer(t, db)).status, TimerStatus.idle);
  });

  testWidgets('Vazgeç discards the session after asking', (t) async {
    final db = await openTestDb(t);
    final clock = demoClock();
    await pumpMeskApp(t, db, '/odak', clock: clock);
    await tapVisible(t, find.text('Başlat'));
    await _wait(t, clock, const Duration(minutes: 10));
    await tapVisible(t, find.text('Bitir'));
    await tapVisible(t, find.text('Vazgeç'));
    expect(find.text('Oturum kaydedilmeden bitsin mi?'), findsOneWidget);
    await tapVisible(t, find.text('Geri dön'));
    expect((await _storedTimer(t, db)).status, TimerStatus.running);

    await tapVisible(t, find.text('Vazgeç'));
    await tapVisible(t, find.widgetWithText(TextButton, 'Bitir'));
    expect((await _storedTimer(t, db)).status, TimerStatus.idle);
    expect(await _newEntries(t, db, 'ingilizce'), isEmpty);
    expect(find.text('Başlat'), findsOneWidget);
  });

  testWidgets('unattended sheet asks which phases count', (t) async {
    final db = await _dbWithTimer(
      t,
      (now) => TimerMachine.start(
        mode: TimerMode.pomodoro,
        skillId: 'okuma',
        preset: _autoAll,
        now: now.subtract(const Duration(minutes: 90)),
      ),
      presets: [_autoAll],
    );
    final clock = demoClock();
    await pumpMeskApp(t, db, '/odak', clock: clock);

    expect(
      find.text(
        'Sen yokken 2 çalışma aşaması kendiliğinden devam etti. '
        'Hangilerini sayalım?',
      ),
      findsOneWidget,
    );
    // Local (UTC+3) start times of the phases at 30 and 60 minutes.
    expect(find.text('20:00'), findsOneWidget);
    expect(find.text('20:30'), findsOneWidget);
    expect(find.text('25 dk'), findsNWidgets(2));
    await t.tap(find.text('20:00'));
    await t.pumpAndSettle();
    await tapVisible(t, find.text('Tamam'));

    final s = await _storedTimer(t, db);
    expect([for (final r in s.completedWork) r.unattended], [false, false]);
    expect(s.completedWork.last.start, DateTime.utc(2026, 11, 21, 17));

    // Away again for an hour: the answer counted as an interaction, so work
    // from 18:00 (UTC) is attended; 18:30-18:55 ran on its own and the app
    // asks again when it comes back.
    for (final s in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      t.binding.handleAppLifecycleStateChanged(s);
    }
    await t.pump();
    clock.advance(const Duration(minutes: 60));
    for (final s in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      t.binding.handleAppLifecycleStateChanged(s);
    }
    await t.pumpAndSettle();
    expect(find.textContaining('Sen yokken 1 çalışma'), findsOneWidget);
    expect(find.text('21:30'), findsOneWidget);
    await tapVisible(t, find.text('Tamam'));
    expect(
      t.container().read(timerControllerProvider.notifier).unattendedPhases(),
      isEmpty,
    );
  });

  testWidgets('preset validation messages', (t) async {
    final db = await openTestDb(t);
    await pumpMeskApp(t, db, '/ayarlar/setler');
    await tapVisible(t, find.text('Yeni set'));
    await tapVisible(t, find.text('Kaydet'));
    expect(find.text('Sete bir ad ver.'), findsOneWidget);

    await t.enterText(find.byKey(const ValueKey('preset-name')), 'Kısa tur');
    await t.enterText(find.byKey(const ValueKey('preset-work')), '0');
    await tapVisible(t, find.text('Kaydet'));
    expect(
      find.text('Çalışma süresi 1 ile 180 dakika arasında olmalı'),
      findsOneWidget,
    );
    await t.enterText(find.byKey(const ValueKey('preset-work')), '15');
    await t.enterText(find.byKey(const ValueKey('preset-rounds')), '13');
    await tapVisible(t, find.text('Kaydet'));
    expect(
      find.text('Uzun mola öncesi tur sayısı 1 ile 12 arasında olmalı'),
      findsOneWidget,
    );

    await t.enterText(find.byKey(const ValueKey('preset-rounds')), '3');
    await tapVisible(t, find.text('Çalışmayı otomatik başlat'));
    await tapVisible(t, find.text('Kaydet'));
    expect(currentLocation(t), '/ayarlar/setler');
    final saved = (await t.runAsync(() => PresetsRepo(db).all()))!
        .where((p) => !p.builtIn)
        .single;
    expect(saved.name, 'Kısa tur');
    expect(saved.workMinutes, 15);
    expect(saved.roundsBeforeLong, 3);
    expect(saved.autoStartBreaks, isTrue);
    expect(saved.autoStartWork, isTrue);
    expect(find.text('Kısa tur'), findsOneWidget);
  });

  testWidgets('built-in presets are read-only', (t) async {
    final db = await openTestDb(t);
    await pumpMeskApp(t, db, '/ayarlar/setler');
    expect(
      find.text('Kendi setini ekle: süreleri ve molaları sen belirle.'),
      findsOneWidget,
    );
    await tapVisible(t, find.text('Klasik 25/5'));
    expect(currentLocation(t), '/ayarlar/setler/klasik');
    expect(find.text('Hazır set, değiştirilemez.'), findsOneWidget);
    expect(find.text('Kaydet'), findsNothing);
    expect(find.byTooltip('Seti sil'), findsNothing);
    final name = t.widget<TextField>(find.byKey(const ValueKey('preset-name')));
    expect(name.enabled, isFalse);
  });

  testWidgets('user preset edits and deletes', (t) async {
    const mine = TimerPreset(
      'benim',
      'Benim',
      30,
      5,
      20,
      3,
      true,
      false,
      false,
    );
    final db = await openTestDb(
      t,
      seed: (db) async {
        await seedDemo(db);
        await PresetsRepo(db).put(mine);
        final kv = KvRepo(db);
        await kv.saveSettings(
          (await kv.settings()).copyWith(
            lastPresetBySkill: {'okuma': 'benim', 'yazilim': 'derin'},
          ),
        );
      },
    );
    await pumpMeskApp(t, db, '/ayarlar/setler');
    await tapVisible(t, find.text('Benim'));
    await t.enterText(find.byKey(const ValueKey('preset-work')), '45');
    await tapVisible(t, find.text('Kaydet'));
    expect(
      (await t.runAsync(() => PresetsRepo(db).get('benim')))!.workMinutes,
      45,
    );

    await tapVisible(t, find.text('Benim'));
    await tapVisible(t, find.byTooltip('Seti sil'));
    await tapVisible(t, find.widgetWithText(TextButton, 'Sil'));
    expect(currentLocation(t), '/ayarlar/setler');
    expect(await t.runAsync(() => PresetsRepo(db).get('benim')), isNull);
    final settings = (await t.runAsync(() => KvRepo(db).settings()))!;
    expect(settings.lastPresetBySkill, {'yazilim': 'derin'});
  });

  testWidgets('focus running', (t) async {
    final db = await _dbWithTimer(t, _secondPomodoro);
    await pumpPhone(
      t,
      const FocusScreen(),
      overrides: appOverrides(db, demoClock()),
    );
    expect(find.text('17:00'), findsOneWidget);
    expect(find.text('2. pomodoro'), findsOneWidget);
    await expectGolden(t, 'focus_running');
  }, tags: 'golden');

  testWidgets('focus summary', (t) async {
    final db = await _dbWithTimer(t, _secondPomodoro);
    await pumpPhone(
      t,
      const FocusScreen(),
      overrides: appOverrides(db, demoClock()),
    );
    await t.tap(find.text('Bitir'));
    await t.pumpAndSettle();
    expect(find.text('33 dk'), findsOneWidget);
    await expectGolden(t, 'focus_summary');
  }, tags: 'golden');

  testWidgets('presets list', (t) async {
    final db = await openTestDb(t);
    await pumpPhone(
      t,
      const PresetsScreen(),
      overrides: appOverrides(db, demoClock()),
    );
    expect(find.text('Derin çalışma 50/10'), findsOneWidget);
  });
}
