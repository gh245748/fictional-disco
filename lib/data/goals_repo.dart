import '../domain/models.dart';
import 'db.dart';

class GoalsRepo extends JsonRepo<Goal> {
  GoalsRepo(MeskDb db) : super(db, MeskDb.goals);

  @override
  Goal fromJson(Map<String, Object?> json) => Goal.fromJson(json);
  @override
  Map<String, Object?> toJson(Goal value) => value.toJson();
  @override
  String keyOf(Goal value) => value.id;
}
