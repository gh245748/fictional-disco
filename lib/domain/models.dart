import 'package:collection/collection.dart';
import 'package:uuid/uuid.dart';

import 'day.dart';
import 'level_curve.dart';
import 'stats.dart';

const _uuid = Uuid();

/// A new random (v4) identifier.
String newId() => _uuid.v4();

/// Sentinel so `copyWith` can distinguish "keep" from "set to null".
const Object _keep = Object();

T? _pick<T>(Object? v, T? current) => identical(v, _keep) ? current : v as T?;

String _iso(DateTime d) => d.toUtc().toIso8601String();
String? _isoN(DateTime? d) => d == null ? null : _iso(d);
DateTime _dt(Object? v) => DateTime.parse(v! as String).toUtc();
DateTime? _dtN(Object? v) => v == null ? null : _dt(v);
LocalDay? _dayN(Object? v) => v == null ? null : LocalDay.parse(v as String);
T _enum<T extends Enum>(List<T> values, Object? name) =>
    values.byName(name! as String);
T? _enumN<T extends Enum>(List<T> values, Object? name) =>
    name == null ? null : values.byName(name as String);

class Character {
  const Character({required this.name, this.titleSkillId, this.titleLevel});

  factory Character.fromJson(Map<String, Object?> j) => Character(
    name: j['name']! as String,
    titleSkillId: j['titleSkillId'] as String?,
    titleLevel: j['titleLevel'] as int?,
  );

  final String name;
  final String? titleSkillId;
  final int? titleLevel;

  Character copyWith({
    String? name,
    Object? titleSkillId = _keep,
    Object? titleLevel = _keep,
  }) => Character(
    name: name ?? this.name,
    titleSkillId: _pick<String>(titleSkillId, this.titleSkillId),
    titleLevel: _pick<int>(titleLevel, this.titleLevel),
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'titleSkillId': titleSkillId,
    'titleLevel': titleLevel,
  };

  @override
  bool operator ==(Object other) =>
      other is Character &&
      other.name == name &&
      other.titleSkillId == titleSkillId &&
      other.titleLevel == titleLevel;

  @override
  int get hashCode => Object.hash(name, titleSkillId, titleLevel);
}

class Skill {
  const Skill({
    required this.id,
    required this.name,
    required this.primary,
    this.secondary,
    this.description,
    required this.createdAt,
    this.archivedAt,
    this.graphX,
    this.graphY,
  });

  factory Skill.fromJson(Map<String, Object?> j) => Skill(
    id: j['id']! as String,
    name: j['name']! as String,
    primary: _enum(Stat.values, j['primary']),
    secondary: _enumN(Stat.values, j['secondary']),
    description: j['description'] as String?,
    createdAt: _dt(j['createdAt']),
    archivedAt: _dtN(j['archivedAt']),
    graphX: (j['graphX'] as num?)?.toDouble(),
    graphY: (j['graphY'] as num?)?.toDouble(),
  );

  final String id;
  final String name;
  final Stat primary;
  final Stat? secondary;
  final String? description;
  final DateTime createdAt;
  final DateTime? archivedAt;
  final double? graphX;
  final double? graphY;

  bool get archived => archivedAt != null;

  Skill copyWith({
    String? name,
    Stat? primary,
    Object? secondary = _keep,
    Object? description = _keep,
    Object? archivedAt = _keep,
    Object? graphX = _keep,
    Object? graphY = _keep,
  }) => Skill(
    id: id,
    name: name ?? this.name,
    primary: primary ?? this.primary,
    secondary: _pick<Stat>(secondary, this.secondary),
    description: _pick<String>(description, this.description),
    createdAt: createdAt,
    archivedAt: _pick<DateTime>(archivedAt, this.archivedAt),
    graphX: _pick<double>(graphX, this.graphX),
    graphY: _pick<double>(graphY, this.graphY),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'primary': primary.name,
    'secondary': secondary?.name,
    'description': description,
    'createdAt': _iso(createdAt),
    'archivedAt': _isoN(archivedAt),
    'graphX': graphX,
    'graphY': graphY,
  };

  @override
  bool operator ==(Object other) =>
      other is Skill &&
      other.id == id &&
      other.name == name &&
      other.primary == primary &&
      other.secondary == secondary &&
      other.description == description &&
      other.createdAt == createdAt &&
      other.archivedAt == archivedAt &&
      other.graphX == graphX &&
      other.graphY == graphY;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    primary,
    secondary,
    description,
    createdAt,
    archivedAt,
    graphX,
    graphY,
  );
}

