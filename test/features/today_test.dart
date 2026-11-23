import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mesk/app/providers.dart';
import 'package:mesk/app/router.dart';
import 'package:mesk/data/db.dart';
import 'package:mesk/data/habits_repo.dart';
import 'package:mesk/data/kv_repo.dart';
import 'package:mesk/domain/models.dart';
import 'package:mesk/features/focus/focus_screen.dart';
import 'package:mesk/features/today/backup_reminder.dart';
import 'package:mesk/features/today/today_screen.dart';

import '../support/app_harness.dart';
import '../support/demo_data.dart';
import '../support/golden.dart';

/// The demo data with the last backup [days] days before the demo's "now".
Future<void> Function(MeskDb) _backupAgo(int? days) => (db) async {
  await seedDemo(db);
  final kv = KvRepo(db);
  final s = await kv.settings();
  await kv.saveSettings(
    s.copyWith(
      lastBackupAt: days == null
          ? null
          : demoClock().nowUtc().subtract(Duration(days: days)),
    ),
  );
};

Future<void> _home(WidgetTester t) async {
  t.container().read(routerProvider).go('/bugun');
  await t.pumpAndSettle();
  // The tab keeps its scroll position; start from the top.
  await t.drag(find.byType(ListView).first, const Offset(0, 1500));
  await t.pumpAndSettle();
}

void main() {
  group('backupReminderDays', () {
    final now = DateTime.utc(2026, 11, 21, 18);
    int? days(AppSettings s) => backupReminderDays(s, now);

    test('recent backup shows nothing', () {
      expect(
        days(AppSettings(lastBackupAt: now.subtract(const Duration(days: 14)))),
        isNull,
      );
    });

    test('older than 14 days shows the day count', () {
      expect(
        days(AppSettings(lastBackupAt: now.subtract(const Duration(days: 15)))),
        15,
      );
    });

    test('never backed up shows the reminder without a count', () {
      expect(days(const AppSettings()), -1);
    });

    test('dismissal hides it for 7 days', () {
      final old = now.subtract(const Duration(days: 30));
      expect(
        days(
          AppSettings(
            lastBackupAt: old,
            backupReminderDismissedAt: now.subtract(const Duration(days: 6)),
          ),
        ),
        isNull,
      );
      expect(
        days(
          AppSettings(
            lastBackupAt: old,
            backupReminderDismissedAt: now.subtract(const Duration(days: 7)),
          ),
        ),
        30,
      );
    });
  });

  testWidgets('mockup numbers', (t) async {
    final db = await openTestDb(t);
    await pumpMeskApp(t, db, '/bugun');
    expect(find.text('220'), findsOneWidget);
    expect(find.text('21 KASIM · CUMARTESİ'), findsOneWidget);
    expect(find.text('bugün 1 / 3'), findsOneWidget);
    expect(find.text('Sv. 23'), findsOneWidget);
    expect(
      find.textContaining('Marifetli', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('TOPLAM SEVİYE'), findsOneWidget);
    expect(find.text('Bugün 20 dk odak'), findsOneWidget);
    expect(find.text('Son çalıştıkların'), findsOneWidget);
    // The goal line of İngilizce, built from the goal card's own math.
    expect(find.textContaining('Hedef 100 sa'), findsOneWidget);
    // Recent backup: no reminder.
    expect(find.textContaining('Son yedeğin'), findsNothing);
  });

  testWidgets('rows open their pages', (t) async {
    final db = await openTestDb(t);
    await pumpMeskApp(t, db, '/bugun');
    await tapVisible(t, find.text('Sv. 23'));
    expect(currentLocation(t), '/yetenekler/ingilizce');

    await _home(t);
    await tapVisible(t, find.text('Tümü'));
    expect(currentLocation(t), '/yetenekler');

    await _home(t);
    await tapVisible(t, find.byTooltip('Ayarlar'));
    expect(currentLocation(t), '/ayarlar');

    await _home(t);
    await tapVisible(t, find.byTooltip('Yeni alışkanlık'));
    expect(currentLocation(t), '/aliskanlik/yeni');
  });

  testWidgets('empty habits show a guiding sentence and an action', (t) async {
    final db = await openTestDb(
      t,
      seed: (db) async {
        await seedDemo(db);
        for (final id in ['h-ingilizce', 'h-erken', 'h-sekersiz']) {
          await HabitsRepo(db).deleteWithChecks(id);
        }
      },
    );
    await pumpMeskApp(t, db, '/bugun');
    expect(find.text('Henüz alışkanlığın yok.'), findsOneWidget);
    await tapVisible(t, find.text('Yeni alışkanlık'));
    expect(currentLocation(t), '/aliskanlik/yeni');
  });

  testWidgets('Odaklan opens focus with last skill', (t) async {
    final db = await openTestDb(t);
    await pumpMeskApp(t, db, '/bugun');
    await tapVisible(t, find.text('Odaklan'));
    expect(currentLocation(t), startsWith('/odak'));
    expect(find.byType(FocusScreen), findsOneWidget);
    expect(find.text('İngilizce'), findsWidgets);
  });

  testWidgets('backup reminder after 14 days and dismiss', (t) async {
    final db = await openTestDb(t, seed: _backupAgo(15));
    await pumpMeskApp(t, db, '/bugun');
    expect(find.text('Son yedeğin üzerinden 15 gün geçti.'), findsOneWidget);

    await tapVisible(t, find.text('Yedek al'));
    expect(currentLocation(t), '/ayarlar');

    await _home(t);
    await tapVisible(t, find.text('Kapat'));
    expect(find.textContaining('Son yedeğin'), findsNothing);
    final saved = t.container().read(settingsProvider).value!;
    expect(saved.backupReminderDismissedAt, demoClock().nowUtc());
  });

  testWidgets('no backup yet also shows the reminder', (t) async {
    final db = await openTestDb(t, seed: _backupAgo(null));
    await pumpMeskApp(t, db, '/bugun');
    expect(find.text('Henüz yedek almadın.'), findsOneWidget);
  });

  testWidgets('today', (t) async {
    final db = await openTestDb(t);
    await pumpPhone(
      t,
      const TodayScreen(),
      overrides: appOverrides(db, demoClock()),
    );
    await expectGolden(t, 'today');
  }, tags: 'golden');
}
