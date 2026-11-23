import 'package:sembast/sembast_io.dart';
import 'package:sembast/sembast_memory.dart';

/// Owner of the sembast [Database] and of every store reference.
class MeskDb {
  MeskDb._(this.database);

  /// Bump together with a new branch in [_migrate].
  static const int schemaVersion = 1;

  final Database database;

  static final skills = stringMapStoreFactory.store('skills');
  static final links = stringMapStoreFactory.store('links');
  static final entries = stringMapStoreFactory.store('entries');
  static final awards = stringMapStoreFactory.store('awards');
  static final levelReached = stringMapStoreFactory.store('levelReached');
  static final tierReached = stringMapStoreFactory.store('tierReached');
  static final achievements = stringMapStoreFactory.store('achievements');
  static final habits = stringMapStoreFactory.store('habits');
  static final habitChecks = stringMapStoreFactory.store('habitChecks');
  static final goals = stringMapStoreFactory.store('goals');
  static final presets = stringMapStoreFactory.store('presets');

  /// Keys: `settings`, `character`, `timer`; values are JSON maps.
  static final kv = StoreRef<String, Object?>('kv');

  static Future<MeskDb> openFile(String path) async => MeskDb._(
    await databaseFactoryIo.openDatabase(
      path,
      version: schemaVersion,
      onVersionChanged: _migrate,
    ),
  );

  /// Opens a fresh in-memory database (a new factory per call, so two calls
  /// never share data even with the same [name]).
  static Future<MeskDb> openMemory([String name = 'test']) async => MeskDb._(
    await newDatabaseFactoryMemory().openDatabase(
      name,
      version: schemaVersion,
      onVersionChanged: _migrate,
    ),
  );

  static Future<void> _migrate(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // v1 is the initial schema; nothing to migrate yet.
  }

  Future<void> close() => database.close();
}

/// Shared implementation of a string-keyed store of JSON-serialisable models.
abstract class JsonRepo<T> {
  JsonRepo(this.db, this.store);

  final MeskDb db;
  final StoreRef<String, Map<String, Object?>> store;

  T fromJson(Map<String, Object?> json);
  Map<String, Object?> toJson(T value);
  String keyOf(T value);

  Database get _db => db.database;

  T _decode(Map<String, Object?> v) => fromJson(Map<String, Object?>.from(v));

  Future<List<T>> all({DatabaseClient? txn}) async {
    final recs = await store.find(txn ?? _db);
    return [for (final r in recs) _decode(r.value)];
  }

  Future<T?> get(String id, {DatabaseClient? txn}) async {
    final v = await store.record(id).get(txn ?? _db);
    return v == null ? null : _decode(v);
  }

  Stream<List<T>> watchAll() => store
      .query()
      .onSnapshots(_db)
      .map((snaps) => [for (final s in snaps) _decode(s.value)]);

  Future<void> put(T value, {DatabaseClient? txn}) async {
    await store.record(keyOf(value)).put(txn ?? _db, toJson(value));
  }

  Future<void> delete(String id, {DatabaseClient? txn}) async {
    await store.record(id).delete(txn ?? _db);
  }
}