class SkillLink {
  const SkillLink({
    required this.id,
    required this.a,
    required this.b,
    required this.createdAt,
  });

  /// Stores the pair sorted so that `a < b`.
  factory SkillLink.normalized({
    required String id,
    required String x,
    required String y,
    required DateTime createdAt,
  }) {
    assert(x != y, 'A skill cannot link to itself');
    final swap = x.compareTo(y) > 0;
    return SkillLink(
      id: id,
      a: swap ? y : x,
      b: swap ? x : y,
      createdAt: createdAt,
    );
  }

  factory SkillLink.fromJson(Map<String, Object?> j) => SkillLink(
    id: j['id']! as String,
    a: j['a']! as String,
    b: j['b']! as String,
    createdAt: _dt(j['createdAt']),
  );

  final String id;
  final String a;
  final String b;
  final DateTime createdAt;

  SkillLink copyWith({String? a, String? b}) =>
      SkillLink(id: id, a: a ?? this.a, b: b ?? this.b, createdAt: createdAt);

  Map<String, Object?> toJson() => {
    'id': id,
    'a': a,
    'b': b,
    'createdAt': _iso(createdAt),
  };

  @override
  bool operator ==(Object other) =>
      other is SkillLink &&
      other.id == id &&
      other.a == a &&
      other.b == b &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, a, b, createdAt);
}

enum EntrySource { pomodoro, free, manual, prior }

class TimeEntry {
  const TimeEntry({
    required this.id,
    required this.skillId,
    required this.startedAt,
    required this.endedAt,
    required this.offsetMinutes,
    required this.seconds,
    required this.source,
    required this.pomodoros,
    this.note,
  });

  factory TimeEntry.fromJson(Map<String, Object?> j) => TimeEntry(
    id: j['id']! as String,
    skillId: j['skillId']! as String,
    startedAt: _dt(j['startedAt']),
    endedAt: _dt(j['endedAt']),
    offsetMinutes: j['offsetMinutes']! as int,
    seconds: j['seconds']! as int,
    source: _enum(EntrySource.values, j['source']),
    pomodoros: j['pomodoros']! as int,
    note: j['note'] as String?,
  );

  final String id;
  final String skillId;
  final DateTime startedAt;
  final DateTime endedAt;
  final int offsetMinutes;
  final int seconds;
  final EntrySource source;
  final int pomodoros;
  final String? note;

  bool get isPrior => source == EntrySource.prior;

  TimeEntry copyWith({
    String? skillId,
    DateTime? startedAt,
    DateTime? endedAt,
    int? offsetMinutes,
    int? seconds,
    EntrySource? source,
    int? pomodoros,
    Object? note = _keep,
  }) => TimeEntry(
    id: id,
    skillId: skillId ?? this.skillId,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt ?? this.endedAt,
    offsetMinutes: offsetMinutes ?? this.offsetMinutes,
    seconds: seconds ?? this.seconds,
    source: source ?? this.source,
    pomodoros: pomodoros ?? this.pomodoros,
    note: _pick<String>(note, this.note),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'skillId': skillId,
    'startedAt': _iso(startedAt),
    'endedAt': _iso(endedAt),
    'offsetMinutes': offsetMinutes,
    'seconds': seconds,
    'source': source.name,
    'pomodoros': pomodoros,
    'note': note,
  };

  @override
  bool operator ==(Object other) =>
      other is TimeEntry &&
      other.id == id &&
      other.skillId == skillId &&
      other.startedAt == startedAt &&
      other.endedAt == endedAt &&
      other.offsetMinutes == offsetMinutes &&
      other.seconds == seconds &&
      other.source == source &&
      other.pomodoros == pomodoros &&
      other.note == note;

  @override
  int get hashCode => Object.hash(
    id,
    skillId,
    startedAt,
    endedAt,
    offsetMinutes,
    seconds,
    source,
    pomodoros,
    note,
  );
}

class XpAward {
  const XpAward({
    required this.id,
    required this.entryId,
    required this.skillId,
    required this.seconds,
    required this.rateBp,
  });

  factory XpAward.fromJson(Map<String, Object?> j) => XpAward(
    id: j['id']! as String,
    entryId: j['entryId']! as String,
    skillId: j['skillId']! as String,
    seconds: j['seconds']! as int,
    rateBp: j['rateBp']! as int,
  );

