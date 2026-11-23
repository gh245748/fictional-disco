import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mesk/data/db.dart';
import 'package:mesk/data/entries_repo.dart';
import 'package:mesk/domain/day.dart';
import 'package:mesk/domain/models.dart';
import 'package:mesk/features/celebrations/cards.dart';
import 'package:mesk/features/entries/entry_form_screen.dart';

import '../support/app_harness.dart';

const _hours = ValueKey('entry-hours');
const _minutes = ValueKey('entry-minutes');

Future<List<TimeEntry>> _entriesOf(
  WidgetTester t,
  MeskDb db,
  String skillId,
) async => (await t.runAsync(() => EntriesRepo(db).forSkill(skillId)))!;

Future<void> _setDuration(WidgetTester t, {int? hours, int? minutes}) async {
  if (hours != null) await t.enterText(find.byKey(_hours), '$hours');
  if (minutes != null) await t.enterText(find.byKey(_minutes), '$minutes');
  await t.pump();
}

/// Picks [hour]:[minute] in the start-time picker through its text mode.
Future<void> _pickStartTime(WidgetTester t, int hour, int minute) async {
  await tapVisible(t, find.byKey(const ValueKey('entry-start')));
  await t.tap(find.byTooltip('Metin giriş moduna geç'));
  await t.pumpAndSettle();
  final fields = find.descendant(
    of: find.byType(Dialog),
    matching: find.byType(TextField),
  );
  await t.enterText(fields.at(0), '$hour');
  await t.enterText(fields.at(1), minute.toString().padLeft(2, '0'));
  await t.tap(find.text('Tamam'));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('manual entry saves and celebrates', (t) async {
    final db = await openTestDb(t);
    await pumpMeskApp(t, db, '/yetenekler/hitabet');
    await tapVisible(t, find.byTooltip('Elle kayıt ekle'));
    expect(currentLocation(t), '/kayit/yeni?skill=hitabet');
    expect(find.text('21 Kasım 2026'), findsOneWidget);
    expect(find.text('Önceki deneyim'), findsOneWidget);

    await _setDuration(t, hours: 1);
    await _pickStartTime(t, 14, 30);
    expect(find.text('14:30'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('entry-note')), 'Sunum');
    await tapVisible(t, find.text('Kaydet'));

    expect(currentLocation(t), '/yetenekler/hitabet');
    final saved = (await _entriesOf(
      t,
      db,
      'hitabet',
    )).where((e) => e.id != 'hitabet-1').single;
    expect(saved.source, EntrySource.manual);
    expect(saved.seconds, 3600);
    expect(saved.pomodoros, 0);
    expect(saved.note, 'Sunum');
    expect(saved.offsetMinutes, 180);
    // 14:30 in Istanbul (UTC+3).
    expect(saved.startedAt, DateTime.utc(2026, 11, 21, 11, 30));
    expect(saved.endedAt, DateTime.utc(2026, 11, 21, 12, 30));

    // The level card comes first: 5 -> 7 in one card.
    final card = find.byType(CelebrationOverlay);
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text('Sv. 5 → 7')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('Yolcu')),
      findsOneWidget,
    );
  });

  testWidgets('entry without start time counts at the start of the day', (
    t,
  ) async {
    final db = await openTestDb(t);
    await pumpMeskApp(t, db, '/yetenekler/hitabet');
    await pushRoute(t, '/kayit/yeni?skill=hitabet');
    await _setDuration(t, minutes: 30);
    await tapVisible(t, find.text('Kaydet'));
    final saved = (await _entriesOf(
      t,
      db,
      'hitabet',
    )).where((e) => e.id != 'hitabet-1').single;
    expect(saved.seconds, 1800);
    // Local midnight of 21 November.
    expect(saved.startedAt, DateTime.utc(2026, 11, 20, 21));
  });

  testWidgets('prior experience creates prior entry', (t) async {
    final db = await openTestDb(t);
    await pumpMeskApp(t, db, '/yetenekler/hitabet');
    await pushRoute(t, '/kayit/yeni?skill=hitabet&prior=1');
    const hint =
        'Seviyene ve hedefine sayılır; bonus, alışkanlık ve günlük toplamlara '
        'sayılmaz.';
    expect(find.text(hint), findsOneWidget);
    expect(
      t.widget<SwitchListTile>(find.byKey(const ValueKey('entry-prior'))).value,
      isTrue,
    );

    await _setDuration(t, hours: 10);
    await tapVisible(t, find.text('Kaydet'));
    final saved = (await _entriesOf(
      t,
      db,
      'hitabet',
    )).where((e) => e.id != 'hitabet-1').single;
    expect(saved.source, EntrySource.prior);
    expect(saved.seconds, 36000);
    expect(saved.pomodoros, 0);
    final awards = (await t.runAsync(() => AwardsRepo(db).forEntry(saved.id)))!;
    expect(awards, isEmpty);
  });

  testWidgets('prior hint follows the switch', (t) async {
    final db = await openTestDb(t);
    await pumpMeskApp(t, db, '/yetenekler/hitabet');
    await pushRoute(t, '/kayit/yeni?skill=hitabet');
    expect(find.textContaining('Seviyene ve hedefine'), findsNothing);
    await tapVisible(t, find.byKey(const ValueKey('entry-prior')));
    expect(find.textContaining('Seviyene ve hedefine'), findsOneWidget);
  });

  testWidgets('future date rejected', (t) async {
    final db = await openTestDb(t);
    await pumpMeskApp(t, db, '/yetenekler/hitabet');
    await pushRoute(t, '/kayit/yeni?skill=hitabet');

    // The picker does not offer days after today.
    await tapVisible(t, find.byKey(const ValueKey('entry-date')));
    await t.tap(find.text('22'));
    await t.tap(find.text('Tamam'));
    await t.pumpAndSettle();
    expect(find.text('21 Kasım 2026'), findsOneWidget);

    // Past days are fine.
    await tapVisible(t, find.byKey(const ValueKey('entry-date')));
    await t.tap(find.text('3'));
    await t.tap(find.text('Tamam'));
    await t.pumpAndSettle();
    expect(find.text('3 Kasım 2026'), findsOneWidget);

    // Today at a time that has not come yet (now is 21:00) is refused.
    await tapVisible(t, find.byKey(const ValueKey('entry-date')));
    await t.tap(find.text('21'));
    await t.tap(find.text('Tamam'));
    await t.pumpAndSettle();
    await _setDuration(t, hours: 1);
    await _pickStartTime(t, 23, 0);
    await tapVisible(t, find.text('Kaydet'));
    expect(find.text('Gelecekteki bir zaman seçilemez.'), findsOneWidget);
    expect(await _entriesOf(t, db, 'hitabet'), hasLength(1));
  });

  testWidgets('zero duration rejected', (t) async {
    final db = await openTestDb(t);
    await pumpMeskApp(t, db, '/yetenekler/hitabet');
    await pushRoute(t, '/kayit/yeni?skill=hitabet');
    await tapVisible(t, find.text('Kaydet'));
    expect(find.text('Süre sıfırdan büyük olmalı.'), findsOneWidget);
    expect(await _entriesOf(t, db, 'hitabet'), hasLength(1));
  });

  testWidgets('edit entry rescales bonus', (t) async {
    final db = await openTestDb(t);
    await pumpMeskApp(t, db, '/yetenekler/okuma');
    await pushRoute(t, '/kayit/okuma-1');
    // 23 h, started 1 September 09:00 local.
    expect(find.text('Kaydı düzenle'), findsOneWidget);
    expect(t.widget<TextField>(find.byKey(_hours)).controller!.text, '23');
    expect(t.widget<TextField>(find.byKey(_minutes)).controller!.text, '0');
    expect(find.text('1 Eylül 2026'), findsOneWidget);
    expect(find.text('09:00'), findsOneWidget);

    await _setDuration(t, hours: 11);
    await tapVisible(t, find.text('Kaydet'));
    final entry = (await t.runAsync(() => EntriesRepo(db).get('okuma-1')))!;
    expect(entry.seconds, 39600);
    expect(entry.startedAt, DateTime.utc(2026, 9, 1, 6));
    expect(entry.source, EntrySource.manual);
    final award = (await t.runAsync(
      () => AwardsRepo(db).get('award-okuma-ingilizce'),
    ))!;
    expect(award.seconds, 3960);
    expect(currentLocation(t), '/yetenekler/okuma');
  });

  testWidgets('editing only the note keeps the exact time', (t) async {
    final db = await openTestDb(t);
    await t.runAsync(() async {
      final repo = EntriesRepo(db);
      final e = (await repo.get('ingilizce-2'))!;
      expect(e.seconds, 1200);
    });
    await pumpMeskApp(t, db, '/yetenekler/ingilizce');
    await pushRoute(t, '/kayit/ingilizce-2');
    await t.enterText(find.byKey(const ValueKey('entry-note')), 'Kelime');
    await tapVisible(t, find.text('Kaydet'));
    final e = (await t.runAsync(() => EntriesRepo(db).get('ingilizce-2')))!;
    expect(e.note, 'Kelime');
    expect(e.seconds, 1200);
    expect(e.source, EntrySource.pomodoro);
    expect(e.pomodoros, 1);
    expect(e.startedAt, DateTime.utc(2026, 11, 21, 16, 30));
  });

  testWidgets('deleting from the editor removes entry and bonus', (t) async {
    final db = await openTestDb(t);
    await pumpMeskApp(t, db, '/yetenekler/okuma');
    await pushRoute(t, '/kayit/okuma-1');
    await tapVisible(t, find.byTooltip('Kaydı sil'));
    expect(find.text('Kayıt silinsin mi?'), findsOneWidget);
    await t.tap(find.text('Sil'));
    await t.pumpAndSettle();
    expect(await t.runAsync(() => EntriesRepo(db).get('okuma-1')), isNull);
    expect(
      await t.runAsync(() => AwardsRepo(db).get('award-okuma-ingilizce')),
      isNull,
    );
    expect(currentLocation(t), '/yetenekler/okuma');
  });

  test('entryError checks duration and future instants', () {
    final now = DateTime.utc(2026, 11, 21, 18);
    expect(
      entryError(seconds: 0, startedAtUtc: now, nowUtc: now),
      'Süre sıfırdan büyük olmalı.',
    );
    expect(
      entryError(
        seconds: 60,
        startedAtUtc: now.add(const Duration(minutes: 1)),
        nowUtc: now,
      ),
      'Gelecekteki bir zaman seçilemez.',
    );
    expect(entryError(seconds: 60, startedAtUtc: now, nowUtc: now), isNull);
  });

  test('localToUtc applies the offset', () {
    expect(
      localToUtc(const LocalDay(2026, 11, 21), 14 * 60 + 30, 180),
      DateTime.utc(2026, 11, 21, 11, 30),
    );
    expect(
      localToUtc(const LocalDay(2026, 3, 1), 60, -300),
      DateTime.utc(2026, 3, 1, 6),
    );
  });
}
