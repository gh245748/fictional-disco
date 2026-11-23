import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mesk/app/providers.dart';
import 'package:mesk/data/kv_repo.dart';
import 'package:mesk/data/log_pipeline.dart';
import 'package:mesk/domain/level_curve.dart';
import 'package:mesk/domain/level_events.dart';
import 'package:mesk/domain/models.dart';
import 'package:mesk/features/celebrations/cards.dart';
import 'package:mesk/features/celebrations/celebration_host.dart';
import 'package:mesk/features/skills/skill_detail_screen.dart';

import '../support/app_harness.dart';
import '../support/demo_data.dart';
import '../support/golden.dart';

/// Records `HapticFeedback.vibrate` calls for the rest of the test.
List<String> _recordHaptics(WidgetTester t) {
  final calls = <String>[];
  t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        calls.add(call.arguments as String);
      }
      return null;
    },
  );
  addTearDown(
    () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return calls;
}

void _push(WidgetTester t, List<Celebration> cards) =>
    t.container().read(celebrationQueueProvider.notifier).push(cards);

TimeEntry _hitabet(int seconds) => TimeEntry(
  id: 'new-hitabet',
  skillId: 'hitabet',
  startedAt: DateTime.utc(2026, 11, 21, 15),
  endedAt: DateTime.utc(2026, 11, 21, 15).add(Duration(seconds: seconds)),
  offsetMinutes: 180,
  seconds: seconds,
  source: EntrySource.manual,
  pomodoros: 0,
);

/// A button that runs [action] through [runAndCelebrate].
class _Runner extends ConsumerWidget {
  const _Runner(this.action);

  final Future<PipelineResult> Function(WidgetRef ref) action;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Center(
    child: TextButton(
      onPressed: () => runAndCelebrate(ref, () => action(ref)),
      child: const Text('Çalıştır'),
    ),
  );
}

