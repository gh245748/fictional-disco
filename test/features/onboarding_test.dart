import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mesk/app/app.dart';
import 'package:mesk/app/router.dart';
import 'package:mesk/data/db.dart';
import 'package:mesk/data/kv_repo.dart';
import 'package:mesk/data/skills_repo.dart';
import 'package:mesk/domain/models.dart';
import 'package:mesk/domain/stats.dart';
import 'package:mesk/features/onboarding/onboarding_screen.dart';
import 'package:mesk/features/onboarding/templates.dart';
import 'package:mesk/services/notifications.dart';

import '../support/demo_data.dart';
import '../support/golden.dart';

Future<MeskDb> _freshDb(WidgetTester t) async {
  final db = (await t.runAsync(() async {
    final db = await MeskDb.openMemory();
    await KvRepo(db).saveSettings(const AppSettings());
    return db;
  }))!;
  addTearDown(() => t.runAsync(db.close));
  return db;
}

Future<void> _pumpApp(
  WidgetTester t,
  MeskDb db, {
  FakeNotificationService? notifications,
}) async {
  setPhoneView(t);
  await t.pumpWidget(
    ProviderScope(
      overrides: appOverrides(db, demoClock(), notifications: notifications),
      child: const MeskApp(),
    ),
  );
  await t.pumpAndSettle();
}

String _location(WidgetTester t) =>
    t.container().read(routerProvider).state.uri.toString();

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.tap(f, warnIfMissed: false);
  await t.pumpAndSettle();
}

Future<void> _next(WidgetTester t) => _tap(t, find.text('Devam'));

Future<void> _toSkillsPage(WidgetTester t) async {
  await _next(t);
  await t.enterText(find.byType(TextField), 'Ayşe');
  await t.pumpAndSettle();
  await _next(t);
}

void main() {
  test('templates match spec Ek C', () {
    expect(skillTemplates, hasLength(14));
    expect(templateLinks, hasLength(11));
    final names = {for (final s in skillTemplates) s.name};
    expect(names, hasLength(14));
    for (final (a, b) in templateLinks) {
      expect(names, containsAll([a, b]));
    }
    final english = skillTemplates.first;
    expect(
      (english.name, english.primary, english.secondary),
      ('İngilizce', Stat.zihin, Stat.karizma),
    );
  });

  testWidgets('creates selected skills and only links among them', (t) async {
    final db = await _freshDb(t);
    await _pumpApp(t, db);
    expect(_location(t), '/baslangic');
    expect(find.text("Meşk'e hoş geldin"), findsOneWidget);

    await _toSkillsPage(t);
    for (final name in ['İngilizce', 'Okuma', 'Hitabet']) {
      await _tap(t, find.text(name));
    }
    await _next(t);
    expect(
      find.text(
        'Pomodoro bittiğinde haber verebilmek için bildirim izni gerekiyor.',
      ),
      findsOneWidget,
    );
    await _tap(t, find.text('Şimdi değil'));

    final skills = (await t.runAsync(() => SkillsRepo(db).all()))!;
    final links = (await t.runAsync(() => LinksRepo(db).all()))!;
    final character = (await t.runAsync(() => KvRepo(db).character()))!;
    final settings = (await t.runAsync(() => KvRepo(db).settings()))!;
    expect({for (final s in skills) s.name}, {'İngilizce', 'Okuma', 'Hitabet'});
    expect(skills.every((s) => s.graphX == null && s.graphY == null), isTrue);
    final byId = {for (final s in skills) s.id: s.name};
    expect(links, hasLength(3));
    expect(
      {
        for (final l in links) {byId[l.a]!, byId[l.b]!},
      },
      {
        {'İngilizce', 'Okuma'},
        {'İngilizce', 'Hitabet'},
        {'Okuma', 'Hitabet'},
      },
    );
    expect(character.name, 'Ayşe');
    expect(settings.onboarded, isTrue);
    expect(_location(t), '/bugun');
  });

  testWidgets('name required', (t) async {
    final db = await _freshDb(t);
    await _pumpApp(t, db);
    await _next(t);
    FilledButton next() => t.widget<FilledButton>(
      find.ancestor(
        of: find.text('Devam'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(next().onPressed, isNull);
    await t.enterText(find.byType(TextField), '   ');
    await t.pumpAndSettle();
    expect(next().onPressed, isNull);
    await t.enterText(find.byType(TextField), 'Ayşe');
    await t.pumpAndSettle();
    expect(next().onPressed, isNotNull);
  });

  testWidgets('custom skill takes a name and a stat', (t) async {
    final db = await _freshDb(t);
    await _pumpApp(t, db);
    await _toSkillsPage(t);
    await _tap(t, find.text('Kendi yeteneğini ekle'));
    await t.enterText(find.byType(TextField), 'Hat sanatı');
    await t.pumpAndSettle();
    await _tap(t, find.widgetWithText(ChoiceChip, 'Yaratıcılık'));
    await _tap(t, find.text('Ekle'));
    await _next(t);
    await _tap(t, find.text('Şimdi değil'));

    final skills = (await t.runAsync(() => SkillsRepo(db).all()))!;
    expect(skills, hasLength(1));
    expect(skills.single.name, 'Hat sanatı');
    expect(skills.single.primary, Stat.yaraticilik);
    expect(skills.single.secondary, isNull);
    expect(_location(t), '/bugun');
  });

  testWidgets('custom skill duplicate is Turkish-aware', (t) async {
    final db = await _freshDb(t);
    await _pumpApp(t, db);
    await _toSkillsPage(t);
    await _tap(t, find.text('Kendi yeteneğini ekle'));
    await t.enterText(find.byType(TextField), 'ingilizce');
    await t.pumpAndSettle();
    expect(find.text('Bu yetenek zaten listede'), findsOneWidget);
    final add = find.ancestor(
      of: find.text('Ekle'),
      matching: find.byType(FilledButton),
    );
    expect(t.widget<FilledButton>(add).onPressed, isNull);
  });

  testWidgets('permission denied still completes', (t) async {
    final db = await _freshDb(t);
    final fake = FakeNotificationService(permissionGranted: false);
    await _pumpApp(t, db, notifications: fake);
    await _toSkillsPage(t);
    await _next(t);
    await _tap(t, find.text('İzin ver'));
    expect(fake.calls, contains('requestPermission'));
    expect(_location(t), '/bugun');
    final settings = (await t.runAsync(() => KvRepo(db).settings()))!;
    expect(settings.onboarded, isTrue);
  });

  testWidgets('skills page', (t) async {
    final db = await _freshDb(t);
    await pumpPhone(
      t,
      const OnboardingScreen(),
      overrides: appOverrides(db, demoClock()),
    );
    await _toSkillsPage(t);
    for (final name in ['İngilizce', 'Okuma', 'Hitabet']) {
      await _tap(t, find.text(name));
    }
    await expectGolden(t, 'onboarding_skills');
  }, tags: 'golden');
}
