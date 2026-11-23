import 'package:sembast/sembast.dart';

import '../domain/day.dart';
import '../domain/models.dart';
import 'db.dart';

class HabitsRepo extends JsonRepo<Habit> {
  HabitsRepo(MeskDb db) : super(db, MeskDb.habits);

  @override
  Habit fromJson(Map<String, Object?> json) => Habit.fromJson(json);
  @override
  Map<String, Object?> toJson(Habit value) => value.toJson();
  @override
  String keyOf(Habit value) => value.id;

  static String checkKey(String habitId, LocalDay day) =>
      '$habitId#${day.toIso()}';

  HabitCheck _check(Map<String, Object?> v) =>
      HabitCheck.fromJson(Map<String, Object?>.from(v));

  Future<List<HabitCheck>> allChecks({DatabaseClient? txn}) async {
    final recs = await MeskDb.habitChecks.find(txn ?? db.database);
    return [for (final r in recs) _check(r.value)];
  }

  Stream<List<HabitCheck>> watchChecks() => MeskDb.habitChecks
      .query()
      .onSnapshots(db.database)
      .map((snaps) => [for (final s in snaps) _check(s.value)]);

  /// Flips the check for [habitId] on [day]; returns the new checked state.
  Future<bool> toggleCheck(
    String habitId,
    LocalDay day, {
    DatabaseClient? txn,
  }) async {
    Future<bool> run(DatabaseClient c) async {
      final rec = MeskDb.habitChecks.record(checkKey(habitId, day));
      if (await rec.exists(c)) {
        await rec.delete(c);
        return false;
      }
      await rec.put(c, HabitCheck(habitId: habitId, day: day).toJson());
      return true;
    }

    return txn != null ? run(txn) : db.database.transaction(run);
  }
}