  final String id;
  final String entryId;
  final String skillId;
  final int seconds;
  final int rateBp;

  XpAward copyWith({String? skillId, int? seconds, int? rateBp}) => XpAward(
    id: id,
    entryId: entryId,
    skillId: skillId ?? this.skillId,
    seconds: seconds ?? this.seconds,
    rateBp: rateBp ?? this.rateBp,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'entryId': entryId,
    'skillId': skillId,
    'seconds': seconds,
    'rateBp': rateBp,
  };

  @override
  bool operator ==(Object other) =>
      other is XpAward &&
      other.id == id &&
      other.entryId == entryId &&
      other.skillId == skillId &&
      other.seconds == seconds &&
      other.rateBp == rateBp;

  @override
  int get hashCode => Object.hash(id, entryId, skillId, seconds, rateBp);
}

class LevelReached {
  const LevelReached({
    required this.skillId,
    required this.level,
    required this.at,
  });

  factory LevelReached.fromJson(Map<String, Object?> j) => LevelReached(
    skillId: j['skillId']! as String,
    level: j['level']! as int,
    at: _dt(j['at']),
  );

  final String skillId;
  final int level;
  final DateTime at;

  LevelReached copyWith({int? level, DateTime? at}) => LevelReached(
    skillId: skillId,
    level: level ?? this.level,
    at: at ?? this.at,
  );

  Map<String, Object?> toJson() => {
    'skillId': skillId,
    'level': level,
    'at': _iso(at),
  };

  @override
  bool operator ==(Object other) =>
      other is LevelReached &&
      other.skillId == skillId &&
      other.level == level &&
      other.at == at;

  @override
  int get hashCode => Object.hash(skillId, level, at);
}

class TierReached {
  const TierReached({
    required this.skillId,
    required this.tier,
    required this.at,
  });

  factory TierReached.fromJson(Map<String, Object?> j) => TierReached(
    skillId: j['skillId']! as String,
    tier: _enum(HiddenTier.values, j['tier']),
    at: _dt(j['at']),
  );

  final String skillId;
  final HiddenTier tier;
  final DateTime at;

  TierReached copyWith({HiddenTier? tier, DateTime? at}) =>
      TierReached(skillId: skillId, tier: tier ?? this.tier, at: at ?? this.at);

  Map<String, Object?> toJson() => {
    'skillId': skillId,
    'tier': tier.name,
    'at': _iso(at),
  };

  @override
  bool operator ==(Object other) =>
      other is TierReached &&
      other.skillId == skillId &&
      other.tier == tier &&
      other.at == at;

  @override
  int get hashCode => Object.hash(skillId, tier, at);
}

class AchievementUnlock {
  const AchievementUnlock({required this.key, required this.at});

  factory AchievementUnlock.fromJson(Map<String, Object?> j) =>
      AchievementUnlock(key: j['key']! as String, at: _dt(j['at']));

  final String key;
  final DateTime at;

  AchievementUnlock copyWith({DateTime? at}) =>
      AchievementUnlock(key: key, at: at ?? this.at);

  Map<String, Object?> toJson() => {'key': key, 'at': _iso(at)};

  @override
  bool operator ==(Object other) =>
      other is AchievementUnlock && other.key == key && other.at == at;

  @override
  int get hashCode => Object.hash(key, at);
}

enum HabitKind { timed, simple }

sealed class HabitSchedule {
  const HabitSchedule();

  factory HabitSchedule.fromJson(Map<String, Object?> j) => switch (j['type']) {
    'daily' => const DailySchedule(),
    'weekdays' => WeekdaysSchedule({
      for (final d in j['weekdays']! as List<Object?>) d! as int,
    }),
    'timesPerWeek' => TimesPerWeekSchedule(j['times']! as int),
    final t => throw FormatException('Unknown schedule type', t),
  };

  Map<String, Object?> toJson();
}

class DailySchedule extends HabitSchedule {
  const DailySchedule();

  @override
  Map<String, Object?> toJson() => {'type': 'daily'};

  @override
  bool operator ==(Object other) => other is DailySchedule;

  @override
  int get hashCode => 'daily'.hashCode;
}

/// Specific weekdays, 1 = Monday ... 7 = Sunday.
class WeekdaysSchedule extends HabitSchedule {
  const WeekdaysSchedule(this.weekdays);

