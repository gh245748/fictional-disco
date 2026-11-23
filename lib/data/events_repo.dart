import '../domain/models.dart';
import 'db.dart';

/// Key: `<skillId>#<level>`.
class LevelReachedRepo extends JsonRepo<LevelReached> {
  LevelReachedRepo(MeskDb db) : super(db, MeskDb.levelReached);

  static String key(String skillId, int level) => '$skillId#$level';

  @override
  LevelReached fromJson(Map<String, Object?> json) =>
      LevelReached.fromJson(json);
  @override
  Map<String, Object?> toJson(LevelReached value) => value.toJson();
  @override
  String keyOf(LevelReached value) => key(value.skillId, value.level);
}

/// Key: `<skillId>#<tier name>`.
class TierReachedRepo extends JsonRepo<TierReached> {
  TierReachedRepo(MeskDb db) : super(db, MeskDb.tierReached);

  static String key(String skillId, Enum tier) => '$skillId#${tier.name}';

  @override
  TierReached fromJson(Map<String, Object?> json) => TierReached.fromJson(json);
  @override
  Map<String, Object?> toJson(TierReached value) => value.toJson();
  @override
  String keyOf(TierReached value) => key(value.skillId, value.tier);
}

/// Key: the achievement key.
class AchievementsRepo extends JsonRepo<AchievementUnlock> {
  AchievementsRepo(MeskDb db) : super(db, MeskDb.achievements);

  @override
  AchievementUnlock fromJson(Map<String, Object?> json) =>
      AchievementUnlock.fromJson(json);
  @override
  Map<String, Object?> toJson(AchievementUnlock value) => value.toJson();
  @override
  String keyOf(AchievementUnlock value) => value.key;
}
