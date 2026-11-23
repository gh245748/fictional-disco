import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mesk/data/db.dart';
import 'package:mesk/data/entries_repo.dart';
import 'package:mesk/data/events_repo.dart';
import 'package:mesk/data/habits_repo.dart';
import 'package:mesk/data/kv_repo.dart';
import 'package:mesk/data/presets_repo.dart';
import 'package:mesk/data/skills_repo.dart';
import 'package:mesk/domain/day.dart';
import 'package:mesk/domain/level_curve.dart';
import 'package:mesk/domain/models.dart';
import 'package:mesk/domain/stats.dart';
import 'package:mesk/domain/timer_machine.dart';

void main() {
  final t = DateTime.utc(2026, 3, 1, 10);

  Skill skill(String id, String name) =>
      Skill(id: id, name: name, primary: Stat.irade, createdAt: t);

  test('skills CRUD and watch emits', () async {
    final db = await MeskDb.openMemory();
    final repo = SkillsRepo(db);
    expect(await repo.all(), isEmpty);
    expect(await repo.get('a'), isNull);

    final emissions = <List<Skill>>[];
    final sub = repo.watchAll().listen(emissions.add);
    await pumpEventQueue();
    expect(emissions.last, isEmpty);

    await repo.put(skill('a', 'Resim'));
    await pumpEventQueue();
    expect(emissions.last.map((s) => s.id), ['a']);
    expect(await repo.get('a'), skill('a', 'Resim'));

    await repo.put(skill('a', 'Hat'));
    expect((await repo.get('a'))!.name, 'Hat');
    expect(await repo.all(), hasLength(1));

    await repo.delete('a');
    await pumpEventQueue();
    expect(await repo.get('a'), isNull);
    expect(emissions.last, isEmpty);

    // transaction variant
    await db.database.transaction((txn) async {
      await repo.put(skill('b', 'Ney'), txn: txn);
      expect(await repo.get('b', txn: txn), isNotNull);
    });
    expect(await repo.all(), hasLength(1));
    await sub.cancel();
    await db.close();
  });

  test('setLinksFor replaces the link set', () async {
    final db = await MeskDb.openMemory();
    final links = LinksRepo(db);
    var n = 0;
    String id() => 'l${n++}';

    await links.setLinksFor('m', {'z', 'b', 'm'}, t, id);
    var all = await links.all();
    expect(all, hasLength(2));
    for (final l in all) {
      expect(l.a.compareTo(l.b) < 0, isTrue);
      expect([l.a, l.b], contains('m'));
    }
    expect(all.map((l) => {l.a, l.b}.difference({'m'}).single).toSet(), {
      'b',
      'z',
    });

    // A link from another skill's perspective is replaced too.
    await links.setLinksFor('b', {'c'}, t, id);
    all = await links.all();
    final pairs = all.map((l) => '${l.a}-${l.b}').toSet();
    expect(pairs, {'m-z', 'b-c'});

    await links.setLinksFor('m', {}, t, id);
    expect((await links.all()).map((l) => '${l.a}-${l.b}'), ['b-c']);
    await db.close();
  });

  test('awards by entry', () async {
    final db = await MeskDb.openMemory();
    final entries = EntriesRepo(db);
    final awards = AwardsRepo(db);
    TimeEntry e(String id, String sid) => TimeEntry(
      id: id,
      skillId: sid,
      startedAt: t,
      endedAt: t.add(const Duration(minutes: 25)),
      offsetMinutes: 180,
      seconds: 1500,
      source: EntrySource.free,
      pomodoros: 0,
    );
    await entries.put(e('e1', 's1'));
    await entries.put(e('e2', 's2'));
    await entries.put(e('e3', 's1'));
    expect((await entries.forSkill('s1')).map((x) => x.id).toSet(), {
      'e1',
      'e3',
    });

    XpAward a(String id, String eid) => XpAward(
      id: id,
      entryId: eid,
      skillId: 's1',
      seconds: 1500,
      rateBp: 10000,
    );
    await awards.put(a('a1', 'e1'));
    await awards.put(a('a2', 'e1'));
    await awards.put(a('a3', 'e2'));
    expect((await awards.forEntry('e1')).map((x) => x.id).toSet(), {
      'a1',
      'a2',
    });
    await awards.deleteForEntry('e1');
    expect(await awards.forEntry('e1'), isEmpty);
    expect(await awards.all(), hasLength(1));
    await db.close();
  });

  test('events repos use composite keys', () async {
    final db = await MeskDb.openMemory();
    final levels = LevelReachedRepo(db);
    await levels.put(LevelReached(skillId: 's', level: 2, at: t));
    await levels.put(LevelReached(skillId: 's', level: 2, at: t));
    await levels.put(LevelReached(skillId: 's', level: 3, at: t));
    expect(await levels.all(), hasLength(2));
    await levels.delete('s#2');
    expect((await levels.all()).single.level, 3);

    final tiers = TierReachedRepo(db);
    await tiers.put(TierReached(skillId: 's', tier: HiddenTier.cinar, at: t));
    expect((await tiers.get('s#cinar'))!.tier, HiddenTier.cinar);

    final ach = AchievementsRepo(db);
    await ach.put(AchievementUnlock(key: 'k', at: t));
    expect((await ach.get('k'))!.key, 'k');
    await db.close();
  });

  test('toggleCheck', () async {
    final db = await MeskDb.openMemory();
    final repo = HabitsRepo(db);
    const day = LocalDay(2026, 3, 1);
    expect(await repo.toggleCheck('h', day), isTrue);
    expect(await repo.allChecks(), [const HabitCheck(habitId: 'h', day: day)]);
    expect(await repo.toggleCheck('h', day), isFalse);
    expect(await repo.allChecks(), isEmpty);

    await repo.put(
      Habit(
        id: 'h',
        name: 'Oku',
        kind: HabitKind.simple,
        schedule: const DailySchedule(),
        createdAt: t,
      ),
    );
    expect(await repo.all(), hasLength(1));
    await db.close();
  });

  test('presets seeded once', () async {
    final db = await MeskDb.openMemory();
    final repo = PresetsRepo(db);
    await repo.seedBuiltIns();
    await repo.seedBuiltIns();
    expect(await repo.all(), hasLength(TimerPreset.builtIns.length));
    expect(TimerPreset.builtIns, hasLength(2));
    await db.close();
  });

  test('settings default when empty', () async {
    final db = await MeskDb.openMemory();
    final kv = KvRepo(db);
    expect(await kv.settings(), AppSettings.defaults);
    expect(await kv.character(), isNull);
    final emissions = <AppSettings>[];
    final sub = kv.watchSettings().listen(emissions.add);
    await pumpEventQueue();
    expect(emissions.last, AppSettings.defaults);
    final changed = AppSettings.defaults.copyWith(
      dayStartHour: 4,
      lastPresetBySkill: {'s': 'klasik'},
    );
    await kv.saveSettings(changed);
    await pumpEventQueue();
    expect(await kv.settings(), changed);
    expect(emissions.last, changed);

    await kv.saveCharacter(const Character(name: 'Ali'));
    expect(await kv.character(), const Character(name: 'Ali'));
    await sub.cancel();
    await db.close();
  });

  test('timer state round-trips', () async {
    final db = await MeskDb.openMemory();
    final kv = KvRepo(db);
    expect(await kv.timer(), TimerState.idle);
    final s = TimerMachine.start(
      mode: TimerMode.pomodoro,
      skillId: 's',
      preset: TimerPreset.builtIns.first,
      now: t,
    );
    await kv.saveTimer(s);
    expect(await kv.timer(), s);
    await db.close();
  });

  test('schema version stored', () async {
    final dir = Directory.systemTemp.createTempSync('mesk_db');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/x.db';
    var db = await MeskDb.openFile(path);
    expect(db.database.version, MeskDb.schemaVersion);
    expect(MeskDb.schemaVersion, 1);
    await SkillsRepo(db).put(skill('a', 'Resim'));
    await db.close();

    db = await MeskDb.openFile(path);
    expect(db.database.version, 1);
    expect(await SkillsRepo(db).all(), [skill('a', 'Resim')]);
    await db.close();
  });
}
