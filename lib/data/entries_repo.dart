import 'package:sembast/sembast.dart';

import '../domain/models.dart';
import 'db.dart';

class EntriesRepo extends JsonRepo<TimeEntry> {
  EntriesRepo(MeskDb db) : super(db, MeskDb.entries);

  @override
  TimeEntry fromJson(Map<String, Object?> json) => TimeEntry.fromJson(json);
  @override
  Map<String, Object?> toJson(TimeEntry value) => value.toJson();
  @override
  String keyOf(TimeEntry value) => value.id;

  Future<List<TimeEntry>> forSkill(
    String skillId, {
    DatabaseClient? txn,
  }) async {
    final recs = await store.find(
      txn ?? db.database,
      finder: Finder(filter: Filter.equals('skillId', skillId)),
    );
    return [for (final r in recs) fromJson(Map<String, Object?>.from(r.value))];
  }
}

class AwardsRepo extends JsonRepo<XpAward> {
  AwardsRepo(MeskDb db) : super(db, MeskDb.awards);

  @override
  XpAward fromJson(Map<String, Object?> json) => XpAward.fromJson(json);
  @override
  Map<String, Object?> toJson(XpAward value) => value.toJson();
  @override
  String keyOf(XpAward value) => value.id;

  Future<List<XpAward>> forEntry(String entryId, {DatabaseClient? txn}) async {
    final recs = await store.find(
      txn ?? db.database,
      finder: Finder(filter: Filter.equals('entryId', entryId)),
    );
    return [for (final r in recs) fromJson(Map<String, Object?>.from(r.value))];
  }

  Future<void> deleteForEntry(String entryId, {DatabaseClient? txn}) async {
    await store.delete(
      txn ?? db.database,
      finder: Finder(filter: Filter.equals('entryId', entryId)),
    );
  }
}
