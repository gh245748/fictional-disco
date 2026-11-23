import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:mesk/app/providers.dart';
import 'package:mesk/data/db.dart';
import 'package:mesk/domain/day.dart';
import 'package:mesk/domain/format.dart';
import 'package:mesk/domain/level_events.dart';
import 'package:mesk/domain/stats.dart';
import 'package:mesk/domain/titles.dart';

import '../support/demo_data.dart';
import '../support/golden.dart';

void main() {
  late MeskDb db;
  late ProviderContainer container;

  setUp(() async {
    db = await MeskDb.openMemory();
    await seedDemo(db);
    container = ProviderContainer(overrides: appOverrides(db, demoClock()));
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  // Riverpod 3 pauses providers nobody listens to, so subscribe before
  // awaiting a value.
  Future<T> watch<T>(ProviderListenable<Future<T>> provider) =>
      container.listen(provider, (_, _) {}).read();

  test('demo views', () async {
    final views = await watch(skillViewsProvider.future);
    expect(views, hasLength(13));
    final yazilim = views.singleWhere((v) => v.skill.id == 'yazilim');
    expect(
      (yazilim.level, yazilim.title, yazilim.band),
      (47, 'Rehber', Band.kalfalik),
    );

    final character = await watch(characterViewProvider.future);
    expect(character.totalLevel, 220);
    expect(character.stats, {
      Stat.zihin: 113,
      Stat.beden: 46,
      Stat.yaraticilik: 38,
      Stat.karizma: 17,
      Stat.denge: 25,
      // Erken kalk 12 + 5, Şekersiz gün 9 + 5, İngilizce 1: 32 points.
      Stat.irade: 4,
    });
    expect(character.name, 'Gezgin');
    expect(character.displayTitle, 'Rehber');
    expect(character.skillCount, 13);
    expect(formatHours(character.totalRealSeconds), '348 sa');
  });

  test('mockup skill rows', () async {
    final views = await watch(skillViewsProvider.future);
    final recent = [...views]
      ..sort((a, b) => b.lastEntryAt!.compareTo(a.lastEntryAt!));
    expect(recent.take(3).map((v) => v.skill.name), [
      'İngilizce',
      'Yazılım',
      'Okuma',
    ]);

    final ingilizce = (await watch(skillViewProvider('ingilizce').future))!;
    expect(ingilizce.level, 23);
    expect(ingilizce.title, 'Marifetli');
    expect(formatHours(ingilizce.totals.xpSeconds), '29,4 sa');
    expect(formatHours(ingilizce.secondsToNext), '1,4 sa');
    expect(ingilizce.progress, closeTo(0.51, 0.01));
    expect(formatPercent(ingilizce.goal!.progress), '%27');
    expect(ingilizce.goal!.requiredDailySeconds, 2004); // 34 dk
    expect(ingilizce.tier, isNull);
    expect(ingilizce.nextTier, isNull);

    final okuma = (await watch(skillViewProvider('okuma').future))!;
    expect(okuma.title, 'Zanaatkâr');
    expect(formatHours(okuma.secondsToNext), '2,9 sa');
    expect(okuma.goal, isNull);

    expect(await watch(skillViewProvider('yok').future), isNull);
  });

  test('today, focus and habits', () async {
    expect(await watch(todayProvider.future), const LocalDay(2026, 11, 21));
    expect(await watch(todayFocusProvider.future), (1200, 1));

    final habits = await watch(todayHabitsProvider.future);
    expect(habits.map((h) => (h.habit.name, h.done)), [
      ('İngilizce · 30 dk', false),
      ('Erken kalk', true),
      ('Şekersiz gün', false),
    ]);
    final erken = habits.singleWhere((h) => h.habit.id == 'h-erken');
    expect(erken.streak, 12);
    final ingilizce = habits.singleWhere((h) => h.habit.id == 'h-ingilizce');
    expect(ingilizce.progressSeconds, 1200);
  });

  test('celebration queue is first in, first out', () {
    final queue = container.read(celebrationQueueProvider.notifier);
    const a = Celebration(kind: CelebrationKind.levelUp, skillId: 'a');
    const b = Celebration(kind: CelebrationKind.milestone, skillId: 'b');
    const c = Celebration(kind: CelebrationKind.achievement);
    queue.push([a, b]);
    queue.push([c]);
    expect(container.read(celebrationQueueProvider), [a, b, c]);
    expect(queue.pop(), a);
    expect(container.read(celebrationQueueProvider), [b, c]);
    queue
      ..pop()
      ..pop();
    expect(queue.pop(), isNull);
    expect(container.read(celebrationQueueProvider), isEmpty);
  });
}
