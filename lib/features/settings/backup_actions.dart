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
  /// Throws when the file cannot be written or shared.
  Future<void> shareJsonFile(String fileName, String content);
}

class SystemShareAdapter implements ShareAdapter {
  const SystemShareAdapter();

  @override
  Future<void> shareJsonFile(String fileName, String content) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, fileName));
    await file.writeAsString(content, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        fileNameOverrides: [fileName],
      ),
    );
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

final backupFilePickerProvider = Provider<BackupFilePicker>(
  (ref) => const SystemBackupFilePicker(),
);

/// Export and restore (§5.14).
class BackupActions {
  BackupActions({
    required this.db,
    required this.clock,
    required this.share,
    required this.pipeline,
    required this.habits,
    required this.reconcileTimer,
  });

  final MeskDb db;
  final Clock clock;
  final ShareAdapter share;
  final LogPipeline pipeline;
  final HabitsController habits;

  /// Reloads the stored timer after the data was replaced.
  final Future<void> Function() reconcileTimer;

  /// Shares a backup file. `lastBackupAt` is set only once the share call
  /// returned without throwing.
  Future<void> export() async {
    final now = clock.nowUtc();
    final json = await exportBackup(db, now);
    final day = dayOfInstant(now, clock.offsetMinutesAt(now), 0);
    await share.shareJsonFile(backupFileName(day), json);
    final kv = KvRepo(db);
    await kv.saveSettings((await kv.settings()).copyWith(lastBackupAt: now));
  }

  /// Replaces all data with [jsonText], then brings derived rows, habit
  /// reminders and the timer in line with it. Throws [BackupException] for a
  /// rejected file, leaving the data as it was.
  Future<void> restore(String jsonText) async {
    await importBackup(db, jsonText);
    await pipeline.recomputeAll();
    await habits.rescheduleReminders();
    try {
      await reconcileTimer();
    } on Object {
      // The timer stays as loaded; the next resume retries.
    }
  }
}

final backupActionsProvider = Provider<BackupActions>(
  (ref) => BackupActions(
    db: ref.watch(dbProvider),
    clock: ref.watch(clockProvider),
    share: ref.watch(shareAdapterProvider),
    pipeline: ref.watch(pipelineProvider),
    habits: ref.watch(habitsControllerProvider),
    reconcileTimer: () =>
        ref.read(timerControllerProvider.notifier).reconcile(),
  ),
);
