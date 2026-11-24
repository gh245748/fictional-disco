import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mesk/app/app.dart';
import 'package:mesk/app/providers.dart';
import 'package:mesk/app/router.dart';
import 'package:mesk/data/db.dart';
import 'package:mesk/data/habits_repo.dart';
import 'package:mesk/data/log_pipeline.dart';
import 'package:mesk/data/skills_repo.dart';
import 'package:mesk/domain/models.dart';
import 'package:mesk/domain/stats.dart';
import 'package:mesk/features/skills/skill_edit_screen.dart';
import 'package:mesk/features/skills/skills_controller.dart';
import 'package:mesk/features/skills/skills_screen.dart';

import '../support/demo_data.dart';
import '../support/golden.dart';

Future<MeskDb> _demoDb(WidgetTester t) async {
  final db = (await t.runAsync(() async {
    final db = await MeskDb.openMemory();
    await seedDemo(db);
    return db;
  }))!;
  addTearDown(() => t.runAsync(db.close));
  return db;
}

Future<void> _pumpApp(WidgetTester t, MeskDb db, String location) async {
  setPhoneView(t);
  await t.pumpWidget(
    ProviderScope(
      overrides: appOverrides(db, demoClock()),
      child: const MeskApp(),
    ),
  );
  await t.pumpAndSettle();
  t.container().read(routerProvider).go(location);
  await t.pumpAndSettle();
}

String _location(WidgetTester t) =>
    t.container().read(routerProvider).state.uri.toString();

