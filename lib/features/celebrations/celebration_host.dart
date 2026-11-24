import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../data/log_pipeline.dart';
import '../../domain/level_events.dart';
import '../habits/habits_controller.dart';
import 'cards.dart';

/// Runs a pipeline [action] and queues the celebrations it returns. Every
/// caller of the [LogPipeline] goes through this. Errors are rethrown and
/// queue nothing.
///
/// Afterwards the habit reminders are planned again: time entries can
/// complete (or un-complete) a timed habit, which changes today's reminder.
Future<void> runAndCelebrate(
  WidgetRef ref,
  Future<PipelineResult> Function() action,
) async {
  // Read before awaiting: the caller may be gone when the action finishes.
  final queue = ref.read(celebrationQueueProvider.notifier);
  final habits = ref.read(habitsControllerProvider);
  final result = await action();
  queue.push(result.celebrations);
  // Best effort; never fails the caller.
  await habits.rescheduleReminders();
}

/// Shows the queued celebrations above [child], one at a time.
class CelebrationHost extends ConsumerStatefulWidget {
  const CelebrationHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CelebrationHost> createState() => _CelebrationHostState();
}

class _CelebrationHostState extends ConsumerState<CelebrationHost> {
  /// Counts dismissed cards so each card gets fresh animation state.
  int _shown = 0;

  /// Dismisses card number [serial]; repeated calls for it are ignored.
  void _dismiss(int serial) {
    if (serial != _shown) return;
    final queue = ref.read(celebrationQueueProvider.notifier);
    queue.pop();
    setState(() => _shown++);
    final next = ref.read(celebrationQueueProvider).firstOrNull;
    if (next != null) _announce(next);
  }

  /// Level cards come with a medium vibration when vibration is on (§5.13).
  void _announce(Celebration c) {
    const levelKinds = {
      CelebrationKind.levelUp,
      CelebrationKind.milestone,
      CelebrationKind.hiddenTier,
    };
    if (!levelKinds.contains(c.kind)) return;
    if (ref.read(settingsProvider).value?.vibration ?? true) {
      HapticFeedback.mediumImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<List<Celebration>>(celebrationQueueProvider, (prev, next) {
      if ((prev == null || prev.isEmpty) && next.isNotEmpty) {
        _announce(next.first);
      }
    });
    final head = ref.watch(celebrationQueueProvider).firstOrNull;
    final serial = _shown;
    final skills = ref.watch(skillsProvider).value ?? const [];
    final goals = ref.watch(goalsProvider).value ?? const [];
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (head != null)
          Positioned.fill(
            child: CelebrationOverlay(
              key: ValueKey(serial),
              celebration: head,
              onDismiss: () => _dismiss(serial),
              skillName:
                  skills.where((s) => s.id == head.skillId).firstOrNull?.name ??
                  '',
              goalTargetSeconds: goals
                  .where((g) => g.id == head.goalId)
                  .firstOrNull
                  ?.targetSeconds,
            ),
          ),
      ],
    );
  }
}
