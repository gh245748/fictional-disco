import 'package:sembast/sembast.dart';

import '../domain/models.dart';
import 'db.dart';

class SkillsRepo extends JsonRepo<Skill> {
  SkillsRepo(MeskDb db) : super(db, MeskDb.skills);

  @override
  Skill fromJson(Map<String, Object?> json) => Skill.fromJson(json);
  @override
  Map<String, Object?> toJson(Skill value) => value.toJson();
  @override
  String keyOf(Skill value) => value.id;
}

class LinksRepo extends JsonRepo<SkillLink> {
  LinksRepo(MeskDb db) : super(db, MeskDb.links);

  @override
  SkillLink fromJson(Map<String, Object?> json) => SkillLink.fromJson(json);
  @override
  Map<String, Object?> toJson(SkillLink value) => value.toJson();
  @override
  String keyOf(SkillLink value) => value.id;

  /// Replaces every link touching [skillId] with links to [others]
  /// (self-links ignored, pairs stored normalized, no duplicates).
  Future<void> setLinksFor(
    String skillId,
    Set<String> others,
    DateTime now,
    String Function() newId, {
    DatabaseClient? txn,
  }) async {
    Future<void> run(DatabaseClient c) async {
      final existing = await all(txn: c);
      for (final l in existing) {
        if (l.a == skillId || l.b == skillId) await delete(l.id, txn: c);
      }
      for (final other in others) {
        if (other == skillId) continue;
        await put(
          SkillLink.normalized(
            id: newId(),
            x: skillId,
            y: other,
            createdAt: now,
          ),
          txn: c,
        );
      }
    }

    if (txn != null) {
      await run(txn);
    } else {
      await db.database.transaction(run);
    }
  }
}
