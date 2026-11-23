import 'package:flutter_test/flutter_test.dart';
import 'package:mesk/domain/achievements.dart';
import 'package:mesk/domain/day.dart';
import 'package:mesk/domain/models.dart';
import 'package:mesk/domain/stats.dart';

int _n = 0;

TimeEntry entry({
  String skill = 'A',
  DateTime? start,
  DateTime? end,
  int offset = 180,
  int seconds = 600,
  EntrySource source = EntrySource.manual,
  int pomodoros = 0,
}) {
  final s = start ?? DateTime.utc(2026, 3, 2, 10);
  return TimeEntry(
    id: 'e${_n++}',
    skillId: skill,
    startedAt: s,
    endedAt: end ?? s.add(Duration(seconds: seconds)),
    offsetMinutes: offset,
    seconds: seconds,
    source: source,
    pomodoros: pomodoros,
  );
}

AchievementContext ctx({
  List<TimeEntry> entries = const [],
  List<SkillLink> links = const [],
  Map<String, int> levels = const {},
  Map<Stat, int>? stats,
  int maxStreak = 0,
  bool perfectWeek = false,
  List<Goal> goals = const [],
  int totalLevel = 0,
}) => AchievementContext(
  entries: entries,
  links: links,
  levelBySkillId: levels,
  statDisplayValues: stats ?? {for (final s in Stat.values) s: 0},
  maxDailyStreak: maxStreak,
  hadPerfectWeek: perfectWeek,
  goals: goals,
  totalLevel: totalLevel,
  dayStartHour: 0,
);

SkillLink link(int i) =>
    SkillLink(id: 'l$i', a: 'a$i', b: 'b$i', createdAt: DateTime.utc(2026));

Goal goal({DateTime? completedAt, LocalDay? deadline}) => Goal(
  id: 'g',
  skillId: 'A',
  targetSeconds: 3600,
  deadline: deadline,
  createdAt: DateTime.utc(2026),
  completedAt: completedAt,
);

bool has(String key, AchievementContext c) =>
    metAchievementKeys(c).contains(key);

