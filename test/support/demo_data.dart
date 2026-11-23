import 'package:mesk/data/db.dart';
import 'package:mesk/data/entries_repo.dart';
import 'package:mesk/data/goals_repo.dart';
import 'package:mesk/data/habits_repo.dart';
import 'package:mesk/data/kv_repo.dart';
import 'package:mesk/data/log_pipeline.dart';
import 'package:mesk/data/presets_repo.dart';
import 'package:mesk/data/skills_repo.dart';
import 'package:mesk/domain/day.dart';
import 'package:mesk/domain/models.dart';

import 'mockup.dart';

/// The mockup's "now": Saturday 21 November 2026, 21:00 in Istanbul.
FixedClock demoClock() =>
    FixedClock(DateTime.utc(2026, 11, 21, 18), offsetMinutes: 180);

/// Real seconds per skill. Together with the İngilizce bonus below they give
/// the mockup levels (Task 5) and 348 h of total real time.
const Map<String, int> _realSeconds = {
  'ingilizce': 97560, // 27,1 sa (+ 2,3 sa bonus = 29,4 sa XP, Sv. 23)
  'okuma': 210960, // 58,6 sa, Sv. 31
  'yazilim': 579600, // 161 sa, Sv. 47
  'satranc': 25920, // Sv. 12
  'hitabet': 5040, // Sv. 5
  'gitar': 61200, // Sv. 18
  'cizim': 14760, // Sv. 9
  'muzik-teorisi': 9000, // Sv. 7
  'gunluk-yazma': 11520, // Sv. 8
  'meditasyon': 21600, // Sv. 11
  'yoga': 7200, // Sv. 6
  'fitness': 165600, // Sv. 28
  'kosu': 43200, // Sv. 15
};

TimeEntry _entry(
  String id,
  String skillId,
  DateTime startedAt,
  int seconds, {
  EntrySource source = EntrySource.manual,
  int pomodoros = 0,
}) => TimeEntry(
  id: id,
  skillId: skillId,
  startedAt: startedAt,
  endedAt: startedAt.add(Duration(seconds: seconds)),
  offsetMinutes: 180,
  seconds: seconds,
  source: source,
  pomodoros: pomodoros,
);

List<TimeEntry> _entries() {
  final out = <TimeEntry>[
    // İngilizce: 96360 s earlier this month plus today's pomodoro, which is
    // the latest entry of all.
    _entry('ingilizce-1', 'ingilizce', DateTime.utc(2026, 11, 10, 6), 96360),
    _entry(
      'ingilizce-2',
      'ingilizce',
      DateTime.utc(2026, 11, 21, 16, 30),
      1200,
      source: EntrySource.pomodoro,
      pomodoros: 1,
    ),
    // Yazılım: last worked yesterday.
    _entry('yazilim-1', 'yazilim', DateTime.utc(2026, 2, 1, 6), 576000),
    _entry('yazilim-2', 'yazilim', DateTime.utc(2026, 11, 20, 15), 3600),
    // Okuma: last worked the day before yesterday; okuma-1 is the entry
    // whose link bonus went to İngilizce.
    _entry('okuma-1', 'okuma', DateTime.utc(2026, 9, 1, 6), 82800),
    _entry('okuma-2', 'okuma', DateTime.utc(2026, 4, 1, 6), 122760),
    _entry('okuma-3', 'okuma', DateTime.utc(2026, 11, 19, 17), 5400),
  ];
  var month = 3;
  for (final e in _realSeconds.entries) {
    if (const {'ingilizce', 'okuma', 'yazilim'}.contains(e.key)) continue;
    out.add(
      _entry('${e.key}-1', e.key, DateTime.utc(2026, month, 2, 6), e.value),
    );
    month = month == 10 ? 3 : month + 1;
  }
  return out;
}

Habit _habit(
  String id,
  String name,
  HabitKind kind,
  DateTime createdAt, {
  String? skillId,
  int? targetMinutes,
}) => Habit(
  id: id,
  name: name,
  kind: kind,
  skillId: skillId,
  targetMinutes: targetMinutes,
  schedule: const DailySchedule(),
  createdAt: createdAt,
);

/// Writes the approved mockup's dataset (see the Klasik "Bugün" artboard)
/// into [db]. Entries and awards are written directly; the pipeline only
/// settles level, goal and achievement rows afterwards.
Future<void> seedDemo(MeskDb db) async {
  final (skills, _) = mockupSkillsAndLevels();
  final skillsRepo = SkillsRepo(db);
  for (final s in skills) {
    await skillsRepo.put(s);
  }
  final linksRepo = LinksRepo(db);
  var i = 0;
  for (final (x, y) in mockupLinks) {
    await linksRepo.put(
      SkillLink.normalized(
        id: 'link-${++i}',
        x: x,
        y: y,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
  }

  final entries = EntriesRepo(db);
  for (final e in _entries()) {
    await entries.put(e);
  }
  await AwardsRepo(db).put(
    const XpAward(
      id: 'award-okuma-ingilizce',
      entryId: 'okuma-1',
      skillId: 'ingilizce',
      seconds: 8280,
      rateBp: 1000,
    ),
  );

  // Habits are listed in creation order: İngilizce, Erken kalk, Şekersiz gün.
  final habits = HabitsRepo(db);
  final nov1 = DateTime.utc(2026, 11, 1);
  await habits.put(
    _habit(
      'h-ingilizce',
      'İngilizce · 30 dk',
      HabitKind.timed,
      nov1,
      skillId: 'ingilizce',
      targetMinutes: 30,
    ),
  );
  await habits.put(
    _habit(
      'h-erken',
      'Erken kalk',
      HabitKind.simple,
      nov1.add(const Duration(minutes: 1)),
    ),
  );
  await habits.put(
    _habit(
      'h-sekersiz',
      'Şekersiz gün',
      HabitKind.simple,
      nov1.add(const Duration(minutes: 2)),
    ),
  );
  // Erken kalk: 12 days in a row up to today.
  for (var d = 10; d <= 21; d++) {
    await habits.toggleCheck('h-erken', LocalDay(2026, 11, d));
  }
  // Şekersiz gün: a best streak of 9 days, broken since.
  for (var d = 1; d <= 9; d++) {
    await habits.toggleCheck('h-sekersiz', LocalDay(2026, 11, d));
  }

  await GoalsRepo(db).put(
    Goal(
      id: 'g-ingilizce',
      skillId: 'ingilizce',
      targetSeconds: 100 * 3600,
      deadline: const LocalDay(2027, 3, 31),
      createdAt: nov1,
    ),
  );

  final kv = KvRepo(db);
  await kv.saveCharacter(const Character(name: 'Gezgin'));
  await kv.saveSettings(
    AppSettings(
      onboarded: true,
      lastSkillId: 'ingilizce',
      lastBackupAt: DateTime.utc(2026, 11, 18, 18),
    ),
  );
  await PresetsRepo(db).seedBuiltIns();
  await LogPipeline(db, demoClock()).recomputeAll();
}
