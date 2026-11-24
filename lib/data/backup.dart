import 'dart:convert';

import 'package:sembast/sembast.dart';

import '../domain/day.dart';
import '../domain/models.dart';
import '../domain/timer_machine.dart';
import 'db.dart';

const String backupFormat = 'mesk-backup';
const int backupVersion = 1;

/// A backup file was rejected; [message] is user-facing Turkish text.
class BackupException implements Exception {
  const BackupException(this.message);

  final String message;

  @override
  String toString() => 'BackupException: $message';
}

const _unreadable = 'Yedek dosyası okunamadı.';

/// Store name -> (sembast store, model validator). The validator throws when a
/// record value is not a valid model.
final Map<String, StoreRef<String, Object?>> _stores = {
  'skills': MeskDb.skills.cast<String, Object?>(),
  'links': MeskDb.links.cast<String, Object?>(),
  'entries': MeskDb.entries.cast<String, Object?>(),
  'awards': MeskDb.awards.cast<String, Object?>(),
  'levelReached': MeskDb.levelReached.cast<String, Object?>(),
  'tierReached': MeskDb.tierReached.cast<String, Object?>(),
  'achievements': MeskDb.achievements.cast<String, Object?>(),
  'habits': MeskDb.habits.cast<String, Object?>(),
  'habitChecks': MeskDb.habitChecks.cast<String, Object?>(),
  'goals': MeskDb.goals.cast<String, Object?>(),
  'presets': MeskDb.presets.cast<String, Object?>(),
  'kv': MeskDb.kv,
};

typedef _Validator = void Function(Map<String, Object?> json);

final Map<String, _Validator> _validators = {
  'skills': Skill.fromJson,
  'links': SkillLink.fromJson,
  'entries': TimeEntry.fromJson,
  'awards': XpAward.fromJson,
  'levelReached': LevelReached.fromJson,
  'tierReached': TierReached.fromJson,
  'achievements': AchievementUnlock.fromJson,
  'habits': Habit.fromJson,
  'habitChecks': HabitCheck.fromJson,
  'goals': Goal.fromJson,
  'presets': TimerPreset.fromJson,
};

final Map<String, _Validator> _kvValidators = {
  'settings': AppSettings.fromJson,
  'character': Character.fromJson,
  'timer': TimerState.fromJson,
};

/// Serialises every store to the JSON backup format.
///
/// All stores are read in one transaction, so a write that lands meanwhile
/// cannot split an entry from its awards.
Future<String> exportBackup(MeskDb db, DateTime nowUtc) async {
  final data = await db.database.transaction((txn) async {
    final out = <String, Object?>{};
    for (final e in _stores.entries) {
      final records = await e.value.find(txn);
      out[e.key] = [
        for (final r in records) {'key': r.key, 'value': r.value},
      ];
    }
    return out;
  });
  return jsonEncode({
    'format': backupFormat,
    'version': backupVersion,
    'exportedAt': nowUtc.toUtc().toIso8601String(),
    'data': data,
  });
}

/// What a backup file holds, for the confirmation before restoring it.
class BackupSummary {
  const BackupSummary({
    required this.exportedAt,
    required this.skills,
    required this.entries,
    required this.habits,
  });

  /// When the file was made; null when the file does not say.
  final DateTime? exportedAt;
  final int skills;
  final int entries;
  final int habits;
}

/// Validates [jsonText] like [importBackup] does, without writing anything,
/// and counts what it holds. Throws [BackupException] for a rejected file.
BackupSummary inspectBackup(String jsonText) {
  final parsed = _parse(jsonText);
  return BackupSummary(
    exportedAt: _exportedAt(jsonText),
    skills: parsed['skills']?.length ?? 0,
    entries: parsed['entries']?.length ?? 0,
    habits: parsed['habits']?.length ?? 0,
  );
}

DateTime? _exportedAt(String jsonText) {
  try {
    final raw = (jsonDecode(jsonText) as Map<String, Object?>)['exportedAt'];
    return raw is String ? DateTime.tryParse(raw)?.toUtc() : null;
  } on Object {
    return null;
  }
}

/// Replaces the whole database with the backup in [jsonText]. Everything is
/// validated first; the write itself is one transaction, so a rejected file
/// leaves the database untouched. The caller runs `recomputeAll()` afterwards.
///
/// A running session never moves across a restore: the stored timer is
/// reset to idle, whatever the file says.
Future<void> importBackup(MeskDb db, String jsonText) async {
  final parsed = _parse(jsonText);

  await db.database.transaction((txn) async {
    for (final e in _stores.entries) {
      await e.value.delete(txn);
      for (final r in parsed[e.key] ?? const <MapEntry<String, Object?>>[]) {
        await e.value.record(r.key).put(txn, r.value);
      }
    }
  });
}

Map<String, List<MapEntry<String, Object?>>> _parse(String jsonText) {
  final Object? root;
  try {
    root = jsonDecode(jsonText);
  } on FormatException {
    throw const BackupException(_unreadable);
  }
  if (root is! Map<String, Object?>) {
    throw const BackupException(_unreadable);
  }
  if (root['format'] != backupFormat) {
    throw const BackupException('Bu dosya bir Meşk yedeği değil.');
  }
  final version = root['version'];
  if (version is! int) throw const BackupException(_unreadable);
  if (version > backupVersion) {
    throw const BackupException(
      'Bu yedek daha yeni bir Meşk sürümüyle alınmış. '
      'Önce uygulamayı güncelle.',
    );
  }

  try {
    final data = root['data']! as Map<String, Object?>;
    final out = <String, List<MapEntry<String, Object?>>>{};
    for (final name in _stores.keys) {
      final raw = data[name];
      if (raw == null) continue;
      final records = <MapEntry<String, Object?>>[];
      for (final item in raw as List<Object?>) {
        final rec = item! as Map<String, Object?>;
        final key = rec['key']! as String;
        final value = rec['value'];
        final validate = name == 'kv' ? _kvValidators[key] : _validators[name];
        if (validate != null) {
          validate(Map<String, Object?>.from(value! as Map));
        } else if (name == 'kv') {
          // Unknown kv key: not ours to restore.
          continue;
        }
        records.add(
          MapEntry(
            key,
            name == 'kv' && key == 'timer' ? TimerState.idle.toJson() : value,
          ),
        );
      }
      out[name] = records;
    }
    return out;
  } on Object {
    throw const BackupException(_unreadable);
  }
}

/// `mesk-yedek-YYYY-MM-DD.json`.
String backupFileName(LocalDay day) => 'mesk-yedek-${day.toIso()}.json';
