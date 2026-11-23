import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../data/kv_repo.dart';
import '../../domain/models.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/buttons.dart';
import '../../ui/widgets/mesk_card.dart';

const int backupReminderAfterDays = 14;
const int backupReminderSnoozeDays = 7;

/// Whole days since the last backup when the reminder is due, -1 when no
/// backup was ever made, and null when no reminder should show (the backup is
/// recent, or the reminder was dismissed less than 7 days ago).
int? backupReminderDays(AppSettings settings, DateTime nowUtc) {
  final dismissed = settings.backupReminderDismissedAt;
  if (dismissed != null &&
      nowUtc.difference(dismissed).inDays < backupReminderSnoozeDays) {
    return null;
  }
  final last = settings.lastBackupAt;
  if (last == null) return -1;
  final days = nowUtc.difference(last).inDays;
  return days > backupReminderAfterDays ? days : null;
}

/// The small dismissible reminder on Today (§5.14).
class BackupReminder extends ConsumerWidget {
  const BackupReminder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value;
    if (settings == null) return const SizedBox.shrink();
    final days = backupReminderDays(
      settings,
      ref.watch(clockProvider).nowUtc(),
    );
    if (days == null) return const SizedBox.shrink();
    return MeskCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            days < 0
                ? 'Henüz yedek almadın.'
                : 'Son yedeğin üzerinden $days gün geçti.',
            style: MeskType.body14,
          ),
          Row(
            children: [
              MeskTextButton(
                'Yedek al',
                onPressed: () => context.push('/ayarlar'),
              ),
              MeskTextButton(
                'Kapat',
                color: MeskColors.muted,
                onPressed: () => _dismiss(ref, settings),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _dismiss(WidgetRef ref, AppSettings settings) =>
      KvRepo(ref.read(dbProvider)).saveSettings(
        settings.copyWith(
          backupReminderDismissedAt: ref.read(clockProvider).nowUtc(),
        ),
      );
}
