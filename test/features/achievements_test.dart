import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mesk/data/db.dart';
import 'package:mesk/data/entries_repo.dart';
import 'package:mesk/data/events_repo.dart';
import 'package:mesk/data/kv_repo.dart';
import 'package:mesk/data/log_pipeline.dart';
import 'package:mesk/data/skills_repo.dart';
import 'package:mesk/domain/achievements.dart';
import 'package:mesk/domain/models.dart';
import 'package:mesk/domain/stats.dart';
import 'package:mesk/features/achievements/achievements_screen.dart';
import 'package:mesk/ui/theme.dart';

import '../support/app_harness.dart';
import '../support/demo_data.dart';
import '../support/golden.dart';

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
  final at = DateTime.utc(2026, 1, 2, 6);
  await EntriesRepo(db).put(
    TimeEntry(
      id: 'ney-1',
      skillId: 'ney',
      startedAt: at,
      endedAt: at.add(Duration(hours: hours)),
      offsetMinutes: 180,
      seconds: hours * 3600,
      source: EntrySource.prior,
      pomodoros: 0,
    ),
  );
  await KvRepo(db).saveSettings(const AppSettings(onboarded: true));
  await LogPipeline(db, demoClock()).recomputeAll();
};

Color? _nameColor(WidgetTester t, String key, String name) => t
    .widget<Text>(
      find.descendant(
        of: find.byKey(ValueKey('badge-$key'), skipOffstage: false),
        matching: find.text(name, skipOffstage: false),
      ),
    )
    .style
    ?.color;

BoxDecoration _frame(WidgetTester t, String key) =>
    t.widget<Container>(find.byKey(ValueKey(key))).decoration! as BoxDecoration;

void main() {
  testWidgets('locked vs unlocked badges', (t) async {
    final db = await openTestDb(t);
    await pumpPhone(
      t,
      const AchievementsScreen(),
      overrides: appOverrides(db, demoClock()),
    );
    expect(find.text('Genel'), findsOneWidget);
    expect(find.text('Yetenekler'), findsOneWidget);
    for (final def in generalAchievements) {
      expect(
        find.byKey(ValueKey('badge-${def.key}'), skipOffstage: false),
        findsOneWidget,
        reason: def.key,
      );
    }
    final unlocked = (await t.runAsync(() => AchievementsRepo(db).all()))!
        .map((u) => u.key)
        .toList();
    expect(unlocked, contains('ilk_adim'));
    expect(unlocked, isNot(contains('bin_saat')));

    // Unlocked: full-strength name and the unlock date.
    expect(_nameColor(t, 'ilk_adim', 'İlk Adım'), MeskColors.text);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('badge-ilk_adim'), skipOffstage: false),
        matching: find.textContaining('2026', skipOffstage: false),
      ),
      findsOneWidget,
    );
    // Locked: faint name, no date, the condition instead.
    expect(_nameColor(t, 'bin_saat', 'Bin Saat'), MeskColors.faint);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('badge-bin_saat'), skipOffstage: false),
        matching: find.textContaining('2026', skipOffstage: false),
      ),
      findsNothing,
    );
    expect(find.text('Toplam 1000 saat', skipOffstage: false), findsOneWidget);
  });

  testWidgets('skill tab: reached levels, milestones framed in gold', (
    t,
  ) async {
    final db = await openTestDb(t);
    await pumpPhone(
      t,
      const AchievementsScreen(),
      overrides: appOverrides(db, demoClock()),
    );
    await t.tap(find.text('Yetenekler'));
    await t.pumpAndSettle();
    expect(find.text('Yazılım'), findsOneWidget);
    expect(_frame(t, 'level-yazilim-10').border!.top.color, MeskColors.accent);
    expect(
      _frame(t, 'level-yazilim-9').border!.top.color,
      isNot(MeskColors.accent),
    );
    // Level 48 of Yazılım is not reached yet.
    expect(find.byKey(const ValueKey('level-yazilim-48')), findsNothing);
    // Nothing is said about hidden tiers before level 99.
    expect(find.text('???', skipOffstage: false), findsNothing);
    expect(find.textContaining('Gizli', skipOffstage: false), findsNothing);

    await t.tap(find.byKey(const ValueKey('level-yazilim-47')));
    await t.pumpAndSettle();
    expect(find.text('Rehber'), findsOneWidget);
    expect(find.textContaining('Yazılım · Sv. 47'), findsOneWidget);
  });

  testWidgets('hidden tiers show as ??? once a skill reached level 99', (
    t,
  ) async {
    final db = await openTestDb(t, seed: _neyWith(2600));
    await pumpPhone(
      t,
      const AchievementsScreen(),
      overrides: appOverrides(db, demoClock()),
    );
    await t.tap(find.text('Yetenekler'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.text('Çınar'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Çınar'), findsOneWidget);
    expect(find.text('???', skipOffstage: false), findsNWidgets(2));
    expect(find.text('Zümrüdüanka', skipOffstage: false), findsNothing);
    expect(find.text('Efsane', skipOffstage: false), findsNothing);
  });

  testWidgets('skill tab empty state', (t) async {
    final db = await openTestDb(
      t,
      seed: (db) => KvRepo(db).saveSettings(const AppSettings(onboarded: true)),
    );
    await pumpMeskApp(t, db, '/basarimlar');
    await t.tap(find.text('Yetenekler'));
    await t.pumpAndSettle();
    expect(find.text('Yetenek ekle'), findsOneWidget);
    await t.tap(find.text('Yetenek ekle'));
    await t.pumpAndSettle();
    expect(currentLocation(t), '/yetenekler/yeni');
  });

  testWidgets('achievements', (t) async {
    final db = await openTestDb(t);
    await pumpPhone(
      t,
      const AchievementsScreen(),
      overrides: appOverrides(db, demoClock()),
    );
    await expectGolden(t, 'achievements');
  }, tags: 'golden');

  testWidgets('achievements skills tab', (t) async {
    final db = await openTestDb(t);
    await pumpPhone(
      t,
      const AchievementsScreen(),
      overrides: appOverrides(db, demoClock()),
    );
    await t.tap(find.text('Yetenekler'));
    await t.pumpAndSettle();
    await expectGolden(t, 'achievements_skills');
  }, tags: 'golden');
}
