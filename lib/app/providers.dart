import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db.dart';
import '../data/entries_repo.dart';
import '../data/events_repo.dart';
import '../data/goals_repo.dart';
import '../data/habits_repo.dart';
import '../data/kv_repo.dart';
import '../data/log_pipeline.dart';
import '../data/presets_repo.dart';
import '../data/skills_repo.dart';
import '../domain/day.dart';
import '../domain/habits.dart';
import '../domain/level_events.dart';
import '../domain/models.dart';
import '../services/notifications.dart';
import 'views.dart';

// ---------------------------------------------------------------------------
// Base providers, overridden in `main` and in tests.

final dbProvider = Provider<MeskDb>(
  (ref) => throw UnimplementedError('dbProvider must be overridden'),
);

final clockProvider = Provider<Clock>((ref) => SystemClock());

final notificationsProvider = Provider<NotificationService>(
  (ref) => throw UnimplementedError('notificationsProvider must be overridden'),
);

final pipelineProvider = Provider<LogPipeline>(
  (ref) => LogPipeline(ref.watch(dbProvider), ref.watch(clockProvider)),
);

// ---------------------------------------------------------------------------
// One stream per store.

final skillsProvider = StreamProvider<List<Skill>>(
  (ref) => SkillsRepo(ref.watch(dbProvider)).watchAll(),
);

final linksProvider = StreamProvider<List<SkillLink>>(
  (ref) => LinksRepo(ref.watch(dbProvider)).watchAll(),
);

final entriesProvider = StreamProvider<List<TimeEntry>>(
  (ref) => EntriesRepo(ref.watch(dbProvider)).watchAll(),
);

final awardsProvider = StreamProvider<List<XpAward>>(
  (ref) => AwardsRepo(ref.watch(dbProvider)).watchAll(),
);

final levelReachedProvider = StreamProvider<List<LevelReached>>(
  (ref) => LevelReachedRepo(ref.watch(dbProvider)).watchAll(),
);

final tierReachedProvider = StreamProvider<List<TierReached>>(
  (ref) => TierReachedRepo(ref.watch(dbProvider)).watchAll(),
);

final achievementsProvider = StreamProvider<List<AchievementUnlock>>(
  (ref) => AchievementsRepo(ref.watch(dbProvider)).watchAll(),
);

final habitsProvider = StreamProvider<List<Habit>>(
  (ref) => HabitsRepo(ref.watch(dbProvider)).watchAll(),
);

final habitChecksProvider = StreamProvider<List<HabitCheck>>(
  (ref) => HabitsRepo(ref.watch(dbProvider)).watchChecks(),
);

final goalsProvider = StreamProvider<List<Goal>>(
  (ref) => GoalsRepo(ref.watch(dbProvider)).watchAll(),
);

final presetsProvider = StreamProvider<List<TimerPreset>>(
  (ref) => PresetsRepo(ref.watch(dbProvider)).watchAll(),
);

final settingsProvider = StreamProvider<AppSettings>(
  (ref) => KvRepo(ref.watch(dbProvider)).watchSettings(),
);

final characterProvider = StreamProvider<Character?>(
  (ref) => KvRepo(ref.watch(dbProvider)).watchCharacter(),
);

// ---------------------------------------------------------------------------
// Derived values.

/// The user's current day (honouring `dayStartHour`), re-read every minute.
final todayProvider = StreamProvider<LocalDay>((ref) async* {
  final clock = ref.watch(clockProvider);
  final dayStartHour = await ref.watch(
    settingsProvider.selectAsync((s) => s.dayStartHour),
  );
  LocalDay read() => todayOf(clock, dayStartHour);
  yield read();
  yield* Stream.periodic(const Duration(minutes: 1), (_) => read()).distinct();
});

final habitDayDataProvider = FutureProvider<HabitDayData>((ref) async {
  final entries = await ref.watch(entriesProvider.future);
  final checks = await ref.watch(habitChecksProvider.future);
  final dayStartHour = await ref.watch(
    settingsProvider.selectAsync((s) => s.dayStartHour),
  );
  return buildHabitDayData(entries, checks, dayStartHour);
});

/// Views of every skill, archived ones included, in store order.
final skillViewsProvider = FutureProvider<List<SkillView>>((ref) async {
  final skills = await ref.watch(skillsProvider.future);
  final entries = await ref.watch(entriesProvider.future);
  final awards = await ref.watch(awardsProvider.future);
  final goals = await ref.watch(goalsProvider.future);
  final dayData = await ref.watch(habitDayDataProvider.future);
  final today = await ref.watch(todayProvider.future);
  return buildSkillViews(
    skills: skills,
    entries: entries,
    awards: awards,
    goals: goals,
    dayData: dayData,
    today: today,
  );
});

/// The view of one skill, or null when it does not exist.
final skillViewProvider = FutureProvider.family<SkillView?, String>((
  ref,
  id,
) async {
  final views = await ref.watch(skillViewsProvider.future);
  for (final v in views) {
    if (v.skill.id == id) return v;
  }
  return null;
});

final characterViewProvider = FutureProvider<CharacterView>((ref) async {
  final views = await ref.watch(skillViewsProvider.future);
  final character = await ref.watch(characterProvider.future);
  final habits = await ref.watch(habitsProvider.future);
  final dayData = await ref.watch(habitDayDataProvider.future);
  final today = await ref.watch(todayProvider.future);
  return buildCharacterView(
    skills: views,
    character: character,
    // Archived habits keep the points they earned (nothing decays).
    iradePoints: iradePoints(habits, today, dayData),
  );
});

/// Today's due habits (not archived), in creation order.
final todayHabitsProvider = FutureProvider<List<TodayHabit>>((ref) async {
  final habits = await ref.watch(habitsProvider.future);
  final dayData = await ref.watch(habitDayDataProvider.future);
  final today = await ref.watch(todayProvider.future);
  final active =
      [
        for (final h in habits)
          if (h.archivedAt == null) h,
      ]..sort((a, b) {
        final c = a.createdAt.compareTo(b.createdAt);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
  return todayHabits(active, today, dayData);
});

/// Tracked seconds and pomodoros of today; prior experience excluded.
final todayFocusProvider = FutureProvider<(int seconds, int pomodoros)>((
  ref,
) async {
  final entries = await ref.watch(entriesProvider.future);
  final today = await ref.watch(todayProvider.future);
  final dayStartHour = await ref.watch(
    settingsProvider.selectAsync((s) => s.dayStartHour),
  );
  var seconds = 0;
  var pomodoros = 0;
  for (final e in entries) {
    if (e.isPrior) continue;
    if (dayOfInstant(e.startedAt, e.offsetMinutes, dayStartHour) != today) {
      continue;
    }
    seconds += e.seconds;
    pomodoros += e.pomodoros;
  }
  return (seconds, pomodoros);
});

// ---------------------------------------------------------------------------
// Celebrations waiting to be shown.

class CelebrationQueue extends Notifier<List<Celebration>> {
  @override
  List<Celebration> build() => const [];

  void push(List<Celebration> cards) {
    if (cards.isEmpty) return;
    state = [...state, ...cards];
  }

  /// Removes and returns the first card, or null when the queue is empty.
  Celebration? pop() {
    if (state.isEmpty) return null;
    final first = state.first;
    state = state.sublist(1);
    return first;
  }
}

final celebrationQueueProvider =
    NotifierProvider<CelebrationQueue, List<Celebration>>(CelebrationQueue.new);
