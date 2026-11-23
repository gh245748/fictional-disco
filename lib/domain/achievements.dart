import 'day.dart';
import 'models.dart';
import 'stats.dart';

class AchievementDef {
  const AchievementDef(this.key, this.name, this.condition);

  final String key;
  final String name;
  final String condition;
}

/// Spec Ek B, in table order.
const List<AchievementDef> generalAchievements = [
  AchievementDef('ilk_adim', 'İlk Adım', 'İlk süre kaydı'),
  AchievementDef('ilk_domates', 'İlk Domates', 'İlk tamamlanan pomodoro'),
  AchievementDef('bereketli_gun', 'Bereketli Gün', 'Bir günde 8 pomodoro'),
  AchievementDef('derin_dalis', 'Derin Dalış', 'Tek oturumda 2 saat çalışma'),
  AchievementDef('on_saat', 'On Saatlik Yol', 'Toplam 10 saat gerçek süre'),
  AchievementDef('yuz_saat', 'Yüz Saat', 'Toplam 100 saat'),
  AchievementDef('bin_saat', 'Bin Saat', 'Toplam 1000 saat'),
  AchievementDef('ilk_bag', 'İlk Bağ', 'İlk bağlantı'),
  AchievementDef('takimyildiz', 'Takımyıldız', 'Ağda 10 bağlantı'),
  AchievementDef('cok_yonlu', 'Çok Yönlü', '5 yetenekte Sv. 10'),
  AchievementDef('ronesans', 'Rönesans', 'Altı statın hepsi en az 10'),
  AchievementDef('yedi_gun', 'Yedi Gün', 'Bir alışkanlıkta 7 günlük seri'),
  AchievementDef('otuz_gun', 'Otuz Gün', '30 günlük seri'),
  AchievementDef('yuz_gun', 'Yüz Gün', '100 günlük seri'),
  AchievementDef(
    'kusursuz_hafta',
    'Kusursuz Hafta',
    'Bir haftada planlı bütün alışkanlıklar tamam',
  ),
  AchievementDef('hedefe_varis', 'Hedefe Varış', 'İlk tamamlanan hedef'),
  AchievementDef(
    'sozunu_tutan',
    'Sözünü Tutan',
    'Bir hedefi bitiş tarihinden önce tamamlamak',
  ),
  AchievementDef('toplam_100', 'Toplam 100', 'Toplam seviye 100'),
  AchievementDef('toplam_250', 'Toplam 250', 'Toplam seviye 250'),
  AchievementDef('toplam_500', 'Toplam 500', 'Toplam seviye 500'),
  AchievementDef('sabahci', 'Sabahçı', "07:00'den önce biten bir pomodoro"),
  AchievementDef(
    'gece_kusu',
    'Gece Kuşu',
    'Gece yarısından sonra biten bir pomodoro',
  ),
  AchievementDef(
    'donus',
    'Dönüş',
    '14 günden uzun bir aradan sonra bir yeteneğe geri dönmek',
  ),
];

/// Everything [metAchievementKeys] reads. Streak and perfect-week values come
/// from the habit helpers and are passed in as plain values.
class AchievementContext {
  const AchievementContext({
    required this.entries,
    required this.links,
    required this.levelBySkillId,
    required this.statDisplayValues,
    required this.maxDailyStreak,
    required this.hadPerfectWeek,
    required this.goals,
    required this.totalLevel,
    required this.dayStartHour,
  });

  final List<TimeEntry> entries;
  final List<SkillLink> links;
  final Map<String, int> levelBySkillId;
  final Map<Stat, int> statDisplayValues;
  final int maxDailyStreak;
  final bool hadPerfectWeek;
  final List<Goal> goals;
  final int totalLevel;
  final int dayStartHour;
}

const int _hour = 3600;

/// Turkey has a fixed UTC+3 offset and [Goal] stores no offset, so goal
/// completion is judged in UTC+3 (assumption).
const int _goalOffsetMinutes = 180;

