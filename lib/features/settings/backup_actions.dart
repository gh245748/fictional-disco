import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

import '../../app/providers.dart';
import '../../data/backup.dart';
import '../../data/db.dart';
import '../../data/kv_repo.dart';
import '../../data/log_pipeline.dart';
import '../../domain/day.dart';
import '../focus/timer_controller.dart';
import '../habits/habits_controller.dart';

/// Hands a backup file to the system share sheet.
abstract class ShareAdapter {
  /// Writes [content] to a temporary file called [fileName] and shares it.
  /// Throws when the file cannot be written or shared. The result says
  /// whether the user finished or dismissed the share sheet.
  Future<ShareResult> shareJsonFile(String fileName, String content);
}

/// Prefix and suffix of the exported temporary files.
const _exportPrefix = 'mesk-yedek-';
const _exportSuffix = '.json';

/// Deletes exported backup files left in the temporary directory. Never
/// called right after sharing: the receiving app may still be reading the
/// file. Best effort.
Future<void> deleteStaleExports() async {
  try {
    final dir = await getTemporaryDirectory();
    await for (final f in dir.list()) {
      final name = p.basename(f.path);
      if (f is File &&
          name.startsWith(_exportPrefix) &&
          name.endsWith(_exportSuffix)) {
        await f.delete();
      }
    }
  } on Object {
    // Stale files are harmless; the next export or launch retries.
  }
}

class SystemShareAdapter implements ShareAdapter {
  const SystemShareAdapter();

  @override
  Future<ShareResult> shareJsonFile(String fileName, String content) async {
    await deleteStaleExports();
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, fileName));
    await file.writeAsString(content, flush: true);
    return SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        fileNameOverrides: [fileName],
      ),
    );
  }
}

/// Where the copy of the current data goes before a restore replaces it.
///
/// A new copy is staged first and only replaces the old one once the restore
/// went through, so restoring the copy itself (undo) swaps the two instead
/// of destroying it.
abstract class SafetyCopyStore {
  /// The committed safety copy, or null when there is none.
  Future<String?> readSafetyCopy();

  /// Writes [content] beside the committed copy. Throws on failure.
  Future<void> stageSafetyCopy(String content);

  /// Makes the staged content the safety copy.
  Future<void> commitStagedSafetyCopy();
}

/// The one rolling safety copy, in the app documents directory.
const safetyCopyFileName = 'mesk-geri-yukleme-oncesi.json';

class SystemSafetyCopyStore implements SafetyCopyStore {
  const SystemSafetyCopyStore();

  Future<(File target, File staged)> _files() async {
    final dir = await getApplicationDocumentsDirectory();
    final target = File(p.join(dir.path, safetyCopyFileName));
    return (target, File('${target.path}.tmp'));
  }

  @override
  Future<String?> readSafetyCopy() async {
    final (target, _) = await _files();
    return await target.exists() ? target.readAsString() : null;
  }

  @override
  Future<void> stageSafetyCopy(String content) async {
    final (_, staged) = await _files();
    await staged.writeAsString(content, flush: true);
  }

  @override
  Future<void> commitStagedSafetyCopy() async {
    final (target, staged) = await _files();
    await staged.rename(target.path);
  }
}

/// Lets the user choose a backup file.
abstract class BackupFilePicker {
  /// The text of the chosen `.json` file, or null when the user cancelled.
  /// Throws [BackupException] when the file cannot be read.
  Future<String?> pickBackupJson();
}

class SystemBackupFilePicker implements BackupFilePicker {
  const SystemBackupFilePicker();

  @override
  Future<String?> pickBackupJson() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (files.isEmpty) return null;
    final path = files.first.path;
    if (path == null) {
      throw const BackupException('Yedek dosyası okunamadı.');
    }
    try {
      return await File(path).readAsString();
    } on Object {
      throw const BackupException('Yedek dosyası okunamadı.');
    }
  }
}

final shareAdapterProvider = Provider<ShareAdapter>(
  (ref) => const SystemShareAdapter(),
);

final safetyCopyStoreProvider = Provider<SafetyCopyStore>(
  (ref) => const SystemSafetyCopyStore(),
);