void main() {
  testWidgets('multi-level combined card', (t) async {
    final db = await openTestDb(t);
    await pumpMeskApp(t, db, '/bugun');
    // Two hours lift Hitabet from 5 to 8 in one save.
    final result = (await t.runAsync(
      () => LogPipeline(db, demoClock()).saveEntry(_hitabet(7200)),
    ))!;
    final levelCards = result.celebrations
        .where((c) => c.kind == CelebrationKind.levelUp)
        .toList();
    expect(levelCards, hasLength(1));
    _push(t, result.celebrations);
    await t.pumpAndSettle();

    expect(find.byType(CelebrationOverlay), findsOneWidget);
    expect(find.text('HİTABET'), findsOneWidget);
    expect(find.text('Sv. 5 → 8'), findsOneWidget);
    expect(find.text('Talebe'), findsOneWidget);
    expect(
      find.text(
        'Kendini öğrenmeye adadın; her dersi bir şükranla karşılıyorsun.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Sv. 6'), findsNothing);
    expect(find.textContaining('Sv. 7'), findsNothing);

    await t.tap(find.text('Devam'));
    await t.pumpAndSettle();
    expect(find.text('Sv. 5 → 8'), findsNothing);
  });

  testWidgets('runAndCelebrate queues the pipeline cards', (t) async {
    final db = await openTestDb(t);
    await pumpPhone(
      t,
      CelebrationHost(
        child: _Runner(
          (ref) => ref.read(pipelineProvider).saveEntry(_hitabet(3600)),
        ),
      ),
      overrides: appOverrides(db, demoClock()),
    );
    await t.tap(find.text('Çalıştır'));
    await t.pumpAndSettle();
    expect(find.text('Sv. 5 → 7'), findsOneWidget);
  });

  testWidgets('single level shows only the new level', (t) async {
    final db = await openTestDb(t);
    await pumpMeskApp(t, db, '/bugun');
    _push(t, [
      const Celebration(
        kind: CelebrationKind.levelUp,
        skillId: 'gitar',
        fromLevel: 18,
        toLevel: 19,
        viaBonus: true,
      ),
    ]);
    await t.pumpAndSettle();
    expect(find.text('Sv. 19'), findsOneWidget);
    expect(find.text('(bağ bonusu)'), findsOneWidget);
  });

  testWidgets('cards are shown one by one', (t) async {
    final db = await openTestDb(t);
    await pumpMeskApp(t, db, '/bugun');
    _push(t, [
      const Celebration(
        kind: CelebrationKind.levelUp,
        skillId: 'gitar',
        fromLevel: 18,
        toLevel: 19,
      ),
      const Celebration(
        kind: CelebrationKind.goalCompleted,
        skillId: 'ingilizce',
        goalId: 'g-ingilizce',
      ),
      const Celebration(
        kind: CelebrationKind.achievement,
        achievementKey: 'derin_dalis',
      ),
    ]);
    await t.pumpAndSettle();
    expect(find.text('Sv. 19'), findsOneWidget);
    expect(find.text('Hedefe ulaştın'), findsNothing);

    // Tapping anywhere on the card moves on.
    await t.tap(find.text('Sv. 19'));
    await t.pumpAndSettle();
    expect(find.text('Sv. 19'), findsNothing);
    expect(find.text('Hedefe ulaştın'), findsOneWidget);
    expect(find.text('İngilizce · 100 sa'), findsOneWidget);

    await t.tap(find.text('Devam'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Derin Dalış'), findsOneWidget);
    expect(find.text('Tek oturumda 2 saat çalışma'), findsOneWidget);

    // The toast leaves by itself.
    await t.pump(const Duration(seconds: 5));
    await t.pumpAndSettle();
    expect(find.text('Derin Dalış'), findsNothing);
    expect(t.container().read(celebrationQueueProvider), isEmpty);
  });

  testWidgets('milestone names the new band', (t) async {
    final db = await openTestDb(t);
    await pumpMeskApp(t, db, '/bugun');
    _push(t, [
      const Celebration(
        kind: CelebrationKind.milestone,
        skillId: 'cizim',
        fromLevel: 9,
        toLevel: 10,
      ),
    ]);
    await t.pumpAndSettle();
    expect(find.text('Sv. 10'), findsWidgets);
    expect(find.text('Çırak'), findsOneWidget);
    expect(find.text('Çıraklık kademesine geçtin'), findsOneWidget);
  });

  testWidgets('milestone within a band has no band line', (t) async {
    final db = await openTestDb(t);
    await pumpMeskApp(t, db, '/bugun');
    _push(t, [
      const Celebration(
        kind: CelebrationKind.milestone,
        skillId: 'cizim',
        fromLevel: 10,
        toLevel: 10,
      ),
    ]);
    await t.pumpAndSettle();
    expect(find.textContaining('kademesine geçtin'), findsNothing);
  });

  testWidgets('hidden tier reveals its name', (t) async {
    final db = await openTestDb(t);
    await pumpMeskApp(t, db, '/bugun');
    _push(t, [
      const Celebration(
        kind: CelebrationKind.hiddenTier,
        skillId: 'yazilim',
        tier: HiddenTier.cinar,
      ),
    ]);
    await t.pump();
    expect(find.text('???'), findsOneWidget);
    await t.pumpAndSettle();
    final name = t.widget<FadeTransition>(
      find
          .ancestor(
            of: find.text('Çınar'),
            matching: find.byType(FadeTransition),
          )
          .first,
    );
    expect(name.opacity.value, 1);
    expect(find.text('Kökleri derinde, gölgesi geniş.'), findsOneWidget);
  });

  testWidgets('level up vibrates when enabled', (t) async {
    final haptics = _recordHaptics(t);
    final db = await openTestDb(t);
    await pumpMeskApp(t, db, '/bugun');
    _push(t, [
      const Celebration(
        kind: CelebrationKind.levelUp,
        skillId: 'gitar',
        fromLevel: 18,
        toLevel: 19,
      ),
    ]);
    await t.pumpAndSettle();
    expect(haptics, ['HapticFeedbackType.mediumImpact']);
  });

  testWidgets('no vibration when disabled in settings', (t) async {
    final haptics = _recordHaptics(t);
    final db = await openTestDb(t);
    await t.runAsync(() async {
      final kv = KvRepo(db);
      await kv.saveSettings((await kv.settings()).copyWith(vibration: false));
    });
    await pumpMeskApp(t, db, '/bugun');
    _push(t, [
      const Celebration(
        kind: CelebrationKind.levelUp,
        skillId: 'gitar',
        fromLevel: 18,
        toLevel: 19,
      ),
    ]);
    await t.pumpAndSettle();
    expect(find.text('Sv. 19'), findsOneWidget);
    expect(haptics, isEmpty);
  });

  testWidgets('celebration level up', (t) async {
    final db = await openTestDb(t);
    await pumpPhone(
      t,
      const CelebrationHost(child: SkillDetailScreen(skillId: 'hitabet')),
      overrides: appOverrides(db, demoClock()),
    );
    _push(t, [
      const Celebration(
        kind: CelebrationKind.levelUp,
        skillId: 'hitabet',
        fromLevel: 5,
        toLevel: 8,
        viaBonus: true,
      ),
    ]);
    await t.pumpAndSettle();
    await expectGolden(t, 'celebration_level_up');
  }, tags: 'golden');
}
