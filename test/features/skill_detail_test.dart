import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mesk/data/db.dart';
import 'package:mesk/data/entries_repo.dart';
import 'package:mesk/data/kv_repo.dart';
import 'package:mesk/data/log_pipeline.dart';
import 'package:mesk/data/skills_repo.dart';
import 'package:mesk/domain/day.dart';
import 'package:mesk/domain/models.dart';
import 'package:mesk/domain/stats.dart';
import 'package:mesk/features/skills/skill_detail_screen.dart';
import 'package:mesk/features/skills/title_path_screen.dart';
import 'package:mesk/ui/theme.dart';
import 'package:mesk/ui/widgets/weekly_chart.dart';

import '../support/app_harness.dart';
import '../support/demo_data.dart';
import '../support/golden.dart';

TimeEntry _entry(
  String id,
  DateTime startedAt,
  int seconds, {
  String skillId = 'ney',
  EntrySource source = EntrySource.manual,
  int offsetMinutes = 180,
}) => TimeEntry(
  id: id,
  skillId: skillId,
  startedAt: startedAt,
  endedAt: startedAt.add(Duration(seconds: seconds)),
  offsetMinutes: offsetMinutes,
  seconds: seconds,
  source: source,
  pomodoros: 0,
);

/// One skill, "Ney", with [hours] of prior experience.
Future<void> Function(MeskDb) _neyWith(int hours) => (db) async {
  await SkillsRepo(db).put(
    Skill(
      id: 'ney',
      name: 'Ney',
      primary: Stat.yaraticilik,
      createdAt: DateTime.utc(2026),
    ),
  );
  await EntriesRepo(db).put(
    _entry(
      'ney-1',
      DateTime.utc(2026, 1, 2, 6),
      hours * 3600,
      source: EntrySource.prior,
    ),
  );
  await KvRepo(db).saveSettings(const AppSettings(onboarded: true));
  await LogPipeline(db, demoClock()).recomputeAll();
};

Color? _color(WidgetTester t, String text) =>
    t.widget<Text>(find.text(text)).style?.color;