/// The text and summary of the safety copy, or null when there is no usable
/// one. Refresh after a restore.
final safetyCopyProvider =
    FutureProvider.autoDispose<({String text, BackupSummary summary})?>((
      ref,
    ) async {
      try {
        final text = await ref.watch(safetyCopyStoreProvider).readSafetyCopy();
        if (text == null) return null;
        return (text: text, summary: inspectBackup(text));
      } on Object {
        return null;
      }
    });

final backupFilePickerProvider = Provider<BackupFilePicker>(
  (ref) => const SystemBackupFilePicker(),
);

/// What a restore did.
class RestoreOutcome {
  const RestoreOutcome({required this.derivedDataUpdated});

  /// False when the data was replaced but recomputing levels, achievements
  /// or reminders failed afterwards.
  final bool derivedDataUpdated;
}

/// Export and restore (§5.14).
class BackupActions {
  BackupActions({
    required this.db,
    required this.clock,
    required this.share,
    required this.safetyCopy,
    required this.pipeline,
    required this.habits,
    required this.reconcileTimer,
  });

  final MeskDb db;
  final Clock clock;
  final ShareAdapter share;
  final SafetyCopyStore safetyCopy;
  final LogPipeline pipeline;
  final HabitsController habits;

  /// Reloads the stored timer after the data was replaced.
  final Future<void> Function() reconcileTimer;

  /// Shares a backup file. `lastBackupAt` is set only when the share call
  /// returned without throwing and the user did not dismiss the share sheet
  /// (a platform that cannot tell counts as shared). Returns whether the
  /// backup counted.
  Future<bool> export() async {
    final now = clock.nowUtc();
    final json = await exportBackup(db, now);
    final day = dayOfInstant(now, clock.offsetMinutesAt(now), 0);
    final result = await share.shareJsonFile(backupFileName(day), json);
    if (result.status == ShareResultStatus.dismissed) return false;
    await _markBackedUp(now);
    return true;
  }

  Future<void> _markBackedUp(DateTime at) async {
    final kv = KvRepo(db);
    await kv.saveSettings((await kv.settings()).copyWith(lastBackupAt: at));
  }

  /// Validates [jsonText] and counts what it holds, changing nothing.
  /// Throws [BackupException] for a rejected file.
  BackupSummary inspect(String jsonText) => inspectBackup(jsonText);

  /// Replaces all data with [jsonText], then brings derived rows, habit
  /// reminders and the timer in line with it. The current data is first
  /// saved as a safety copy. Throws [BackupException] for a rejected file or
  /// when the safety copy cannot be written, leaving the data as it was.
  ///
  /// A restored user-picked file counts as a backup of its own date. With
  /// [undo] the text is the safety copy itself, which never left the device,
  /// so `lastBackupAt` keeps the value the restored data carries.
  Future<RestoreOutcome> restore(String jsonText, {bool undo = false}) async {
    final summary = inspectBackup(jsonText);
    try {
      await safetyCopy.stageSafetyCopy(await exportBackup(db, clock.nowUtc()));
    } on Object {
      throw const BackupException(
        'Mevcut verilerinin kopyası alınamadığı için geri yükleme yapılmadı.',
      );
    }
    await importBackup(db, jsonText);
    try {
      // The data before this restore becomes the safety copy; restoring the
      // old copy itself therefore swaps the two.
      await safetyCopy.commitStagedSafetyCopy();
    } on Object {
      // The previous copy stays; the restore itself went through.
    }
    final at = undo ? null : summary.exportedAt;
    var updated = true;
    try {
      if (at != null) await _markBackedUp(at);
      await pipeline.recomputeAll();
      await habits.rescheduleReminders();
    } on Object {
      updated = false;
    }
    try {
      await reconcileTimer();
    } on Object {
      // The timer stays as loaded; the next resume retries.
    }
    return RestoreOutcome(derivedDataUpdated: updated);
  }
}

final backupActionsProvider = Provider<BackupActions>(
  (ref) => BackupActions(
    db: ref.watch(dbProvider),
    clock: ref.watch(clockProvider),
    share: ref.watch(shareAdapterProvider),
    safetyCopy: ref.watch(safetyCopyStoreProvider),
    pipeline: ref.watch(pipelineProvider),
    habits: ref.watch(habitsControllerProvider),
    reconcileTimer: () =>
        ref.read(timerControllerProvider.notifier).reconcile(),
  ),
);