  final Set<int> weekdays;

  @override
  Map<String, Object?> toJson() => {
    'type': 'weekdays',
    'weekdays': (weekdays.toList()..sort()),
  };

  @override
  bool operator ==(Object other) =>
      other is WeekdaysSchedule &&
      const SetEquality<int>().equals(other.weekdays, weekdays);

  @override
  int get hashCode => const SetEquality<int>().hash(weekdays);
}

/// [times] completions per week, 1-7.
class TimesPerWeekSchedule extends HabitSchedule {
  const TimesPerWeekSchedule(this.times);

  final int times;

  @override
  Map<String, Object?> toJson() => {'type': 'timesPerWeek', 'times': times};

  @override
  bool operator ==(Object other) =>
      other is TimesPerWeekSchedule && other.times == times;

  @override
  int get hashCode => Object.hash('timesPerWeek', times);
}

class Habit {
  const Habit({
    required this.id,
    required this.name,
    required this.kind,
    this.skillId,
    this.targetMinutes,
    required this.schedule,
    this.reminderMinuteOfDay,
    required this.createdAt,
    this.archivedAt,
  });

  factory Habit.fromJson(Map<String, Object?> j) => Habit(
    id: j['id']! as String,
    name: j['name']! as String,
    kind: _enum(HabitKind.values, j['kind']),
    skillId: j['skillId'] as String?,
    targetMinutes: j['targetMinutes'] as int?,
    schedule: HabitSchedule.fromJson(
      (j['schedule']! as Map).cast<String, Object?>(),
    ),
    reminderMinuteOfDay: j['reminderMinuteOfDay'] as int?,
    createdAt: _dt(j['createdAt']),
    archivedAt: _dtN(j['archivedAt']),
  );

  final String id;
  final String name;
  final HabitKind kind;
  final String? skillId;
  final int? targetMinutes;
  final HabitSchedule schedule;
  final int? reminderMinuteOfDay;
  final DateTime createdAt;
  final DateTime? archivedAt;

  Habit copyWith({
    String? name,
    HabitKind? kind,
    Object? skillId = _keep,
    Object? targetMinutes = _keep,
    HabitSchedule? schedule,
    Object? reminderMinuteOfDay = _keep,
    Object? archivedAt = _keep,
  }) => Habit(
    id: id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    skillId: _pick<String>(skillId, this.skillId),
    targetMinutes: _pick<int>(targetMinutes, this.targetMinutes),
    schedule: schedule ?? this.schedule,
    reminderMinuteOfDay: _pick<int>(
      reminderMinuteOfDay,
      this.reminderMinuteOfDay,
    ),
    createdAt: createdAt,
    archivedAt: _pick<DateTime>(archivedAt, this.archivedAt),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'skillId': skillId,
    'targetMinutes': targetMinutes,
    'schedule': schedule.toJson(),
    'reminderMinuteOfDay': reminderMinuteOfDay,
    'createdAt': _iso(createdAt),
    'archivedAt': _isoN(archivedAt),
  };

  @override
  bool operator ==(Object other) =>
      other is Habit &&
      other.id == id &&
      other.name == name &&
      other.kind == kind &&
      other.skillId == skillId &&
      other.targetMinutes == targetMinutes &&
      other.schedule == schedule &&
      other.reminderMinuteOfDay == reminderMinuteOfDay &&
      other.createdAt == createdAt &&
      other.archivedAt == archivedAt;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    kind,
    skillId,
    targetMinutes,
    schedule,
    reminderMinuteOfDay,
    createdAt,
    archivedAt,
  );
}

class HabitCheck {
  const HabitCheck({required this.habitId, required this.day});

  factory HabitCheck.fromJson(Map<String, Object?> j) => HabitCheck(
    habitId: j['habitId']! as String,
    day: LocalDay.parse(j['day']! as String),
  );

  final String habitId;
  final LocalDay day;

  HabitCheck copyWith({LocalDay? day}) =>
      HabitCheck(habitId: habitId, day: day ?? this.day);

  Map<String, Object?> toJson() => {'habitId': habitId, 'day': day.toIso()};

  @override
  bool operator ==(Object other) =>
      other is HabitCheck && other.habitId == habitId && other.day == day;

  @override
  int get hashCode => Object.hash(habitId, day);
}

class Goal {
  const Goal({
    required this.id,
    required this.skillId,
    required this.targetSeconds,
    this.deadline,
    required this.createdAt,
    this.completedAt,
    this.closedAt,
  });