void main() {
  test('achievement defs verbatim', () {
    expect(generalAchievements.length, 23);
    expect(generalAchievements.first.name, 'İlk Adım');
    expect(generalAchievements.first.key, 'ilk_adim');
    expect(generalAchievements.last.name, 'Dönüş');
    expect(generalAchievements.last.key, 'donus');
    expect(generalAchievements.map((a) => a.key).toSet().length, 23);
    final byKey = {for (final a in generalAchievements) a.key: a};
    expect(byKey['sabahci']!.name, 'Sabahçı');
    expect(byKey['sabahci']!.condition, "07:00'den önce biten bir pomodoro");
  });

  test('empty context meets nothing', () {
    expect(metAchievementKeys(ctx()), isEmpty);
  });

  test('ilk_adim', () {
    expect(has('ilk_adim', ctx(entries: [entry()])), isTrue);
    expect(has('ilk_adim', ctx()), isFalse);
    expect(
      has('ilk_adim', ctx(entries: [entry(source: EntrySource.prior)])),
      isFalse,
    );
  });

  test('ilk_domates', () {
    expect(
      has(
        'ilk_domates',
        ctx(entries: [entry(source: EntrySource.pomodoro, pomodoros: 1)]),
      ),
      isTrue,
    );
    expect(
      has(
        'ilk_domates',
        ctx(entries: [entry(source: EntrySource.pomodoro, pomodoros: 0)]),
      ),
      isFalse,
    );
  });

  test('bereketli_gun: 8 on one local day, 7 misses', () {
    List<TimeEntry> day(int n) => [
      for (var i = 0; i < n; i++)
        entry(
          start: DateTime.utc(2026, 3, 2, 8, i * 10),
          source: EntrySource.pomodoro,
          pomodoros: 1,
        ),
    ];
    expect(has('bereketli_gun', ctx(entries: day(8))), isTrue);
    expect(has('bereketli_gun', ctx(entries: day(7))), isFalse);
    // 7 + 1 on the next local day does not reach 8.
    expect(
      has(
        'bereketli_gun',
        ctx(
          entries: [
            ...day(7),
            entry(
              start: DateTime.utc(2026, 3, 3, 8),
              source: EntrySource.pomodoro,
              pomodoros: 1,
            ),
          ],
        ),
      ),
      isFalse,
    );
    // Summed across entries on one day.
    expect(
      has(
        'bereketli_gun',
        ctx(
          entries: [
            entry(source: EntrySource.pomodoro, pomodoros: 4),
            entry(
              start: DateTime.utc(2026, 3, 2, 12),
              source: EntrySource.pomodoro,
              pomodoros: 4,
            ),
          ],
        ),
      ),
      isTrue,
    );
  });

  test('derin_dalis: 7200 s pomodoro/free, 7199 misses, manual does not', () {
    expect(
      has(
        'derin_dalis',
        ctx(entries: [entry(seconds: 7200, source: EntrySource.free)]),
      ),
      isTrue,
    );
    expect(
      has(
        'derin_dalis',
        ctx(entries: [entry(seconds: 7200, source: EntrySource.pomodoro)]),
      ),
      isTrue,
    );
    expect(
      has(
        'derin_dalis',
        ctx(entries: [entry(seconds: 7199, source: EntrySource.free)]),
      ),
      isFalse,
    );
    expect(
      has(
        'derin_dalis',
        ctx(entries: [entry(seconds: 7200, source: EntrySource.manual)]),
      ),
      isFalse,
    );
  });

  test('hour totals include prior experience', () {
    const h = 3600;
    expect(has('on_saat', ctx(entries: [entry(seconds: 10 * h)])), isTrue);
    expect(has('on_saat', ctx(entries: [entry(seconds: 10 * h - 1)])), isFalse);
    expect(
      has(
        'on_saat',
        ctx(
          entries: [entry(seconds: 10 * h, source: EntrySource.prior)],
        ),
      ),
      isTrue,
    );
    expect(
      has(
        'yuz_saat',
        ctx(
          entries: [
            entry(seconds: 60 * h),
            entry(seconds: 40 * h),
          ],
        ),
      ),
      isTrue,
    );
    expect(
      has('yuz_saat', ctx(entries: [entry(seconds: 100 * h - 1)])),
      isFalse,
    );
    expect(has('bin_saat', ctx(entries: [entry(seconds: 1000 * h)])), isTrue);
    expect(
      has('bin_saat', ctx(entries: [entry(seconds: 1000 * h - 1)])),
      isFalse,
    );
  });

  test('links', () {
    expect(has('ilk_bag', ctx(links: [link(0)])), isTrue);
    expect(has('ilk_bag', ctx()), isFalse);
    expect(
      has('takimyildiz', ctx(links: [for (var i = 0; i < 10; i++) link(i)])),
      isTrue,
    );
    expect(
      has('takimyildiz', ctx(links: [for (var i = 0; i < 9; i++) link(i)])),
      isFalse,
    );
  });

  test('cok_yonlu: five skills at level 10', () {
    Map<String, int> lv(int n, int level) => {
      for (var i = 0; i < n; i++) 's$i': level,
    };
    expect(has('cok_yonlu', ctx(levels: lv(5, 10))), isTrue);
    expect(has('cok_yonlu', ctx(levels: lv(4, 10))), isFalse);
    expect(has('cok_yonlu', ctx(levels: lv(5, 9))), isFalse);
  });

  test('ronesans: all six stats at least 10', () {
    final ok = {for (final s in Stat.values) s: 10};
    expect(has('ronesans', ctx(stats: ok)), isTrue);
    expect(has('ronesans', ctx(stats: {...ok, Stat.irade: 9})), isFalse);
    expect(has('ronesans', ctx(stats: {...ok}..remove(Stat.irade))), isFalse);
  });

  test('streaks', () {
    expect(has('yedi_gun', ctx(maxStreak: 7)), isTrue);
    expect(has('yedi_gun', ctx(maxStreak: 6)), isFalse);
    expect(has('otuz_gun', ctx(maxStreak: 30)), isTrue);
    expect(has('otuz_gun', ctx(maxStreak: 29)), isFalse);
    expect(has('yuz_gun', ctx(maxStreak: 100)), isTrue);
    expect(has('yuz_gun', ctx(maxStreak: 99)), isFalse);
  });

  test('kusursuz_hafta', () {
    expect(has('kusursuz_hafta', ctx(perfectWeek: true)), isTrue);
    expect(has('kusursuz_hafta', ctx()), isFalse);
  });

  test('hedefe_varis', () {
    expect(
      has('hedefe_varis', ctx(goals: [goal(completedAt: DateTime.utc(2026))])),
      isTrue,
    );
    expect(has('hedefe_varis', ctx(goals: [goal()])), isFalse);
  });

  test('sozunu_tutan: local day (UTC+3) of completion <= deadline', () {
    const deadline = LocalDay(2026, 3, 10);
    // 2026-03-10 20:59 UTC = 23:59 local -> on time.
    expect(
      has(
        'sozunu_tutan',
        ctx(
          goals: [
            goal(
              completedAt: DateTime.utc(2026, 3, 10, 20, 59),
              deadline: deadline,
            ),
          ],
        ),
      ),
      isTrue,
    );
    // 21:00 UTC = 00:00 on the 11th local -> late.
    expect(
      has(
        'sozunu_tutan',
        ctx(
          goals: [
            goal(
              completedAt: DateTime.utc(2026, 3, 10, 21),
              deadline: deadline,
            ),
          ],
        ),
      ),
      isFalse,
    );
    // No deadline never counts.
    expect(
      has(
        'sozunu_tutan',
        ctx(goals: [goal(completedAt: DateTime.utc(2026, 3, 1))]),
      ),
      isFalse,
    );
    // Incomplete goal never counts.
    expect(
      has('sozunu_tutan', ctx(goals: [goal(deadline: deadline)])),
      isFalse,
    );
  });

  test('toplam seviye', () {
    expect(has('toplam_100', ctx(totalLevel: 100)), isTrue);
    expect(has('toplam_100', ctx(totalLevel: 99)), isFalse);
    expect(has('toplam_250', ctx(totalLevel: 250)), isTrue);
    expect(has('toplam_250', ctx(totalLevel: 249)), isFalse);
    expect(has('toplam_500', ctx(totalLevel: 500)), isTrue);
    expect(has('toplam_500', ctx(totalLevel: 499)), isFalse);
  });

  TimeEntry endingAtLocal(
    int h,
    int m, {
    int offset = 180,
    EntrySource s = EntrySource.pomodoro,
  }) {
    final end = DateTime.utc(
      2026,
      3,
      2,
      h,
      m,
    ).subtract(Duration(minutes: offset));
    return entry(
      start: end.subtract(const Duration(minutes: 25)),
      end: end,
      offset: offset,
      seconds: 1500,
      source: s,
      pomodoros: 1,
    );
  }

  test('sabahci: local end in [05:00, 07:00)', () {
    expect(has('sabahci', ctx(entries: [endingAtLocal(6, 59)])), isTrue);
    expect(has('sabahci', ctx(entries: [endingAtLocal(5, 0)])), isTrue);
    expect(has('sabahci', ctx(entries: [endingAtLocal(7, 0)])), isFalse);
    expect(has('sabahci', ctx(entries: [endingAtLocal(4, 59)])), isFalse);
    // Uses the entry's own offset, not UTC.
    expect(
      has('sabahci', ctx(entries: [endingAtLocal(6, 30, offset: -300)])),
      isTrue,
    );
    expect(
      has('sabahci', ctx(entries: [endingAtLocal(6, 59, s: EntrySource.free)])),
      isFalse,
    );
  });

  test('gece_kusu: local end in [00:00, 05:00)', () {
    expect(has('gece_kusu', ctx(entries: [endingAtLocal(0, 0)])), isTrue);
    expect(has('gece_kusu', ctx(entries: [endingAtLocal(4, 59)])), isTrue);
    expect(has('gece_kusu', ctx(entries: [endingAtLocal(5, 0)])), isFalse);
    expect(has('gece_kusu', ctx(entries: [endingAtLocal(23, 59)])), isFalse);
    expect(
      has(
        'gece_kusu',
        ctx(entries: [endingAtLocal(2, 0, s: EntrySource.manual)]),
      ),
      isFalse,
    );
  });

  group('donus', () {
    TimeEntry on(
      int day, {
      String skill = 'A',
      EntrySource s = EntrySource.manual,
    }) => entry(skill: skill, start: DateTime.utc(2026, 1, day, 10), source: s);

    test('15 day gap meets, 14 misses', () {
      expect(has('donus', ctx(entries: [on(1), on(16)])), isTrue);
      expect(has('donus', ctx(entries: [on(1), on(15)])), isFalse);
    });

    test('order independent, same skill only, prior ignored', () {
      expect(has('donus', ctx(entries: [on(16), on(1)])), isTrue);
      expect(
        has(
          'donus',
          ctx(
            entries: [
              on(1),
              on(20, skill: 'B'),
            ],
          ),
        ),
        isFalse,
      );
      expect(
        has(
          'donus',
          ctx(
            entries: [
              on(1, s: EntrySource.prior),
              on(20),
            ],
          ),
        ),
        isFalse,
      );
    });

    test('only consecutive entries count', () {
      expect(has('donus', ctx(entries: [on(1), on(10), on(20)])), isFalse);
    });
  });
}
