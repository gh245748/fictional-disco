import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mesk/app/providers.dart';
import 'package:mesk/data/kv_repo.dart';
import 'package:mesk/domain/stats.dart';
import 'package:mesk/features/character/character_screen.dart';

import '../support/app_harness.dart';
import '../support/demo_data.dart';
import '../support/golden.dart';

Finder _inSheet(Finder f) =>
    find.descendant(of: find.byType(BottomSheet), matching: f);

/// Scrolls [f] into view, lets the scroll finish, then taps it.
Future<void> _tap(WidgetTester t, Finder f) async {
  if (f.evaluate().isEmpty) {
    await t.scrollUntilVisible(
      f,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('title defaults to highest skill title and can change', (
    t,
  ) async {
    final db = await openTestDb(t);
    await pumpMeskApp(t, db, '/karakter');
    expect(find.text('Gezgin'), findsOneWidget);
    expect(find.text('Rehber'), findsOneWidget);

    await t.tap(find.byTooltip('Unvanı değiştir'));
    await t.pumpAndSettle();
    final okuma31 = find.byKey(const ValueKey('title-okuma-31'));
    await t.scrollUntilVisible(
      okuma31,
      200,
      scrollable: _inSheet(find.byType(Scrollable)).first,
    );
    await t.tap(okuma31);
    await t.pumpAndSettle();

    expect(find.text('Zanaatkâr'), findsOneWidget);
    expect(find.text('Rehber'), findsNothing);
    final saved = (await t.runAsync(() => KvRepo(db).character()))!;
    expect((saved.titleSkillId, saved.titleLevel), ('okuma', 31));
    expect(saved.name, 'Gezgin');

    // "Otomatik" goes back to the highest skill's title.
    await t.tap(find.byTooltip('Unvanı değiştir'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('title-auto')));
    await t.pumpAndSettle();
    expect(find.text('Rehber'), findsOneWidget);
  });

  testWidgets('character name can be edited', (t) async {
    final db = await openTestDb(t);
    await pumpMeskApp(t, db, '/karakter');
    await t.tap(find.byTooltip('Adı değiştir'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'Yolcu');
    await t.tap(find.text('Kaydet'));
    await t.pumpAndSettle();
    expect(find.text('Yolcu'), findsOneWidget);
    expect(find.text('Gezgin'), findsNothing);
    final saved = (await t.runAsync(() => KvRepo(db).character()))!;
    expect(saved.name, 'Yolcu');
  });

  testWidgets('stat detail lists contributions', (t) async {
    final db = await openTestDb(t);
    await pumpMeskApp(t, db, '/karakter');
    await _tap(t, find.byKey(const ValueKey('stat-karizma')));
    expect(find.text('Hitabet · Sv. 5 · +5'), findsOneWidget);
    expect(find.text('İngilizce · Sv. 23 · +11,5'), findsOneWidget);
    // 5 + 11,5 = 16,5, displayed as 17.
    expect(
      t.widget<Text>(find.byKey(const ValueKey('stat-detail-value'))).data,
      '17',
    );
  });

  testWidgets('irade detail lists habits and matches the character view', (
    t,
  ) async {
    final db = await openTestDb(t);
    await pumpMeskApp(t, db, '/karakter');
    final view = await t.container().read(characterViewProvider.future);
    await _tap(t, find.byKey(const ValueKey('stat-irade')));
    expect(find.text('Erken kalk'), findsOneWidget);
    expect(find.text('12 tamamlama · +5 seri ödülü'), findsOneWidget);
    expect(find.text('Şekersiz gün'), findsOneWidget);
    expect(find.text('9 tamamlama · +5 seri ödülü'), findsOneWidget);
    expect(find.text('İngilizce · 30 dk'), findsOneWidget);
    expect(find.text('1 tamamlama · +0 seri ödülü'), findsOneWidget);
    // 1 + 17 + 14 = 32 points; 32 / 8 = 4.
    expect(find.text('32 puan ÷ 8'), findsOneWidget);
    expect(view.stats[Stat.irade], 4);
    expect(
      t.widget<Text>(find.byKey(const ValueKey('stat-detail-value'))).data,
      '4',
    );
  });

  testWidgets('how stats are calculated expands; achievements link', (t) async {
    final db = await openTestDb(t);
    await pumpMeskApp(t, db, '/karakter');
    expect(find.textContaining('düşmez'), findsNothing);
    await _tap(t, find.text('Statlar nasıl hesaplanır?'));
    expect(find.textContaining('ana statına'), findsOneWidget);
    expect(find.textContaining('alışkanlık'), findsOneWidget);
    expect(find.textContaining('düşmez'), findsOneWidget);

    await _tap(t, find.text('Başarımlar'));
    expect(currentLocation(t), '/basarimlar');
  });

  testWidgets('character', (t) async {
    final db = await openTestDb(t);
    await pumpPhone(
      t,
      const CharacterScreen(),
      overrides: appOverrides(db, demoClock()),
    );
    await expectGolden(t, 'character');
  }, tags: 'golden');
}