  factory Goal.fromJson(Map<String, Object?> j) => Goal(
    id: j['id']! as String,
    skillId: j['skillId']! as String,
    targetSeconds: j['targetSeconds']! as int,
    deadline: _dayN(j['deadline']),
    createdAt: _dt(j['createdAt']),
    completedAt: _dtN(j['completedAt']),
    closedAt: _dtN(j['closedAt']),
  );

  final String id;
  final String skillId;
  final int targetSeconds;
  final LocalDay? deadline;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? closedAt;

  /// Neither completed nor closed.
  bool get active => completedAt == null && closedAt == null;

  Goal copyWith({
    int? targetSeconds,
    Object? deadline = _keep,
    Object? completedAt = _keep,
    Object? closedAt = _keep,
  }) => Goal(
    id: id,
    skillId: skillId,
    targetSeconds: targetSeconds ?? this.targetSeconds,
    deadline: _pick<LocalDay>(deadline, this.deadline),
    createdAt: createdAt,
    completedAt: _pick<DateTime>(completedAt, this.completedAt),
    closedAt: _pick<DateTime>(closedAt, this.closedAt),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'skillId': skillId,
    'targetSeconds': targetSeconds,
    'deadline': deadline?.toIso(),
    'createdAt': _iso(createdAt),
    'completedAt': _isoN(completedAt),
    'closedAt': _isoN(closedAt),
  };

  @override
  bool operator ==(Object other) =>
      other is Goal &&
      other.id == id &&
      other.skillId == skillId &&
      other.targetSeconds == targetSeconds &&
      other.deadline == deadline &&
      other.createdAt == createdAt &&
      other.completedAt == completedAt &&
      other.closedAt == closedAt;

  @override
  int get hashCode => Object.hash(
    id,
    skillId,
    targetSeconds,
    deadline,
    createdAt,
    completedAt,
    closedAt,
  );
}

class TimerPreset {
  const TimerPreset(
    this.id,
    this.name,
    this.workMinutes,
    this.shortBreakMinutes,
    this.longBreakMinutes,
    this.roundsBeforeLong,
    this.autoStartBreaks,
    this.autoStartWork,
    this.builtIn,
  );

  factory TimerPreset.fromJson(Map<String, Object?> j) => TimerPreset(
    j['id']! as String,
    j['name']! as String,
    j['workMinutes']! as int,
    j['shortBreakMinutes']! as int,
    j['longBreakMinutes']! as int,
    j['roundsBeforeLong']! as int,
    j['autoStartBreaks']! as bool,
    j['autoStartWork']! as bool,
    j['builtIn']! as bool,
  );

  static const List<TimerPreset> builtIns = [
    TimerPreset('klasik', 'Klasik 25/5', 25, 5, 15, 4, true, false, true),
    TimerPreset(
      'derin',
      'Derin çalışma 50/10',
      50,
      10,
      30,
      2,
      true,
      false,
      true,
    ),
  ];

  final String id;
  final String name;
  final int workMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;
  final int roundsBeforeLong;
  final bool autoStartBreaks;
  final bool autoStartWork;
  final bool builtIn;

  /// Turkish error message for the first out-of-range value (§5.7), or null.
  String? validate() {
    if (workMinutes < 1 || workMinutes > 180) {
      return 'Çalışma süresi 1 ile 180 dakika arasında olmalı';
    }
    if (shortBreakMinutes < 1 || shortBreakMinutes > 60) {
      return 'Kısa mola 1 ile 60 dakika arasında olmalı';
    }
    if (longBreakMinutes < 1 || longBreakMinutes > 90) {
      return 'Uzun mola 1 ile 90 dakika arasında olmalı';
    }
    if (roundsBeforeLong < 1 || roundsBeforeLong > 12) {
      return 'Uzun mola öncesi tur sayısı 1 ile 12 arasında olmalı';
    }
    return null;
  }

