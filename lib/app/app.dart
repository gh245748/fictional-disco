import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../features/celebrations/celebration_host.dart';
import '../features/focus/timer_controller.dart';
import '../features/habits/habits_controller.dart';
import '../ui/theme.dart';
import 'providers.dart';
import 'router.dart';

/// Largest system text scale the layout supports (spec §5.13).
const double maxTextScale = 1.3;

class MeskApp extends ConsumerStatefulWidget {
  const MeskApp({super.key});

  @override
  ConsumerState<MeskApp> createState() => _MeskAppState();
}

class _MeskAppState extends ConsumerState<MeskApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _resumed);
    // Habit reminders are re-planned at launch; the plan only covers a few
    // days ahead.
    _rescheduleHabits();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _resumed() async {
    _rescheduleHabits();
    await _timerResumed();
  }

  /// Re-plans the habit reminders (best effort; the controller swallows
  /// notification errors).
  void _rescheduleHabits() {
    ref.read(habitsControllerProvider).rescheduleReminders();
  }

  /// Whatever tab is open: close the phases that ended while away (which
  /// reschedules notifications), then ask the Odak screen to review them.
  Future<void> _timerResumed() async {
    try {
      await ref.read(timerControllerProvider.notifier).reconcile();
    } on Object {
      // The timer stays as stored; the next resume retries.
    }
    if (mounted) ref.read(timerCheckInProvider.notifier).request();
  }

  @override
  Widget build(BuildContext context) {
    // Loads the stored timer at launch and keeps it alive on every tab.
    ref.listen(timerControllerProvider, (_, _) {});
    // Wait for the settings so the first route already honours onboarding.
    final ready = ref.watch(
      settingsProvider.select((s) => s.hasValue || s.hasError),
    );
    if (!ready) return const ColoredBox(color: MeskColors.bg);
    return MaterialApp.router(
      title: 'Meşk',
      debugShowCheckedModeBanner: false,
      theme: buildMeskTheme(),
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(maxScaleFactor: maxTextScale),
          ),
          child: CelebrationHost(child: child!),
        );
      },
    );
  }
}