void main() {
  testWidgets('detail shows level, title, remaining', (t) async {
    final db = await openTestDb(t);
    await pumpMeskApp(t, db, '/yetenekler/yazilim');
    expect(find.text('Yazılım'), findsOneWidget);
    expect(find.text('Sv. 47'), findsOneWidget);
    expect(find.text('Rehber'), findsOneWidget);
    expect(find.text('KALFALIK'), findsOneWidget);
    expect(find.text('4 sa 41 dk kaldı'), findsOneWidget);
    expect(find.text('161 sa tecrübe · 161 sa gerçek'), findsOneWidget);
    expect(find.text('Sıradaki unvan: Öncü'), findsOneWidget);
    expect(find.text('Başlat'), findsOneWidget);
    // Linked skills as chips.
    for (final name in ['İngilizce', 'Okuma', 'Satranç']) {
      expect(
        find.descendant(of: find.byType(ActionChip), matching: find.text(name)),
        findsOneWidget,
      );
    }
  });

  testWidgets('experience and real time differ with bonus', (t) async {
    final db = await openTestDb(t);
    await pumpMeskApp(t, db, '/yetenekler/ingilizce');
    expect(find.text('Sv. 23'), findsOneWidget);
    expect(find.text('Marifetli'), findsOneWidget);
    expect(find.text('29,4 sa tecrübe · 27,1 sa gerçek'), findsOneWidget);
  });

  testWidgets('hidden tier name hidden before reached', (t) async {
    final db = await openTestDb(t, seed: _neyWith(1500));
    await pumpMeskApp(t, db, '/yetenekler/ney');
    expect(find.text('Sv. 99'), findsOneWidget);
    expect(find.text('Pir'), findsOneWidget);
    expect(find.text('Sıradaki: ???'), findsOneWidget);
    // 500 of the 1500 h between level 99 and 2500 h.
    expect(find.text('%33 · 1.000 sa kaldı'), findsOneWidget);
    expect(find.textContaining('Çınar'), findsNothing);

    await tapVisible(t, find.text('Unvan yolu'));
    expect(currentLocation(t), '/yetenekler/ney/unvanlar');
    await t.scrollUntilVisible(find.text('Pir'), 400);
    await t.pumpAndSettle();
    expect(find.text('???'), findsNWidgets(3));
    expect(find.textContaining('Çınar'), findsNothing);
  });

  testWidgets('hidden tier name revealed once reached', (t) async {
    final db = await openTestDb(t, seed: _neyWith(2600));
    await pumpMeskApp(t, db, '/yetenekler/ney');
    expect(find.text('PİR · ÇINAR'), findsOneWidget);
    expect(find.text('Sıradaki: ???'), findsOneWidget);
    expect(find.textContaining('Zümrüdüanka'), findsNothing);

    await tapVisible(t, find.text('Unvan yolu'));
    await t.scrollUntilVisible(find.text('Çınar'), 400);
    await t.pumpAndSettle();
    expect(find.text('???'), findsNWidgets(2));
    expect(_color(t, 'Çınar'), MeskColors.text);
  });

  testWidgets('title path hides hidden tiers before level 99', (t) async {
    final db = await openTestDb(t);
    await pumpMeskApp(t, db, '/yetenekler/ingilizce/unvanlar');
    await t.scrollUntilVisible(find.text('Pir'), 400);
    await t.pumpAndSettle();
    await t.drag(find.byType(Scrollable).first, const Offset(0, -2000));
    await t.pumpAndSettle();
    expect(find.text('Pir'), findsOneWidget);
    expect(find.text('???'), findsNothing);
  });

  testWidgets('title path shows reached titles bright and future faint', (
    t,
  ) async {
    final db = await openTestDb(t);
    await pumpMeskApp(t, db, '/yetenekler/ingilizce/unvanlar');
    expect(find.text('Unvan yolu'), findsOneWidget);
    expect(find.text('UYANIŞ'), findsOneWidget);
    expect(_color(t, 'Meraklı'), MeskColors.text);
    // Level rows were written by the demo seed at the demo clock's time.
    expect(find.text('21 Kasım 2026'), findsWidgets);
    await t.scrollUntilVisible(find.text('Marifetli'), 300);
    await t.pumpAndSettle();
    expect(_color(t, 'Marifetli'), MeskColors.text); // current level
    expect(_color(t, 'Yetkin'), MeskColors.faint);
    expect(_color(t, 'Kalfa'), MeskColors.faint);
  });

  testWidgets('Başlat opens focus with the skill', (t) async {
    final db = await openTestDb(t);
    await pumpMeskApp(t, db, '/yetenekler/yazilim');
    await tapVisible(t, find.text('Başlat'));
    expect(currentLocation(t), '/odak?skill=yazilim');
  });

  testWidgets('Hedef koy opens the goal page', (t) async {
    final db = await openTestDb(t);
    await pumpMeskApp(t, db, '/yetenekler/yazilim');
    await tapVisible(t, find.text('Hedef koy'));
    expect(currentLocation(t), '/hedef/yazilim');
  });

  testWidgets('entry list shows rows and opens the editor', (t) async {
    final db = await openTestDb(t);
    await pumpMeskApp(t, db, '/yetenekler/hitabet');
    final row = find.byKey(const ValueKey('entry-hitabet-1'));
    await t.scrollUntilVisible(row, 300);
    await t.pumpAndSettle();
    expect(
      find.descendant(of: row, matching: find.text('2 Nisan 2026')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.text('Elle')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.text('1 sa 24 dk')),
      findsOneWidget,
    );
    await tapVisible(t, row);
    expect(currentLocation(t), '/kayit/hitabet-1');
  });

  testWidgets('swiping an entry deletes it after confirmation', (t) async {
    final db = await openTestDb(t);
    await pumpMeskApp(t, db, '/yetenekler/hitabet');
    final row = find.byKey(const ValueKey('entry-hitabet-1'));
    await t.scrollUntilVisible(row, 300);
    await t.pumpAndSettle();

    await t.drag(row, const Offset(-500, 0));
    await t.pumpAndSettle();
    expect(find.text('Kayıt silinsin mi?'), findsOneWidget);
    await t.tap(find.text('Vazgeç'));
    await t.pumpAndSettle();
    expect(row, findsOneWidget);

    await t.drag(row, const Offset(-500, 0));
    await t.pumpAndSettle();
    await t.tap(find.text('Sil'));
    await t.pumpAndSettle();
    expect(await t.runAsync(() => EntriesRepo(db).get('hitabet-1')), isNull);
    expect(row, findsNothing);
    expect(find.text('Henüz kayıt yok. İlk çalışmanı ekle.'), findsOneWidget);
  });

  test('weekly totals: last 12 Monday weeks, prior excluded', () {
    const today = LocalDay(2026, 11, 21); // Saturday
    final weeks = lastWeeksTrackedSeconds(
      [
        // Monday 16 Nov, 01:00 local: this week.
        _entry('a', DateTime.utc(2026, 11, 15, 22), 600),
        // Sunday 15 Nov, 23:00 local: last week.
        _entry('b', DateTime.utc(2026, 11, 15, 20), 300),
        // Prior experience never counts.
        _entry(
          'c',
          DateTime.utc(2026, 11, 17, 6),
          999,
          source: EntrySource.prior,
        ),
        // Older than 12 weeks.
        _entry('d', DateTime.utc(2026, 8, 1, 6), 120),
      ],
      today,
      0,
    );
    expect(weeks.keys.first, const LocalDay(2026, 8, 31));
    expect(weeks.keys.last, const LocalDay(2026, 11, 16));
    expect(weeks, hasLength(12));
    expect(weeks.keys.every((d) => d.weekday == DateTime.monday), isTrue);
    expect(weeks[const LocalDay(2026, 11, 16)], 600);
    expect(weeks[const LocalDay(2026, 11, 9)], 300);
    expect(weeks.values.fold(0, (a, b) => a + b), 900);
  });

  testWidgets('skill detail', (t) async {
    final db = await openTestDb(t);
    await pumpPhone(
      t,
      const SkillDetailScreen(skillId: 'ingilizce'),
      overrides: appOverrides(db, demoClock()),
    );
    await expectGolden(t, 'skill_detail');
  }, tags: 'golden');

  testWidgets('title path', (t) async {
    final db = await openTestDb(t);
    await pumpPhone(
      t,
      const TitlePathScreen(skillId: 'ingilizce'),
      overrides: appOverrides(db, demoClock()),
    );
    await expectGolden(t, 'title_path');
  }, tags: 'golden');

  testWidgets('weekly chart renders twelve bars', (t) async {
    await pumpPhone(
      t,
      Scaffold(
        body: WeeklyChart({
          for (var i = 0; i < 12; i++)
            const LocalDay(2026, 8, 31).addDays(7 * i): i * 600,
        }),
      ),
    );
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics && (w.properties.label ?? '').contains('12 hafta'),
      ),
      findsOneWidget,
    );
  });
}
