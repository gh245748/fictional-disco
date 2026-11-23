import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../features/celebrations/celebration_host.dart';
import '../ui/theme.dart';
import 'providers.dart';
import 'router.dart';

/// Largest system text scale the layout supports (spec §5.13).
const double maxTextScale = 1.3;

class MeskApp extends ConsumerWidget {
  const MeskApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
