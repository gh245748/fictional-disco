import 'package:sembast/sembast.dart';

import '../domain/achievements.dart';
import '../domain/day.dart';
import '../domain/goals.dart';
import '../domain/habits.dart';
import '../domain/level_curve.dart';
import '../domain/level_events.dart';
import '../domain/models.dart';
import '../domain/stat_calc.dart';
import '../domain/stats.dart';
import '../domain/xp.dart';
import 'db.dart';
import 'entries_repo.dart';
import 'events_repo.dart';
import 'goals_repo.dart';
import 'habits_repo.dart';
import 'kv_repo.dart';
import 'skills_repo.dart';

class PipelineResult {
  const PipelineResult(this.celebrations);

  /// Level and tier cards, then goal cards, then achievement cards.
  final List<Celebration> celebrations;
}

/// Everything the pipeline reads, loaded at once (the dataset is small).
class _Snapshot {
  _Snapshot({
    required this.skills,
    required this.links,
    required this.entries,
    required this.awards,
    required this.levelRows,
    required this.tierRows,
    required this.unlocked,
    required this.habits,
    required this.checks,
    required this.goals,
    required this.settings,
  });

  final List<Skill> skills;
  final List<SkillLink> links;
  final List<TimeEntry> entries;
  final List<XpAward> awards;
  final List<LevelReached> levelRows;
  final List<TierReached> tierRows;
  final List<AchievementUnlock> unlocked;
  final List<Habit> habits;
  final List<HabitCheck> checks;
  final List<Goal> goals;
  final AppSettings settings;

  late final Map<String, SkillTotals> totals = computeTotals(entries, awards);

  SkillTotals totalsOf(String skillId) => totals[skillId] ?? SkillTotals.zero;
}

/// The single place every XP-changing mutation goes through (§6.2): it writes
/// link bonus, keeps level/tier events, completes goals, unlocks achievements
/// and returns the celebrations to show.
class LogPipeline {
  LogPipeline(this.db, this.clock, {String Function() idGen = newId})
    : _newId = idGen,
      _skills = SkillsRepo(db),
      _links = LinksRepo(db),
      _entries = EntriesRepo(db),
      _awards = AwardsRepo(db),
      _levels = LevelReachedRepo(db),
      _tiers = TierReachedRepo(db),
      _achievements = AchievementsRepo(db),
      _habits = HabitsRepo(db),
      _goals = GoalsRepo(db),
      _kv = KvRepo(db);

  final MeskDb db;
  final Clock clock;
  final String Function() _newId;

  final SkillsRepo _skills;
  final LinksRepo _links;
  final EntriesRepo _entries;
  final AwardsRepo _awards;
  final LevelReachedRepo _levels;
  final TierReachedRepo _tiers;
  final AchievementsRepo _achievements;
  final HabitsRepo _habits;
  final GoalsRepo _goals;
  final KvRepo _kv;

  /// Saves a new entry with bonus awards for the skills linked right now, at
  /// the current rate. Prior-experience entries earn no bonus.
  Future<PipelineResult> saveEntry(TimeEntry e) =>
      _mutate(primarySkillId: e.skillId, (txn, data) async {
        await _entries.put(e, txn: txn);
        final awards = awardsForEntry(
          e,
          linkedSkillIds(e.skillId, data.links),
          data.settings.bonusRateBp,
          _newId,
        );
        for (final a in awards) {
          await _awards.put(a, txn: txn);
        }
      });

  /// Replaces an entry and rescales its awards with their recorded rates.
  Future<PipelineResult> updateEntry(TimeEntry e) =>
      _mutate(primarySkillId: e.skillId, (txn, data) async {
        if (!data.entries.any((old) => old.id == e.id)) {
          throw StateError('No entry ${e.id} to update');
        }
        await _entries.put(e, txn: txn);
        final existing = [
          for (final a in data.awards)
            if (a.entryId == e.id) a,
        ];
        for (final a in rescaleAwards(existing, e.seconds)) {
          await _awards.put(a, txn: txn);
        }
      });

  /// Removes an entry and the bonus it gave.
  Future<PipelineResult> deleteEntry(String entryId) =>
      _mutate((txn, data) async {
        await _entries.delete(entryId, txn: txn);
        await _awards.deleteForEntry(entryId, txn: txn);
      });

  /// Bonus seconds that [skillId]'s entries gave to linked skills; this is
  /// what deleting the skill takes away from them.
  Future<int> bonusGivenBySkill(String skillId) async {
    final entryIds = {for (final e in await _entries.forSkill(skillId)) e.id};
    var total = 0;
    for (final a in await _awards.all()) {
      if (entryIds.contains(a.entryId)) total += a.seconds;
    }
    return total;
  }

