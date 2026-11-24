import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/db.dart';
import '../../data/habits_repo.dart';
import '../../data/log_pipeline.dart';
import '../../data/skills_repo.dart';
import '../../domain/day.dart';
import '../../domain/graph_layout.dart';
import '../../domain/models.dart';
import '../../domain/stats.dart';
import '../focus/timer_controller.dart';
import '../habits/habits_controller.dart';

/// Creates, edits, archives and deletes skills. XP-changing deletion goes
/// through the [LogPipeline].
class SkillsController {
  SkillsController(
    this.db,
    this.clock,
    this.pipeline, {
    Random? rng,
    this.afterChange,
  }) : _rng = rng ?? Random(),
       _skills = SkillsRepo(db),
       _links = LinksRepo(db),
       _habits = HabitsRepo(db);

  final MeskDb db;
  final Clock clock;
  final LogPipeline pipeline;
  final Random _rng;

  /// Called after a skill was archived or deleted, which changes habits and
  /// may end the running session: the app re-plans reminders and reloads the
  /// timer. Never throws.
  final Future<void> Function()? afterChange;
  final SkillsRepo _skills;
  final LinksRepo _links;
  final HabitsRepo _habits;

  /// Saves a new skill and its links, returning the new id. The skill is
  /// placed near its linked skills that already have a graph position; with
  /// none, the position stays empty for the graph to fill in.
  Future<String> create({
    required String name,
    required Stat primary,
    Stat? secondary,
    String? description,
    Set<String> links = const {},
  }) async {
    final id = newId();
    final now = clock.nowUtc();
    await db.database.transaction((txn) async {
      final neighbors = <(double, double)>[];
      for (final other in links) {
        final s = await _skills.get(other, txn: txn);
        if (s?.graphX != null && s?.graphY != null) {
          neighbors.add((s!.graphX!, s.graphY!));
        }
      }
      final (double?, double?) pos = neighbors.isEmpty
          ? (null, null)
          : GraphLayout.placeNear(neighbors, _rng);
      await _skills.put(
        Skill(
          id: id,
          name: name,
          primary: primary,
          secondary: secondary,
          description: description,
          createdAt: now,
          graphX: pos.$1,
          graphY: pos.$2,
        ),
        txn: txn,
      );
      await _links.setLinksFor(id, links, now, newId, txn: txn);
    });
    return id;
  }

  /// Saves [s]; with [links] given, replaces the skill's links.
  Future<void> update(Skill s, {Set<String>? links}) => db.database.transaction(
    (txn) async {
      await _skills.put(s, txn: txn);
      if (links != null) {
        await _links.setLinksFor(s.id, links, clock.nowUtc(), newId, txn: txn);
      }
    },
  );

  /// Active timed habits tied to the skill; archiving the skill archives them.
  Future<List<Habit>> activeTimedHabits(String skillId) async => [
    for (final h in await _habits.all())
      if (h.skillId == skillId &&
          h.kind == HabitKind.timed &&
          h.archivedAt == null)
        h,
  ];

  /// Archives the skill and its active timed habits (§5.9).
  Future<void> archive(String id) async {
    final now = clock.nowUtc();
    await db.database.transaction((txn) async {
      final skill = await _skills.get(id, txn: txn);
      if (skill == null) return;
      await _skills.put(skill.copyWith(archivedAt: now), txn: txn);
      for (final h in await _habits.all(txn: txn)) {
        if (h.skillId == id &&
            h.kind == HabitKind.timed &&
            h.archivedAt == null) {
          await _habits.put(h.copyWith(archivedAt: now), txn: txn);
        }
      }
    });
    await pipeline.afterHabitChange();
    await _changed();
  }

  /// Brings the skill back. Its archived habits stay archived.
  Future<void> unarchive(String id) async {
    final skill = await _skills.get(id);
    if (skill == null) return;
    await _skills.put(skill.copyWith(archivedAt: null));
  }

  Future<void> delete(String id) async {
    await pipeline.deleteSkill(id);
    await _changed();
  }

  Future<void> _changed() async {
    try {
      await afterChange?.call();
    } on Object {
      // Best effort: the next resume re-plans and reloads anyway.
    }
  }
}

final skillsControllerProvider = Provider<SkillsController>(
  (ref) => SkillsController(
    ref.watch(dbProvider),
    ref.watch(clockProvider),
    ref.watch(pipelineProvider),
    afterChange: () async {
      // A deleted skill takes its timed habits and a running session with it.
      await ref.read(habitsControllerProvider).rescheduleReminders();
      await ref.read(timerControllerProvider.notifier).reconcile();
    },
  ),
);
