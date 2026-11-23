import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast.dart';
import 'package:mesk/data/backup.dart';
import 'package:mesk/data/db.dart';
import 'package:mesk/domain/day.dart';
import 'package:mesk/domain/level_curve.dart';
import 'package:mesk/domain/models.dart';
import 'package:mesk/domain/stats.dart';
import 'package:mesk/domain/timer_machine.dart';

final _t0 = DateTime.utc(2026, 11, 20, 9);
final _t1 = DateTime.utc(2026, 11, 20, 10);

/// Puts at least one record in every store and all three kv keys.
Future<void> _seed(MeskDb db) async {
  await db.database.transaction((txn) async {
    await MeskDb.skills
        .record('s1')
        .put(
          txn,
          Skill(
            id: 's1',
            name: 'Gitar',
            primary: Stat.yaraticilik,
            createdAt: _t0,
          ).toJson(),
        );
    await MeskDb.skills
        .record('s2')
        .put(
          txn,
          Skill(
            id: 's2',
            name: 'Satranç',
            primary: Stat.zihin,
            createdAt: _t0,
          ).toJson(),
        );
    await MeskDb.links
        .record('l1')
        .put(
          txn,
          SkillLink.normalized(
            id: 'l1',
            x: 's1',
            y: 's2',
            createdAt: _t0,
          ).toJson(),
        );
    await MeskDb.entries
        .record('e1')
        .put(
          txn,
          TimeEntry(
            id: 'e1',
            skillId: 's1',
            startedAt: _t0,
            endedAt: _t1,
            offsetMinutes: 180,
            seconds: 3600,
            source: EntrySource.manual,
            pomodoros: 0,
            note: 'not',
          ).toJson(),
        );
    await MeskDb.awards
        .record('a1')
        .put(
          txn,
          const XpAward(
            id: 'a1',
            entryId: 'e1',
            skillId: 's1',
            seconds: 3600,
            rateBp: 10000,
          ).toJson(),
        );
    await MeskDb.levelReached
        .record('s1#2')
        .put(txn, LevelReached(skillId: 's1', level: 2, at: _t1).toJson());
    await MeskDb.tierReached
        .record('s1#t')
        .put(
          txn,
          TierReached(skillId: 's1', tier: HiddenTier.cinar, at: _t1).toJson(),
        );
    await MeskDb.achievements
        .record('first')
        .put(txn, AchievementUnlock(key: 'first', at: _t1).toJson());
    await MeskDb.habits
        .record('h1')
        .put(
          txn,
          Habit(
            id: 'h1',
            name: 'Su iç',
            kind: HabitKind.simple,
            schedule: const DailySchedule(),
            createdAt: _t0,
          ).toJson(),
        );
    await MeskDb.habitChecks
        .record('h1#2026-11-20')
        .put(
          txn,
          const HabitCheck(habitId: 'h1', day: LocalDay(2026, 11, 20)).toJson(),
        );
    await MeskDb.goals
        .record('g1')
        .put(
          txn,
          Goal(
            id: 'g1',
            skillId: 's1',
            targetSeconds: 36000,
            deadline: const LocalDay(2027, 1, 1),
            createdAt: _t0,
          ).toJson(),
        );
    await MeskDb.presets
        .record('p1')
        .put(
          txn,
          const TimerPreset(
            'p1',
            'Özel',
            25,
            5,
            15,
            4,
            false,
            false,
            false,
          ).toJson(),
        );
    await MeskDb.kv
        .record('settings')
        .put(
          txn,
          const AppSettings(onboarded: true, lastSkillId: 's1').toJson(),
        );
    await MeskDb.kv
        .record('character')
        .put(
          txn,
          const Character(
            name: 'Ayşe',
            titleSkillId: 's1',
            titleLevel: 2,
          ).toJson(),
        );
    await MeskDb.kv
        .record('timer')
        .put(
          txn,
          const TimerState(
            status: TimerStatus.paused,
            mode: TimerMode.free,
            skillId: 's1',
            pausedElapsedSeconds: 120,
            phaseStartedAt: null,
          ).toJson(),
        );
  });
}

Map<String, Object?> _dataOf(String json) =>
    (jsonDecode(json) as Map<String, Object?>)['data']! as Map<String, Object?>;

String _wrap(Map<String, Object?> data, {int version = backupVersion}) =>
    jsonEncode({
      'format': backupFormat,
      'version': version,
      'exportedAt': '2026-11-21T10:00:00.000Z',
      'data': data,
    });