  /// Deletes the skill and everything that references it, as if it never
  /// existed (§5.1), then re-evaluates the other skills' levels.
  Future<void> deleteSkill(String skillId) async {
    await _mutate((txn, data) async {
      final entryIds = {
        for (final e in data.entries)
          if (e.skillId == skillId) e.id,
      };
      for (final id in entryIds) {
        await _entries.delete(id, txn: txn);
      }
      for (final a in data.awards) {
        if (entryIds.contains(a.entryId) || a.skillId == skillId) {
          await _awards.delete(a.id, txn: txn);
        }
      }
      for (final l in data.links) {
        if (l.a == skillId || l.b == skillId) {
          await _links.delete(l.id, txn: txn);
        }
      }
      final habitIds = {
        for (final h in data.habits)
          if (h.skillId == skillId) h.id,
      };
      for (final id in habitIds) {
        await _habits.delete(id, txn: txn);
      }
      for (final c in data.checks) {
        if (habitIds.contains(c.habitId)) {
          await MeskDb.habitChecks
              .record(HabitsRepo.checkKey(c.habitId, c.day))
              .delete(txn);
        }
      }
      for (final g in data.goals) {
        if (g.skillId == skillId) await _goals.delete(g.id, txn: txn);
      }
      for (final r in data.levelRows) {
        if (r.skillId == skillId) {
          await _levels.delete(
            LevelReachedRepo.key(skillId, r.level),
            txn: txn,
          );
        }
      }
      for (final r in data.tierRows) {
        if (r.skillId == skillId) {
          await _tiers.delete(TierReachedRepo.key(skillId, r.tier), txn: txn);
        }
      }
      await _forgetSkillInSettings(txn, data.settings, skillId);
      await _skills.delete(skillId, txn: txn);
    });
  }

  /// Re-evaluates achievements after a habit or check changed.
  Future<PipelineResult> afterHabitChange() => _mutate((txn, data) async {});

  /// Brings every derived event row in line with the stored data (after a
  /// backup import). Rows that already exist keep their dates.
  Future<void> recomputeAll() async {
    await _mutate((txn, data) async {});
  }

  Future<void> _forgetSkillInSettings(
    Transaction txn,
    AppSettings settings,
    String skillId,
  ) async {
    if (settings.lastSkillId == skillId ||
        settings.lastPresetBySkill.containsKey(skillId)) {
      await _kv.saveSettings(
        settings.copyWith(
          lastSkillId: settings.lastSkillId == skillId
              ? null
              : settings.lastSkillId,
          lastPresetBySkill: {...settings.lastPresetBySkill}..remove(skillId),
        ),
        txn: txn,
      );
    }
    final character = await _kv.character(txn: txn);
    if (character != null && character.titleSkillId == skillId) {
      await _kv.saveCharacter(
        character.copyWith(titleSkillId: null, titleLevel: null),
        txn: txn,
      );
    }
  }

  Future<_Snapshot> _load(Transaction txn) async => _Snapshot(
    skills: await _skills.all(txn: txn),
    links: await _links.all(txn: txn),
    entries: await _entries.all(txn: txn),
    awards: await _awards.all(txn: txn),
    levelRows: await _levels.all(txn: txn),
    tierRows: await _tiers.all(txn: txn),
    unlocked: await _achievements.all(txn: txn),
    habits: await _habits.all(txn: txn),
    checks: await _habits.allChecks(txn: txn),
    goals: await _goals.all(txn: txn),
    settings: await _kv.settings(txn: txn),
  );

  /// Runs [apply] in one transaction between a before and an after snapshot,
  /// then settles levels, tiers, goals and achievements. Level cards list
  /// [primarySkillId] first.
  Future<PipelineResult> _mutate(
    Future<void> Function(Transaction txn, _Snapshot before) apply, {
    String? primarySkillId,
  }) => db.database.transaction((txn) async {
    final before = await _load(txn);
    await apply(txn, before);
    final after = await _load(txn);
    final now = clock.nowUtc();

    final levelCards = await _settleLevels(
      txn,
      before,
      after,
      now,
      primarySkillId,
    );
    final goalCards = await _completeGoals(txn, after, now);
    final achievementCards = await _unlockAchievements(txn, after, now);
    return PipelineResult([...levelCards, ...goalCards, ...achievementCards]);
  });