  TimerPreset copyWith({
    String? name,
    int? workMinutes,
    int? shortBreakMinutes,
    int? longBreakMinutes,
    int? roundsBeforeLong,
    bool? autoStartBreaks,
    bool? autoStartWork,
  }) => TimerPreset(
    id,
    name ?? this.name,
    workMinutes ?? this.workMinutes,
    shortBreakMinutes ?? this.shortBreakMinutes,
    longBreakMinutes ?? this.longBreakMinutes,
    roundsBeforeLong ?? this.roundsBeforeLong,
    autoStartBreaks ?? this.autoStartBreaks,
    autoStartWork ?? this.autoStartWork,
    builtIn,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'workMinutes': workMinutes,
    'shortBreakMinutes': shortBreakMinutes,
    'longBreakMinutes': longBreakMinutes,
    'roundsBeforeLong': roundsBeforeLong,
    'autoStartBreaks': autoStartBreaks,
    'autoStartWork': autoStartWork,
    'builtIn': builtIn,
  };

  @override
  bool operator ==(Object other) =>
      other is TimerPreset &&
      other.id == id &&
      other.name == name &&
      other.workMinutes == workMinutes &&
      other.shortBreakMinutes == shortBreakMinutes &&
      other.longBreakMinutes == longBreakMinutes &&
      other.roundsBeforeLong == roundsBeforeLong &&
      other.autoStartBreaks == autoStartBreaks &&
      other.autoStartWork == autoStartWork &&
      other.builtIn == builtIn;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    workMinutes,
    shortBreakMinutes,
    longBreakMinutes,
    roundsBeforeLong,
    autoStartBreaks,
    autoStartWork,
    builtIn,
  );
}

class AppSettings {
  const AppSettings({
    this.bonusRateBp = 1000,
    this.dayStartHour = 0,
    this.sound = true,
    this.vibration = true,
    this.lastBackupAt,
    this.lastSkillId,
    this.lastPresetBySkill = const {},
    this.onboarded = false,
  });

  factory AppSettings.fromJson(Map<String, Object?> j) => AppSettings(
    bonusRateBp: j['bonusRateBp']! as int,
    dayStartHour: j['dayStartHour']! as int,
    sound: j['sound']! as bool,
    vibration: j['vibration']! as bool,
    lastBackupAt: _dtN(j['lastBackupAt']),
    lastSkillId: j['lastSkillId'] as String?,
    lastPresetBySkill: {
      for (final e in (j['lastPresetBySkill']! as Map).entries)
        e.key as String: e.value as String,
    },
    onboarded: j['onboarded']! as bool,
  );

  static const AppSettings defaults = AppSettings();

  final int bonusRateBp;
  final int dayStartHour;
  final bool sound;
  final bool vibration;
  final DateTime? lastBackupAt;
  final String? lastSkillId;
  final Map<String, String> lastPresetBySkill;
  final bool onboarded;

  AppSettings copyWith({
    int? bonusRateBp,
    int? dayStartHour,
    bool? sound,
    bool? vibration,
    Object? lastBackupAt = _keep,
    Object? lastSkillId = _keep,
    Map<String, String>? lastPresetBySkill,
    bool? onboarded,
  }) => AppSettings(
    bonusRateBp: bonusRateBp ?? this.bonusRateBp,
    dayStartHour: dayStartHour ?? this.dayStartHour,
    sound: sound ?? this.sound,
    vibration: vibration ?? this.vibration,
    lastBackupAt: _pick<DateTime>(lastBackupAt, this.lastBackupAt),
    lastSkillId: _pick<String>(lastSkillId, this.lastSkillId),
    lastPresetBySkill: lastPresetBySkill ?? this.lastPresetBySkill,
    onboarded: onboarded ?? this.onboarded,
  );

  Map<String, Object?> toJson() => {
    'bonusRateBp': bonusRateBp,
    'dayStartHour': dayStartHour,
    'sound': sound,
    'vibration': vibration,
    'lastBackupAt': _isoN(lastBackupAt),
    'lastSkillId': lastSkillId,
    'lastPresetBySkill': lastPresetBySkill,
    'onboarded': onboarded,
  };

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.bonusRateBp == bonusRateBp &&
      other.dayStartHour == dayStartHour &&
      other.sound == sound &&
      other.vibration == vibration &&
      other.lastBackupAt == lastBackupAt &&
      other.lastSkillId == lastSkillId &&
      const MapEquality<String, String>().equals(
        other.lastPresetBySkill,
        lastPresetBySkill,
      ) &&
      other.onboarded == onboarded;

  @override
  int get hashCode => Object.hash(
    bonusRateBp,
    dayStartHour,
    sound,
    vibration,
    lastBackupAt,
    lastSkillId,
    const MapEquality<String, String>().hash(lastPresetBySkill),
    onboarded,
  );
}
