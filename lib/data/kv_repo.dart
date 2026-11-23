import 'package:sembast/sembast.dart';

import '../domain/models.dart';
import '../domain/timer_machine.dart';
import 'db.dart';

/// Singleton values: app settings, the character and the running timer.
class KvRepo {
  KvRepo(this.db);

  final MeskDb db;

  static const settingsKey = 'settings';
  static const characterKey = 'character';
  static const timerKey = 'timer';

  RecordRef<String, Object?> _ref(String key) => MeskDb.kv.record(key);

  Map<String, Object?>? _map(Object? v) =>
      v == null ? null : Map<String, Object?>.from(v as Map);

  AppSettings _settings(Object? v) {
    final m = _map(v);
    return m == null ? AppSettings.defaults : AppSettings.fromJson(m);
  }

  Character? _character(Object? v) {
    final m = _map(v);
    return m == null ? null : Character.fromJson(m);
  }

  Future<AppSettings> settings({DatabaseClient? txn}) async =>
      _settings(await _ref(settingsKey).get(txn ?? db.database));

  Stream<AppSettings> watchSettings() =>
      _ref(settingsKey).onSnapshot(db.database).map((s) => _settings(s?.value));

  Future<void> saveSettings(AppSettings s, {DatabaseClient? txn}) async {
    await _ref(settingsKey).put(txn ?? db.database, s.toJson());
  }

  Future<Character?> character({DatabaseClient? txn}) async =>
      _character(await _ref(characterKey).get(txn ?? db.database));

  Stream<Character?> watchCharacter() =>
      _ref(characterKey)
          .onSnapshot(db.database)
          .map((s) => _character(s?.value));

  Future<void> saveCharacter(Character c, {DatabaseClient? txn}) async {
    await _ref(characterKey).put(txn ?? db.database, c.toJson());
  }

  Future<TimerState> timer({DatabaseClient? txn}) async {
    final m = _map(await _ref(timerKey).get(txn ?? db.database));
    return m == null ? TimerState.idle : TimerState.fromJson(m);
  }

  Future<void> saveTimer(TimerState s, {DatabaseClient? txn}) async {
    await _ref(timerKey).put(txn ?? db.database, s.toJson());
  }
}
