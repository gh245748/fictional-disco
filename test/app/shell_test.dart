import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mesk/app/app.dart';
import 'package:mesk/app/router.dart';
import 'package:mesk/app/shell.dart';
import 'package:mesk/data/db.dart';
import 'package:mesk/data/kv_repo.dart';
import 'package:mesk/domain/models.dart';
import 'package:mesk/features/entries/entry_form_screen.dart';
import 'package:mesk/features/graph/graph_screen.dart';
import 'package:mesk/features/skills/skill_detail_screen.dart';
import 'package:mesk/ui/theme.dart';

import '../support/demo_data.dart';
import '../support/golden.dart';

Future<MeskDb> _db(WidgetTester t, {required bool onboarded}) async {
  final db = (await t.runAsync(() async {
    final db = await MeskDb.openMemory();
    await KvRepo(db).saveSettings(AppSettings(onboarded: onboarded));
    return db;
  }))!;
  addTearDown(() => t.runAsync(db.close));
  return db;
}

Future<void> _pumpApp(WidgetTester t, MeskDb db) async {
  setPhoneView(t);
  await t.pumpWidget(
    ProviderScope(
      overrides: appOverrides(db, demoClock()),
      child: const MeskApp(),
    ),
  );
  await t.pumpAndSettle();
}

String _location(WidgetTester t) =>
    t.container().read(routerProvider).state.uri.toString();

Color? _labelColor(WidgetTester t, String label) => t
    .widget<Text>(
      find.descendant(of: find.byType(MeskShell), matching: find.text(label)),
    )
    .style
    ?.color;

void main() {
  testWidgets('tabs switch and onboarding redirect', (t) async {
    final fresh = await _db(t, onboarded: false);
    await _pumpApp(t, fresh);
    expect(_location(t), '/baslangic');
    expect(find.byType(MeskShell), findsNothing);

    // Finishing onboarding elsewhere sends the user to Bugün.
    await t.runAsync(
      () => KvRepo(fresh).saveSettings(const AppSettings(onboarded: true)),
    );
    await t.pumpAndSettle();
    expect(_location(t), '/bugun');

    await t.pumpWidget(const SizedBox());
    final db = await _db(t, onboarded: true);
    await _pumpApp(t, db);
    expect(_location(t), '/bugun');
    expect(find.byType(MeskShell), findsOneWidget);
    for (final label in ['Bugün', 'Yetenekler', 'Odak', 'Ağ', 'Karakter']) {
      expect(
        find.descendant(of: find.byType(MeskShell), matching: find.text(label)),
        findsWidgets,
      );
    }
    expect(_labelColor(t, 'Yetenekler'), MeskColors.faint);

    await t.tap(find.text('Ağ'));
    await t.pumpAndSettle();
    expect(_location(t), '/ag');
    expect(find.byType(GraphScreen), findsOneWidget);
    final nav = t.getSize(find.byKey(MeskShell.navKey));
    expect(nav.height, 72);
  });

  testWidgets('nav marks the active tab in accent', (t) async {
    final db = await _db(t, onboarded: true);
    await _pumpApp(t, db);
    final navLabel = find.descendant(
      of: find.byKey(MeskShell.navKey),
      matching: find.text('Odak'),
    );
    expect(t.widget<Text>(navLabel).style?.color, MeskColors.faint);
    await t.tap(navLabel);
    await t.pumpAndSettle();
    expect(_location(t), '/odak');
    expect(t.widget<Text>(navLabel).style?.color, MeskColors.accent);
  });

  testWidgets('detail routes open over the shell', (t) async {
    final db = await _db(t, onboarded: true);
    await _pumpApp(t, db);
    t.container().read(routerProvider).push('/yetenekler/yazilim');
    await t.pumpAndSettle();
    expect(_location(t), '/yetenekler/yazilim');
    expect(find.byType(SkillDetailScreen), findsOneWidget);
    expect(find.byKey(MeskShell.navKey).hitTestable(), findsNothing);
    t.container().read(routerProvider).push('/kayit/yeni?skill=okuma&prior=1');
    await t.pumpAndSettle();
    expect(_location(t), '/kayit/yeni?skill=okuma&prior=1');
    expect(find.byType(EntryFormScreen), findsOneWidget);
  });

  testWidgets('nav labels fit at the largest text scale', (t) async {
    t.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    final db = await _db(t, onboarded: true);
    await _pumpApp(t, db);
    expect(t.takeException(), isNull);

    final nav = find.byKey(MeskShell.navKey);
    expect(t.getSize(nav).height, 72);
    final navRect = t.getRect(nav);
    for (final (label, _) in MeskShell.tabs) {
      final text = find.descendant(of: nav, matching: find.text(label));
      final paragraph = t.renderObject<RenderParagraph>(text);
      expect(paragraph.textScaler.scale(10), closeTo(13, 1e-9));
      expect(paragraph.didExceedMaxLines, isFalse, reason: label);
      // The whole line is laid out (nothing clipped) ...
      final full = paragraph.getMaxIntrinsicWidth(double.infinity);
      expect(paragraph.size.width, greaterThanOrEqualTo(full), reason: label);
      // ... and, after any scaling, drawn inside its tab and the bar.
      final item = find
          .ancestor(of: text, matching: find.byType(InkResponse))
          .first;
      final itemRect = t.getRect(item);
      final labelRect = t.getRect(text);
      expect(itemRect.width, greaterThanOrEqualTo(44), reason: label);
      expect(itemRect.height, greaterThanOrEqualTo(44), reason: label);
      for (final corner in [labelRect.topLeft, labelRect.bottomRight]) {
        expect(
          itemRect.inflate(0.01).contains(corner),
          isTrue,
          reason: '$label $labelRect in $itemRect',
        );
        expect(navRect.inflate(0.01).contains(corner), isTrue, reason: label);
      }
    }
  });
}