void main() {
  final now = DateTime.utc(2026, 11, 21, 10);
  late MeskDb db;

  setUp(() async => db = await MeskDb.openMemory());
  tearDown(() => db.close());

  Future<void> expectRejected(String text, String message) async {
    final before = await exportBackup(db, now);
    await expectLater(
      importBackup(db, text),
      throwsA(
        isA<BackupException>().having((e) => e.message, 'message', message),
      ),
    );
    expect(_dataOf(await exportBackup(db, now)), _dataOf(before));
  }

  test('round trip', () async {
    await _seed(db);
    final first = await exportBackup(db, now);
    final parsed = jsonDecode(first) as Map<String, Object?>;
    expect(parsed['format'], 'mesk-backup');
    expect(parsed['version'], 1);
    expect(parsed['exportedAt'], now.toIso8601String());
    final data = parsed['data']! as Map<String, Object?>;
    for (final s in [
      'skills', 'links', 'entries', 'awards', 'levelReached', 'tierReached',
      'achievements', 'habits', 'habitChecks', 'goals', 'presets', 'kv', //
    ]) {
      expect(data[s], isNotEmpty, reason: s);
    }
    expect((data['kv']! as List).length, 3);

    final fresh = await MeskDb.openMemory('fresh');
    addTearDown(fresh.close);
    await importBackup(fresh, first);
    final second = await exportBackup(fresh, now);
    expect(_dataOf(second), _dataOf(first));
  });

  test('import replaces existing data', () async {
    await _seed(db);
    final backup = await exportBackup(db, now);
    await MeskDb.skills
        .record('extra')
        .put(
          db.database,
          Skill(
            id: 'extra',
            name: 'X',
            primary: Stat.beden,
            createdAt: _t0,
          ).toJson(),
        );
    await importBackup(db, backup);
    expect(await MeskDb.skills.record('extra').get(db.database), isNull);
    expect(_dataOf(await exportBackup(db, now)), _dataOf(backup));
  });

  test('unknown stores are ignored and missing stores are empty', () async {
    await _seed(db);
    await importBackup(
      db,
      _wrap({
        'skills': [
          {
            'key': 'n1',
            'value': Skill(
              id: 'n1',
              name: 'Yeni',
              primary: Stat.denge,
              createdAt: _t0,
            ).toJson(),
          },
        ],
        'futureStore': [
          {'key': 'x', 'value': <String, Object?>{}},
        ],
      }),
    );
    final data = _dataOf(await exportBackup(db, now));
    expect((data['skills']! as List).length, 1);
    expect(data.containsKey('futureStore'), isFalse);
    expect(data['entries'], isEmpty);
    expect(data['kv'], isEmpty);
  });

  test('file name', () {
    expect(
      backupFileName(const LocalDay(2026, 11, 21)),
      'mesk-yedek-2026-11-21.json',
    );
  });

  test('malformed json', () async {
    await _seed(db);
    await expectRejected('{not json', 'Yedek dosyası okunamadı.');
    await expectRejected('[1,2]', 'Yedek dosyası okunamadı.');
  });

  test('not a mesk backup', () async {
    await _seed(db);
    await expectRejected('{"data":{}}', 'Bu dosya bir Meşk yedeği değil.');
    await expectRejected(
      '{"format":"other","version":1,"data":{}}',
      'Bu dosya bir Meşk yedeği değil.',
    );
  });

  test('newer version', () async {
    await _seed(db);
    await expectRejected(
      _wrap({}, version: backupVersion + 1),
      'Bu yedek daha yeni bir Meşk sürümüyle alınmış. Önce uygulamayı güncelle.',
    );
  });

  test('atomic', () async {
    await _seed(db);
    final good = Skill(
      id: 'n1',
      name: 'Yeni',
      primary: Stat.denge,
      createdAt: _t0,
    ).toJson();
    await expectRejected(
      _wrap({
        'skills': [
          {'key': 'n1', 'value': good},
          {
            'key': 'bad',
            'value': {'id': 5},
          },
        ],
      }),
      'Yedek dosyası okunamadı.',
    );
    await expectRejected(
      _wrap({
        'kv': [
          {
            'key': 'timer',
            'value': {'status': 'nope'},
          },
        ],
      }),
      'Yedek dosyası okunamadı.',
    );
  });
}
