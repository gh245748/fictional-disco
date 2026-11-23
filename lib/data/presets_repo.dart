import 'package:sembast/sembast.dart';

import '../domain/models.dart';
import 'db.dart';

class PresetsRepo extends JsonRepo<TimerPreset> {
  PresetsRepo(MeskDb db) : super(db, MeskDb.presets);

  @override
  TimerPreset fromJson(Map<String, Object?> json) => TimerPreset.fromJson(json);
  @override
  Map<String, Object?> toJson(TimerPreset value) => value.toJson();
  @override
  String keyOf(TimerPreset value) => value.id;

  /// Inserts the built-in presets that are missing; never overwrites.
  Future<void> seedBuiltIns({DatabaseClient? txn}) async {
    Future<void> run(DatabaseClient c) async {
      for (final p in TimerPreset.builtIns) {
        if (await get(p.id, txn: c) == null) await put(p, txn: c);
      }
    }

    if (txn != null) {
      await run(txn);
    } else {
      await db.database.transaction(run);
    }
  }
}