Set<String> metAchievementKeys(AchievementContext ctx) {
  final met = <String>{};
  final real = ctx.entries.where((e) => !e.isPrior).toList();

  // "First time record": prior experience is not a tracked step.
  if (real.isNotEmpty) met.add('ilk_adim');
  if (real.any((e) => e.pomodoros >= 1)) met.add('ilk_domates');

  final pomodorosByDay = <LocalDay, int>{};
  for (final e in real) {
    final d = dayOfInstant(e.startedAt, e.offsetMinutes, ctx.dayStartHour);
    pomodorosByDay[d] = (pomodorosByDay[d] ?? 0) + e.pomodoros;
  }
  if (pomodorosByDay.values.any((n) => n >= 8)) met.add('bereketli_gun');

  if (real.any(
    (e) =>
        (e.source == EntrySource.pomodoro || e.source == EntrySource.free) &&
        e.seconds >= 2 * _hour,
  )) {
    met.add('derin_dalis');
  }

  final totalSeconds = ctx.entries.fold<int>(0, (s, e) => s + e.seconds);
  if (totalSeconds >= 10 * _hour) met.add('on_saat');
  if (totalSeconds >= 100 * _hour) met.add('yuz_saat');
  if (totalSeconds >= 1000 * _hour) met.add('bin_saat');

  if (ctx.links.isNotEmpty) met.add('ilk_bag');
  if (ctx.links.length >= 10) met.add('takimyildiz');

  if (ctx.levelBySkillId.values.where((l) => l >= 10).length >= 5) {
    met.add('cok_yonlu');
  }
  if (Stat.values.every((s) => (ctx.statDisplayValues[s] ?? 0) >= 10)) {
    met.add('ronesans');
  }

  if (ctx.maxDailyStreak >= 7) met.add('yedi_gun');
  if (ctx.maxDailyStreak >= 30) met.add('otuz_gun');
  if (ctx.maxDailyStreak >= 100) met.add('yuz_gun');
  if (ctx.hadPerfectWeek) met.add('kusursuz_hafta');

  if (ctx.goals.any((g) => g.completedAt != null)) met.add('hedefe_varis');
  if (ctx.goals.any((g) {
    final done = g.completedAt;
    final deadline = g.deadline;
    if (done == null || deadline == null) return false;
    return dayOfInstant(done, _goalOffsetMinutes, 0).compareTo(deadline) <= 0;
  })) {
    met.add('sozunu_tutan');
  }

  if (ctx.totalLevel >= 100) met.add('toplam_100');
  if (ctx.totalLevel >= 250) met.add('toplam_250');
  if (ctx.totalLevel >= 500) met.add('toplam_500');

  for (final e in real.where((e) => e.source == EntrySource.pomodoro)) {
    final local = e.endedAt.toUtc().add(Duration(minutes: e.offsetMinutes));
    final minuteOfDay = local.hour * 60 + local.minute;
    if (minuteOfDay >= 5 * 60 && minuteOfDay < 7 * 60) met.add('sabahci');
    if (minuteOfDay < 5 * 60) met.add('gece_kusu');
  }

  final bySkill = <String, List<TimeEntry>>{};
  for (final e in real) {
    (bySkill[e.skillId] ??= []).add(e);
  }
  outer:
  for (final list in bySkill.values) {
    list.sort((a, b) => a.startedAt.compareTo(b.startedAt));
    for (var i = 1; i < list.length; i++) {
      final prev = list[i - 1];
      final cur = list[i];
      final a = dayOfInstant(
        prev.startedAt,
        prev.offsetMinutes,
        ctx.dayStartHour,
      );
      final b = dayOfInstant(
        cur.startedAt,
        cur.offsetMinutes,
        ctx.dayStartHour,
      );
      if (a.daysUntil(b) > 14) {
        met.add('donus');
        break outer;
      }
    }
  }

  return met;
}