  Future<List<Celebration>> _settleLevels(
    Transaction txn,
    _Snapshot before,
    _Snapshot after,
    DateTime now,
    String? primarySkillId,
  ) async {
    final ids = <String>{
      ?primarySkillId,
      for (final s in after.skills) s.id,
      ...after.totals.keys,
      for (final r in after.levelRows) r.skillId,
      for (final r in after.tierRows) r.skillId,
    };
    final xpBefore = {for (final id in ids) id: before.totalsOf(id).xpSeconds};
    final xpAfter = {for (final id in ids) id: after.totalsOf(id).xpSeconds};
    final bonusOnly = {
      for (final id in ids)
        if (before.totalsOf(id).realSeconds == after.totalsOf(id).realSeconds)
          id,
    };

    final hasEntry = {for (final e in after.entries) e.skillId};
    final levelRows = {
      for (final r in after.levelRows) LevelReachedRepo.key(r.skillId, r.level),
    };
    final tierRows = {
      for (final r in after.tierRows) TierReachedRepo.key(r.skillId, r.tier),
    };
    final wantedLevels = <String>{};
    final wantedTiers = <String>{};
    for (final id in ids) {
      final xp = xpAfter[id]!;
      // Level 1 is reached by the first entry; higher levels by XP alone.
      final from = hasEntry.contains(id) ? 1 : 2;
      for (var level = from; level <= levelForXp(xp); level++) {
        final key = LevelReachedRepo.key(id, level);
        wantedLevels.add(key);
        if (!levelRows.contains(key)) {
          await _levels.put(
            LevelReached(skillId: id, level: level, at: now),
            txn: txn,
          );
        }
      }
      final tier = hiddenTierForXp(xp);
      for (final t in HiddenTier.values) {
        if (tier == null || t.index > tier.index) break;
        final key = TierReachedRepo.key(id, t);
        wantedTiers.add(key);
        if (!tierRows.contains(key)) {
          await _tiers.put(
            TierReached(skillId: id, tier: t, at: now),
            txn: txn,
          );
        }
      }
    }
    for (final key in levelRows.difference(wantedLevels)) {
      await _levels.delete(key, txn: txn);
    }
    for (final key in tierRows.difference(wantedTiers)) {
      await _tiers.delete(key, txn: txn);
    }

    return celebrationsFor(
      diffLevels(xpBefore, xpAfter, bonusOnlySkillIds: bonusOnly),
    );
  }

  Future<List<Celebration>> _completeGoals(
    Transaction txn,
    _Snapshot data,
    DateTime now,
  ) async {
    final today = todayOf(clock, data.settings.dayStartHour);
    final cards = <Celebration>[];
    for (var i = 0; i < data.goals.length; i++) {
      final goal = data.goals[i];
      if (!goal.active) continue;
      final status = goalStatus(
        goal,
        realSeconds: data.totalsOf(goal.skillId).realSeconds,
        paceSecondsPerDay: 0,
        today: today,
      );
      if (!status.completed) continue;
      final done = goal.copyWith(completedAt: now);
      data.goals[i] = done;
      await _goals.put(done, txn: txn);
      cards.add(
        Celebration(
          kind: CelebrationKind.goalCompleted,
          goalId: goal.id,
          skillId: goal.skillId,
        ),
      );
    }
    return cards;
  }

  Future<List<Celebration>> _unlockAchievements(
    Transaction txn,
    _Snapshot data,
    DateTime now,
  ) async {
    final dayStartHour = data.settings.dayStartHour;
    final today = todayOf(clock, dayStartHour);
    final habitData = buildHabitDayData(
      data.entries,
      data.checks,
      dayStartHour,
    );
    // Archived skills count toward stats and total level (§5.1, §5.6).
    final levels = {
      for (final s in data.skills)
        s.id: levelForXp(data.totalsOf(s.id).xpSeconds),
    };
    final stats = sumContributions([
      skillStatValues(data.skills, levels),
      {
        Stat.irade: iradeFromPoints(iradePoints(data.habits, today, habitData))
            .toDouble(),
      },
    ]);
    final met = metAchievementKeys(
      AchievementContext(
        entries: data.entries,
        links: data.links,
        levelBySkillId: levels,
        statDisplayValues: {
          for (final e in stats.entries) e.key: displayStatValue(e.value),
        },
        maxDailyStreak: maxDailyStreak(data.habits, today, habitData),
        hadPerfectWeek: hadPerfectWeek(data.habits, today, habitData),
        goals: data.goals,
        totalLevel: totalLevel(data.skills, levels),
        dayStartHour: dayStartHour,
      ),
    );
    final already = {for (final u in data.unlocked) u.key};
    final cards = <Celebration>[];
    for (final def in generalAchievements) {
      if (!met.contains(def.key) || already.contains(def.key)) continue;
      await _achievements.put(
        AchievementUnlock(key: def.key, at: now),
        txn: txn,
      );
      cards.add(
        Celebration(kind: CelebrationKind.achievement, achievementKey: def.key),
      );
    }
    return cards;
  }
}
