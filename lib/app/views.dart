import '../domain/day.dart';
import '../domain/goals.dart';
import '../domain/habits.dart';
import '../domain/level_curve.dart';
import '../domain/models.dart';
import '../domain/stat_calc.dart';
import '../domain/stats.dart';
import '../domain/titles.dart';
import '../domain/xp.dart';

/// Everything a screen shows about one skill.
class SkillView {
  const SkillView({
    required this.skill,
    required this.totals,
    required this.level,
    required this.title,
    required this.band,
    required this.progress,
    required this.secondsToNext,
    required this.tier,
    required this.nextTier,
    required this.tierProgress,
    required this.activeGoal,
    required this.goal,
    required this.lastEntryAt,
  });

  final Skill skill;
  final SkillTotals totals;
  final int level;
  final String title;
  final Band band;

  /// Progress (0..1) toward the next level; 1 at level 99.
  final double progress;
  final int secondsToNext;

  /// The highest hidden tier reached, if any.
  final HiddenTier? tier;

  /// The hidden tier to aim for; only set from level 99 on.
  final HiddenTier? nextTier;
  final double tierProgress;

  /// The skill's goal that is neither completed nor closed.
  final Goal? activeGoal;

  /// Status of [activeGoal].
  final GoalStatus? goal;

  /// End of the latest tracked (non-prior) entry.
  final DateTime? lastEntryAt;
}

/// One [SkillView] per skill, in the order of [skills].
List<SkillView> buildSkillViews({
  required Iterable<Skill> skills,
  required Iterable<TimeEntry> entries,
  required Iterable<XpAward> awards,
  required Iterable<Goal> goals,
  required HabitDayData dayData,
  required LocalDay today,
}) {
  final totals = computeTotals(entries, awards);
  final lastEntry = <String, DateTime>{};
  for (final e in entries) {
    if (e.isPrior) continue;
    final last = lastEntry[e.skillId];
    if (last == null || e.endedAt.isAfter(last)) {
      lastEntry[e.skillId] = e.endedAt;
    }
  }
  final activeGoals = <String, Goal>{};
  for (final g in goals) {
    if (!g.active) continue;
    final other = activeGoals[g.skillId];
    if (other == null || g.createdAt.isAfter(other.createdAt)) {
      activeGoals[g.skillId] = g;
    }
  }

  return [
    for (final skill in skills)
      _view(
        skill,
        totals[skill.id] ?? SkillTotals.zero,
        activeGoals[skill.id],
        lastEntry[skill.id],
        dayData.trackedSecondsBySkillDay[skill.id] ?? const {},
        today,
      ),
  ];
}

SkillView _view(
  Skill skill,
  SkillTotals totals,
  Goal? goal,
  DateTime? lastEntryAt,
  Map<LocalDay, int> trackedByDay,
  LocalDay today,
) {
  final xp = totals.xpSeconds;
  final level = levelForXp(xp);
  GoalStatus? status;
  if (goal != null) {
    LocalDay? first;
    for (final d in trackedByDay.keys) {
      if (first == null || d.compareTo(first) < 0) first = d;
    }
    status = goalStatus(
      goal,
      realSeconds: totals.realSeconds,
      paceSecondsPerDay: paceSecondsPerDay(trackedByDay, today, first),
      today: today,
    );
  }
  return SkillView(
    skill: skill,
    totals: totals,
    level: level,
    title: titleForLevel(level),
    band: bandForLevel(level),
    progress: levelProgress(xp),
    secondsToNext: secondsToNextLevel(xp),
    tier: hiddenTierForXp(xp),
    nextTier: nextHiddenTier(xp),
    tierProgress: hiddenTierProgress(xp),
    activeGoal: goal,
    goal: status,
    lastEntryAt: lastEntryAt,
  );
}

/// The character summary of the Today and Character screens.
class CharacterView {
  const CharacterView({
    required this.totalLevel,
    required this.totalRealSeconds,
    required this.skillCount,
    required this.stats,
    required this.name,
    required this.displayTitle,
  });

  /// Sum of all skill levels, archived skills included (§5.6).
  final int totalLevel;

  /// Real time of all skills, prior experience and archived skills included.
  final int totalRealSeconds;

  /// All skills, archived included, like [totalLevel].
  final int skillCount;

  /// Display values (rounded) of all six stats.
  final Map<Stat, int> stats;
  final String name;

  /// The title the user picked, or the title of the highest skill.
  final String displayTitle;
}

/// [skills] must include archived skills; [iradePoints] is the habit score
/// of `iradePoints` over every habit.
CharacterView buildCharacterView({
  required List<SkillView> skills,
  required Character? character,
  required int iradePoints,
}) {
  final levels = {for (final v in skills) v.skill.id: v.level};
  final raw = sumContributions([
    skillStatValues([for (final v in skills) v.skill], levels),
    {Stat.irade: iradeFromPoints(iradePoints).toDouble()},
  ]);
  return CharacterView(
    totalLevel: skills.fold(0, (sum, v) => sum + v.level),
    totalRealSeconds: skills.fold(0, (sum, v) => sum + v.totals.realSeconds),
    skillCount: skills.length,
    stats: {for (final s in Stat.values) s: displayStatValue(raw[s] ?? 0)},
    name: character?.name ?? '',
    displayTitle: _displayTitle(skills, character),
  );
}

String _displayTitle(List<SkillView> skills, Character? character) {
  final chosenId = character?.titleSkillId;
  final chosenLevel = character?.titleLevel;
  if (chosenId != null && chosenLevel != null) {
    for (final v in skills) {
      // Only titles still earned count; otherwise fall back to the default.
      if (v.skill.id == chosenId && v.level >= chosenLevel) {
        return titleForLevel(chosenLevel);
      }
    }
  }
  SkillView? best;
  for (final v in skills) {
    if (best == null ||
        v.level > best.level ||
        (v.level == best.level && v.totals.xpSeconds > best.totals.xpSeconds)) {
      best = v;
    }
  }
  return best == null ? '' : best.title;
}