Future<void> _tap(WidgetTester t, Finder f) async {
  if (f.evaluate().isEmpty) {
    await t.scrollUntilVisible(
      f,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await t.ensureVisible(f);
  await t.tap(f, warnIfMissed: false);
  await t.pumpAndSettle();
}

Finder _inDialog(String text) =>
    find.descendant(of: find.byType(AlertDialog), matching: find.text(text));

double _top(WidgetTester t, String text) => t.getTopLeft(find.text(text)).dy;

void main() {
  group('SkillsController', () {
    late MeskDb db;
    late SkillsController controller;

    setUp(() async {
      db = await MeskDb.openMemory();
      await seedDemo(db);
      controller = SkillsController(
        db,
        demoClock(),
        LogPipeline(db, demoClock()),
        rng: Random(1),
      );
    });
    tearDown(() => db.close());

    test(
      'delete and archive tell the app so reminders and timer follow',
      () async {
        var changes = 0;
        final watched = SkillsController(
          db,
          demoClock(),
          LogPipeline(db, demoClock()),
          afterChange: () async => changes++,
        );
        await watched.archive('okuma');
        expect(changes, 1);
        await watched.delete('yoga');
        expect(changes, 2);
      },
    );

    test('create places the skill near positioned linked skills', () async {
      final skills = SkillsRepo(db);
      final okuma = (await skills.get('okuma'))!;
      await skills.put(okuma.copyWith(graphX: 100.0, graphY: 50.0));

      final id = await controller.create(
        name: 'Felsefe',
        primary: Stat.zihin,
        secondary: Stat.denge,
        description: 'Kısa not',
        links: {'okuma', 'yoga'},
      );
      final made = (await skills.get(id))!;
      expect(made.name, 'Felsefe');
      expect(made.secondary, Stat.denge);
      expect(made.description, 'Kısa not');
      expect(made.graphX, isNotNull);
      expect(made.graphY, isNotNull);
      expect(
        sqrt(pow(made.graphX! - 100, 2) + pow(made.graphY! - 50, 2)),
        lessThanOrEqualTo(120),
      );
      final links = await LinksRepo(db).all();
      expect(links.where((l) => l.a == id || l.b == id).length, 2);
    });

    test('create leaves the position empty without positioned links', () async {
      final id = await controller.create(
        name: 'Felsefe',
        primary: Stat.zihin,
        links: {'okuma'},
      );
      final made = (await SkillsRepo(db).get(id))!;
      expect(made.graphX, isNull);
      expect(made.graphY, isNull);
    });

    test('update rewrites the links', () async {
      final skills = SkillsRepo(db);
      final hitabet = (await skills.get('hitabet'))!;
      await controller.update(
        hitabet.copyWith(name: 'Konuşma'),
        links: {'gitar'},
      );
      expect((await skills.get('hitabet'))!.name, 'Konuşma');
      final links = [
        for (final l in await LinksRepo(db).all())
          if (l.a == 'hitabet' || l.b == 'hitabet') l,
      ];
      expect(links, hasLength(1));
      expect({links.single.a, links.single.b}, {'hitabet', 'gitar'});
    });

    test(
      'archive archives timed habits, unarchive keeps them archived',
      () async {
        await controller.archive('ingilizce');
        final habits = HabitsRepo(db);
        expect((await SkillsRepo(db).get('ingilizce'))!.archived, isTrue);
        expect((await habits.get('h-ingilizce'))!.archivedAt, isNotNull);
        expect((await habits.get('h-erken'))!.archivedAt, isNull);

        await controller.unarchive('ingilizce');
        expect((await SkillsRepo(db).get('ingilizce'))!.archived, isFalse);
        expect((await habits.get('h-ingilizce'))!.archivedAt, isNotNull);
      },
    );
  });

  testWidgets('sort by name is Turkish-aware', (t) async {
    final db = (await t.runAsync(() async {
      final db = await MeskDb.openMemory();
      final repo = SkillsRepo(db);
      for (final (i, name) in [
        'İngilizce',
        'Işık',
        'Çizim',
        'Cesaret',
      ].indexed) {
        await repo.put(
          Skill(
            id: 's$i',
            name: name,
            primary: Stat.zihin,
            createdAt: DateTime.utc(2026),
          ),
        );
      }
      return db;
    }))!;
    addTearDown(() => t.runAsync(db.close));
    await pumpPhone(
      t,
      const SkillsScreen(),
      overrides: appOverrides(db, demoClock()),
    );
    await _tap(t, find.text('Ad'));
    final tops = [
      for (final n in ['Cesaret', 'Çizim', 'Işık', 'İngilizce']) _top(t, n),
    ];
    expect(tops, [...tops]..sort());
    expect(tops.toSet(), hasLength(4));
  });

  testWidgets('secondary cannot equal primary', (t) async {
    final db = await _demoDb(t);
    await _pumpApp(t, db, '/yetenekler/yeni');
    ChoiceChip secondary(Stat s) =>
        t.widget<ChoiceChip>(find.byKey(ValueKey('secondary-${s.name}')));

    await _tap(t, find.byKey(const ValueKey('primary-zihin')));
    expect(secondary(Stat.zihin).onSelected, isNull);
    expect(secondary(Stat.karizma).onSelected, isNotNull);

    await _tap(t, find.byKey(const ValueKey('secondary-karizma')));
    expect(secondary(Stat.karizma).selected, isTrue);

    // Moving the primary onto the secondary clears the secondary.
    await _tap(t, find.byKey(const ValueKey('primary-karizma')));
    expect(secondary(Stat.karizma).selected, isFalse);
    expect(secondary(Stat.karizma).onSelected, isNull);
  });

  testWidgets('new skill is saved with its links', (t) async {
    final db = await _demoDb(t);
    await _pumpApp(t, db, '/yetenekler/yeni');
    await t.enterText(find.byType(TextField).first, 'Felsefe');
    await _tap(t, find.byKey(const ValueKey('primary-zihin')));
    await _tap(t, find.byKey(const ValueKey('link-okuma')));
    await _tap(t, find.text('Kaydet'));

    final skills = (await t.runAsync(() => SkillsRepo(db).all()))!;
    final made = skills.singleWhere((s) => s.name == 'Felsefe');
    final links = (await t.runAsync(() => LinksRepo(db).all()))!;
    expect(
      links.where((l) => l.a == made.id || l.b == made.id).single,
      isA<SkillLink>(),
    );
    expect(_location(t), '/yetenekler');
  });

  testWidgets('delete confirmation shows bonus and deletes', (t) async {
    final db = await _demoDb(t);
    await _pumpApp(t, db, '/yetenekler/okuma/duzenle');
    await _tap(t, find.text('Sil'));
    expect(
      find.text(
        'Okuma ve bütün kayıtları silinecek. '
        'Bağlı yeteneklerden 2 sa 18 dk bonus da silinecek.',
      ),
      findsOneWidget,
    );
    expect(find.text('Silmek yerine arşivleyebilirsin.'), findsOneWidget);
    expect(_inDialog('Önce yedek al'), findsOneWidget);
    expect(_inDialog('Arşivle'), findsOneWidget);

    await _tap(t, _inDialog('Sil'));
    expect((await t.runAsync(() => SkillsRepo(db).get('okuma'))), isNull);
    expect(_location(t), '/yetenekler');
    expect(find.text('Okuma'), findsNothing);
  });

  testWidgets('delete confirmation omits bonus sentence when there is none', (
    t,
  ) async {
    final db = await _demoDb(t);
    await _pumpApp(t, db, '/yetenekler/hitabet/duzenle');
    await _tap(t, find.text('Sil'));
    expect(find.text('Hitabet ve bütün kayıtları silinecek.'), findsOneWidget);
  });

  testWidgets('backup button leads to settings', (t) async {
    final db = await _demoDb(t);
    await _pumpApp(t, db, '/yetenekler/okuma/duzenle');
    await _tap(t, find.text('Sil'));
    await _tap(t, _inDialog('Önce yedek al'));
    expect(_location(t), '/ayarlar');
    expect((await t.runAsync(() => SkillsRepo(db).get('okuma'))), isNotNull);
  });

  testWidgets('archive hides from list but keeps total level', (t) async {
    final db = await _demoDb(t);
    await _pumpApp(t, db, '/yetenekler');
    t.container().listen(characterViewProvider, (_, _) {});
    await t.pumpAndSettle();
    final before = t.container().read(characterViewProvider).value!;
    expect(find.text('Yazılım'), findsOneWidget);
    expect(find.text('Arşiv'), findsNothing);

    t.container().read(routerProvider).push('/yetenekler/yazilim/duzenle');
    await t.pumpAndSettle();
    await _tap(t, find.text('Arşivle'));
    expect(_location(t), '/yetenekler');
    expect(find.text('Yazılım'), findsNothing);

    await _tap(t, find.text('Arşiv'));
    expect(find.text('Yazılım'), findsOneWidget);
    final after = t.container().read(characterViewProvider).value!;
    expect(after.totalLevel, before.totalLevel);
    expect(after.totalRealSeconds, before.totalRealSeconds);
  });

  testWidgets('archiving archives its timed habits after confirmation', (
    t,
  ) async {
    final db = await _demoDb(t);
    await _pumpApp(t, db, '/yetenekler/ingilizce/duzenle');

    await _tap(t, find.text('Arşivle'));
    expect(
      find.text('Bu yeteneğe bağlı 1 alışkanlık da arşivlenecek.'),
      findsOneWidget,
    );
    // Declining changes nothing.
    await _tap(t, _inDialog('Vazgeç'));
    expect(
      (await t.runAsync(() => SkillsRepo(db).get('ingilizce')))!.archived,
      isFalse,
    );

    await _tap(t, find.text('Arşivle'));
    await _tap(t, _inDialog('Arşivle'));
    expect(
      (await t.runAsync(() => SkillsRepo(db).get('ingilizce')))!.archived,
      isTrue,
    );
    final habits = HabitsRepo(db);
    expect(
      (await t.runAsync(() => habits.get('h-ingilizce')))!.archivedAt,
      isNotNull,
    );
    expect((await t.runAsync(() => habits.get('h-erken')))!.archivedAt, isNull);
  });

  testWidgets('skills list', (t) async {
    final db = await _demoDb(t);
    await pumpPhone(
      t,
      const SkillsScreen(),
      overrides: appOverrides(db, demoClock()),
    );
    await expectGolden(t, 'skills_list');
  }, tags: 'golden');

  testWidgets('skill edit', (t) async {
    final db = await _demoDb(t);
    await pumpPhone(
      t,
      const SkillEditScreen(skillId: 'ingilizce'),
      overrides: appOverrides(db, demoClock()),
    );
    await expectGolden(t, 'skill_edit');
  }, tags: 'golden');
}
