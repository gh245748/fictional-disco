import 'package:flutter_test/flutter_test.dart';
import 'package:mesk/data/db.dart';
import 'package:mesk/data/entries_repo.dart';
import 'package:mesk/data/events_repo.dart';
import 'package:mesk/data/goals_repo.dart';
import 'package:mesk/data/habits_repo.dart';
import 'package:mesk/data/kv_repo.dart';
import 'package:mesk/data/log_pipeline.dart';
import 'package:mesk/data/skills_repo.dart';
import 'package:mesk/domain/day.dart';
import 'package:mesk/domain/level_curve.dart';
import 'package:mesk/domain/level_events.dart';
import 'package:mesk/domain/models.dart';
import 'package:mesk/domain/stats.dart';

const int _hour = 3600;

void main() {
  final now = DateTime.utc(2026, 11, 21, 18);
  late MeskDb db;
  late FixedClock clock;
  late LogPipeline pipeline;
  late int seq;

  String nextId() => 'id${(seq++).toString().padLeft(4, '0')}';

  setUp(() async {
    db = await MeskDb.openMemory();
    clock = FixedClock(now, offsetMinutes: 180);
    seq = 0;
    pipeline = LogPipeline(db, clock, idGen: nextId);
  });

  tearDown(() => db.close());

  Future<void> addSkill(String id, {Stat primary = Stat.zihin}) =>
      SkillsRepo(db).put(
        Skill(
          id: id,
          name: 'Yetenek $id',
          primary: primary,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      );

  Future<void> link(String skillId, Set<String> others) =>
      LinksRepo(db).setLinksFor(skillId, others, now, nextId);

  TimeEntry entry(
    String id,
    String skillId,
    int seconds, {
    EntrySource source = EntrySource.manual,
  }) {
    final end = clock.nowUtc();
    return TimeEntry(
      id: id,
      skillId: skillId,
      startedAt: end.subtract(Duration(seconds: seconds)),
      endedAt: end,
      offsetMinutes: 180,
      seconds: seconds,
      source: source,
      pomodoros: 0,
    );
  }

  Future<List<XpAward>> awards() => AwardsRepo(db).all();

  Future<List<int>> levelsOf(String skillId) async {
    final rows = await LevelReachedRepo(db).all();
    return [
      for (final r in rows)
        if (r.skillId == skillId) r.level,
    ]..sort();
  }

  test(
    'save writes awards for current links and celebrates both skills',
    () async {
      await addSkill('A');
      await addSkill('B');
      await link('A', {'B'});

      final result = await pipeline.saveEntry(entry('e1', 'A', 3 * _hour));

      final aw = await awards();
      expect(aw, hasLength(1));
      expect(aw.single.skillId, 'B');
      expect(aw.single.entryId, 'e1');
      expect(aw.single.seconds, 1080);
      expect(aw.single.rateBp, 1000);
      expect((await EntriesRepo(db).get('e1'))!.seconds, 10800);

      final levelCards = result.celebrations
          .where(
            (c) =>
                c.kind == CelebrationKind.levelUp ||
                c.kind == CelebrationKind.milestone,
          )
          .toList();
      expect(levelCards, hasLength(2));
      expect(levelCards[0].kind, CelebrationKind.levelUp);
      expect(levelCards[0].skillId, 'A');
      expect(levelCards[0].fromLevel, 1);
      expect(levelCards[0].toLevel, 8);
      expect(levelCards[0].viaBonus, isFalse);
      expect(levelCards[1].kind, CelebrationKind.levelUp);
      expect(levelCards[1].skillId, 'B');
      expect(levelCards[1].fromLevel, 1);
      expect(levelCards[1].toLevel, 2);
      expect(levelCards[1].viaBonus, isTrue);
      // Level cards come first.
      expect(result.celebrations.take(2), levelCards);

      expect(await levelsOf('A'), [for (var l = 1; l <= 8; l++) l]);
      expect(await levelsOf('B'), [2]);
      final row = await LevelReachedRepo(db).get(LevelReachedRepo.key('A', 8));
      expect(row!.at, now);
    },
  );

  test('level cards list the logged skill before bonus skills', () async {
    await addSkill('A');
    await addSkill('Z');
    await link('Z', {'A'});

    final result = await pipeline.saveEntry(entry('e1', 'Z', 3 * _hour));

    final levelCards = result.celebrations
        .where((c) => c.kind == CelebrationKind.levelUp)
        .map((c) => (c.skillId, c.viaBonus));
    expect(levelCards, [('Z', false), ('A', true)]);
  });

  test(
    'later link does not grant past bonus; removed link keeps earned bonus',
    () async {
      await addSkill('A');
      await addSkill('B');

      await pipeline.saveEntry(entry('e1', 'A', _hour));
      expect(await awards(), isEmpty);

      await link('A', {'B'});
      expect(await awards(), isEmpty, reason: 'no retroactive bonus');

      await pipeline.saveEntry(entry('e2', 'A', _hour));
      expect((await awards()).map((a) => (a.entryId, a.skillId, a.seconds)), [
        ('e2', 'B', 360),
      ]);

      await link('A', {});
      await pipeline.saveEntry(entry('e3', 'A', _hour));
      expect((await awards()).map((a) => (a.entryId, a.skillId, a.seconds)), [
        ('e2', 'B', 360),
      ], reason: 'earned bonus stays after unlinking, new entry gives none');
    },
  );

  test('archived linked skill still receives bonus', () async {
    await addSkill('A');
    await addSkill('B');
    await link('A', {'B'});
    final b = (await SkillsRepo(db).get('B'))!;
    await SkillsRepo(db).put(b.copyWith(archivedAt: now));

    await pipeline.saveEntry(entry('e1', 'A', _hour));

    final aw = await awards();
    expect(aw.map((a) => (a.skillId, a.seconds)), [('B', 360)]);
  });

  test('update rescales awards and re-locks levels', () async {
    await addSkill('A');
    await addSkill('B');
    await link('A', {'B'});
    await pipeline.saveEntry(entry('e1', 'A', _hour));
    final levelBefore = levelForXp(_hour);
    expect(levelBefore, greaterThan(1));
    expect(await levelsOf('A'), [for (var l = 1; l <= levelBefore; l++) l]);

    final result = await pipeline.updateEntry(entry('e1', 'A', 600));

    expect(result.celebrations, isEmpty);
    final aw = await awards();
    expect(aw, hasLength(1));
    expect(aw.single.skillId, 'B');
    expect(aw.single.seconds, 60);
    expect(aw.single.rateBp, 1000);
    expect((await EntriesRepo(db).get('e1'))!.seconds, 600);
    final newLevel = levelForXp(600);
    expect(await levelsOf('A'), [for (var l = 1; l <= newLevel; l++) l]);
  });

  test('update keeps the rate recorded when the entry was saved', () async {
    await addSkill('A');
    await addSkill('B');
    await link('A', {'B'});
    await pipeline.saveEntry(entry('e1', 'A', _hour));
    final kv = KvRepo(db);
    await kv.saveSettings((await kv.settings()).copyWith(bonusRateBp: 2500));

    await pipeline.updateEntry(entry('e1', 'A', 2 * _hour));

    final aw = await awards();
    expect(aw.single.seconds, 720);
    expect(aw.single.rateBp, 1000);
  });

  test('delete removes entry and its awards', () async {
    await addSkill('A');
    await addSkill('B');
    await link('A', {'B'});
    await pipeline.saveEntry(entry('e1', 'A', 3 * _hour));
    await pipeline.saveEntry(entry('e2', 'A', _hour));
    expect(await awards(), hasLength(2));

    final result = await pipeline.deleteEntry('e1');

    expect(result.celebrations, isEmpty);
    expect(await EntriesRepo(db).get('e1'), isNull);
    expect(await EntriesRepo(db).get('e2'), isNotNull);
    expect((await awards()).map((a) => a.entryId), ['e2']);
    final level = levelForXp(_hour);
    expect(await levelsOf('A'), [for (var l = 1; l <= level; l++) l]);
    expect(await levelsOf('B'), isEmpty, reason: '360 s bonus is level 1');
  });

  test('prior entry gives no awards, combined celebration', () async {
    await addSkill('A');
    await addSkill('B');
    await link('A', {'B'});

    final result = await pipeline.saveEntry(
      entry('p1', 'A', 100 * _hour, source: EntrySource.prior),
    );

    expect(await awards(), isEmpty);
    final levelCards = result.celebrations
        .where(
          (c) =>
              c.kind == CelebrationKind.levelUp ||
              c.kind == CelebrationKind.milestone,
        )
        .toList();
    expect(levelCards, hasLength(1));
    expect(levelCards.single.kind, CelebrationKind.milestone);
    expect(levelCards.single.skillId, 'A');
    expect(levelCards.single.fromLevel, 1);
    expect(levelCards.single.toLevel, 39);
    expect(await levelsOf('A'), [for (var l = 1; l <= 39; l++) l]);
    // Ruling R9: prior experience does not unlock ilk_adim.
    expect(
      result.celebrations.map((c) => c.achievementKey),
      isNot(contains('ilk_adim')),
    );
  });

  test('goal completes and unlocks hedefe_varis', () async {
    await addSkill('A');
    await GoalsRepo(db).put(
      Goal(
        id: 'g1',
        skillId: 'A',
        targetSeconds: _hour,
        createdAt: DateTime.utc(2026, 11, 1),
      ),
    );

    final result = await pipeline.saveEntry(entry('e1', 'A', _hour));

    final kinds = result.celebrations.map((c) => c.kind).toList();
    final goalIndex = kinds.indexOf(CelebrationKind.goalCompleted);
    expect(goalIndex, greaterThan(0));
    final goalCard = result.celebrations[goalIndex];
    expect(goalCard.goalId, 'g1');
    expect(goalCard.skillId, 'A');
    // Order: level cards, then goal cards, then achievement cards.
    expect(kinds.first, CelebrationKind.levelUp);
    expect(
      kinds.sublist(goalIndex + 1),
      everyElement(CelebrationKind.achievement),
    );
    final keys = result.celebrations
        .where((c) => c.kind == CelebrationKind.achievement)
        .map((c) => c.achievementKey)
        .toList();
    expect(keys, containsAll(['ilk_adim', 'hedefe_varis']));

    final goal = (await GoalsRepo(db).get('g1'))!;
    expect(goal.completedAt, now);
    final unlocked = await AchievementsRepo(db).get('hedefe_varis');
    expect(unlocked!.at, now);

    // A completed goal does not celebrate again.
    clock.advance(const Duration(hours: 1));
    final again = await pipeline.saveEntry(entry('e2', 'A', 60));
    expect(
      again.celebrations.map((c) => c.kind),
      isNot(contains(CelebrationKind.goalCompleted)),
    );
    expect(
      again.celebrations.map((c) => c.achievementKey),
      isNot(contains('hedefe_varis')),
    );
    expect((await GoalsRepo(db).get('g1'))!.completedAt, now);
  });

  test('deleteSkill cascades', () async {
    await addSkill('A');
    await addSkill('B');
    await addSkill('C');
    await link('A', {'B'});
    // A gives B 360 s.
    await pipeline.saveEntry(entry('eA', 'A', _hour));
    // B's own 10 min also gives A a 60 s award.
    await pipeline.saveEntry(entry('eB', 'B', 600));
    await link('A', {'B', 'C'});

    final habits = HabitsRepo(db);
    await habits.put(
      Habit(
        id: 'h1',
        name: 'Günlük A',
        kind: HabitKind.timed,
        skillId: 'A',
        targetMinutes: 30,
        schedule: const DailySchedule(),
        createdAt: DateTime.utc(2026, 11, 1),
      ),
    );
    await habits.put(
      Habit(
        id: 'h2',
        name: 'Basit',
        kind: HabitKind.simple,
        schedule: const DailySchedule(),
        createdAt: DateTime.utc(2026, 11, 1),
      ),
    );
    await habits.toggleCheck('h1', const LocalDay(2026, 11, 20));
    await habits.toggleCheck('h2', const LocalDay(2026, 11, 20));
    await GoalsRepo(db).put(
      Goal(
        id: 'g1',
        skillId: 'A',
        targetSeconds: 100 * _hour,
        createdAt: DateTime.utc(2026, 11, 1),
      ),
    );
    await TierReachedRepo(db)
        .put(TierReached(skillId: 'A', tier: HiddenTier.cinar, at: now));
    final kv = KvRepo(db);
    await kv.saveSettings(
      (await kv.settings()).copyWith(
        lastSkillId: 'A',
        lastPresetBySkill: {'A': 'klasik', 'B': 'derin'},
      ),
    );
    await kv.saveCharacter(
      const Character(name: 'Ali', titleSkillId: 'A', titleLevel: 3),
    );

    expect(await levelsOf('B'), [1, 2], reason: '600 + 360 s is level 2');
    expect(await pipeline.bonusGivenBySkill('A'), 360);
    expect(await pipeline.bonusGivenBySkill('B'), 60);

    await pipeline.deleteSkill('A');

    expect(await SkillsRepo(db).get('A'), isNull);
    expect(await SkillsRepo(db).all(), hasLength(2));
    expect((await EntriesRepo(db).all()).map((e) => e.id), ['eB']);
    expect(await awards(), isEmpty);
    final links = await LinksRepo(db).all();
    expect(links.where((l) => l.a == 'A' || l.b == 'A'), isEmpty);
    expect((await habits.all()).map((h) => h.id), ['h2']);
    expect((await habits.allChecks()).map((c) => c.habitId), ['h2']);
    expect(await GoalsRepo(db).all(), isEmpty);
    expect(
      (await LevelReachedRepo(db).all()).where((r) => r.skillId == 'A'),
      isEmpty,
    );
    expect(
      (await TierReachedRepo(db).all()).where((r) => r.skillId == 'A'),
      isEmpty,
    );
    final settings = await kv.settings();
    expect(settings.lastSkillId, isNull);
    expect(settings.lastPresetBySkill, {'B': 'derin'});
    final character = (await kv.character())!;
    expect(character.titleSkillId, isNull);
    expect(character.titleLevel, isNull);

    // B lost the 360 s bonus: 600 s is level 1 again.
    expect(levelForXp(600), 1);
    expect(await levelsOf('B'), [1]);
  });

  test('habit change unlocks streak achievements', () async {
    final habits = HabitsRepo(db);
    await habits.put(
      Habit(
        id: 'h1',
        name: 'Kitap',
        kind: HabitKind.simple,
        schedule: const DailySchedule(),
        createdAt: DateTime.utc(2026, 11, 15, 9),
      ),
    );
    for (var d = 15; d <= 20; d++) {
      await habits.toggleCheck('h1', LocalDay(2026, 11, d));
    }
    final six = await pipeline.afterHabitChange();
    expect(
      six.celebrations.map((c) => c.achievementKey),
      isNot(contains('yedi_gun')),
    );

    await habits.toggleCheck('h1', const LocalDay(2026, 11, 21));
    final result = await pipeline.afterHabitChange();

    final cards = result.celebrations
        .where((c) => c.kind == CelebrationKind.achievement)
        .map((c) => c.achievementKey);
    expect(cards, contains('yedi_gun'));
    expect(await AchievementsRepo(db).get('yedi_gun'), isNotNull);

    final again = await pipeline.afterHabitChange();
    expect(again.celebrations, isEmpty);
  });

  test('recomputeAll is silent and idempotent', () async {
    await addSkill('A');
    await addSkill('B');
    await link('A', {'B'});
    // Data written directly, as after a backup import.
    final e = entry('e1', 'A', 3 * _hour);
    await EntriesRepo(db).put(e);
    await AwardsRepo(db).put(
      const XpAward(
        id: 'w1',
        entryId: 'e1',
        skillId: 'B',
        seconds: 1080,
        rateBp: 1000,
      ),
    );
    await GoalsRepo(db).put(
      Goal(
        id: 'g1',
        skillId: 'A',
        targetSeconds: _hour,
        createdAt: DateTime.utc(2026, 11, 1),
      ),
    );
    final old = DateTime.utc(2026, 10, 1);
    await LevelReachedRepo(db)
        .put(LevelReached(skillId: 'A', level: 3, at: old));
    // A stale row above the real level.
    await LevelReachedRepo(db)
        .put(LevelReached(skillId: 'A', level: 50, at: old));
    await AchievementsRepo(db).put(AchievementUnlock(key: 'ilk_adim', at: old));

    await pipeline.recomputeAll();

    expect(await levelsOf('A'), [for (var l = 1; l <= 8; l++) l]);
    expect(await levelsOf('B'), [2]);
    expect(
      (await LevelReachedRepo(db).get(LevelReachedRepo.key('A', 3)))!.at,
      old,
      reason: 'existing rows keep their date',
    );
    expect(
      (await LevelReachedRepo(db).get(LevelReachedRepo.key('A', 8)))!.at,
      now,
    );
    expect((await GoalsRepo(db).get('g1'))!.completedAt, now);
    expect((await AchievementsRepo(db).get('ilk_adim'))!.at, old);
    expect(await AchievementsRepo(db).get('hedefe_varis'), isNotNull);

    Future<Map<String, Object?>> snapshot() async => {
      'levels': [for (final r in await LevelReachedRepo(db).all()) r.toJson()],
      'tiers': [for (final r in await TierReachedRepo(db).all()) r.toJson()],
      'achievements': [
        for (final r in await AchievementsRepo(db).all()) r.toJson(),
      ],
      'goals': [for (final g in await GoalsRepo(db).all()) g.toJson()],
      'awards': [for (final a in await awards()) a.toJson()],
      'entries': [for (final e in await EntriesRepo(db).all()) e.toJson()],
    };

    final first = await snapshot();
    clock.advance(const Duration(days: 1));
    await pipeline.recomputeAll();
    expect(await snapshot(), first);
  });
}
