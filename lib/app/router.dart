import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../features/onboarding/onboarding_screen.dart';
import '../ui/theme.dart';
import 'providers.dart';
import 'shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = buildRouter(ref);
  ref.onDispose(router.dispose);
  return router;
});

/// The app's routes: five tabs in a [StatefulShellRoute] and full-screen
/// pages above them. Users who have not finished onboarding are sent to
/// `/baslangic`.
GoRouter buildRouter(Ref ref) {
  final refresh = ValueNotifier<bool?>(null);
  ref.onDispose(refresh.dispose);
  ref.listen(
    settingsProvider.select((s) => s.value?.onboarded),
    (_, onboarded) => refresh.value = onboarded,
    fireImmediately: true,
  );

  GoRoute page(
    String path,
    String title, {
    List<RouteBase> routes = const [],
  }) => GoRoute(
    path: path,
    builder: (_, _) => PlaceholderScreen(title),
    routes: routes,
  );

  StatefulShellBranch tab(String path, String title) => StatefulShellBranch(
    routes: [
      GoRoute(
        path: path,
        builder: (_, _) => PlaceholderScreen(title, tab: true),
      ),
    ],
  );

  return GoRouter(
    initialLocation: '/bugun',
    refreshListenable: refresh,
    redirect: (context, state) {
      final onboarded = ref.read(settingsProvider).value?.onboarded;
      if (onboarded == null) return null; // settings still loading
      final atOnboarding = state.matchedLocation == '/baslangic';
      if (!onboarded) return atOnboarding ? null : '/baslangic';
      return atOnboarding ? '/bugun' : null;
    },
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/bugun'),
      GoRoute(path: '/baslangic', builder: (_, _) => const OnboardingScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => MeskShell(navigationShell: shell),
        branches: [
          tab('/bugun', 'Bugün'),
          tab('/yetenekler', 'Yetenekler'),
          tab('/odak', 'Odak'),
          tab('/ag', 'Ağ'),
          tab('/karakter', 'Karakter'),
        ],
      ),
      page('/yetenekler/yeni', 'Yeni yetenek'),
      page(
        '/yetenekler/:id',
        'Yetenek',
        routes: [
          page('duzenle', 'Yeteneği düzenle'),
          page('unvanlar', 'Unvan yolu'),
        ],
      ),
      // Query parameters: `skill` (skill id) and `prior` (prior experience).
      page('/kayit/yeni', 'Yeni kayıt'),
      page('/kayit/:entryId', 'Kayıt'),
      page('/aliskanlik/yeni', 'Yeni alışkanlık'),
      page('/aliskanlik/:id', 'Alışkanlık'),
      page('/hedef/:skillId', 'Hedef'),
      page('/basarimlar', 'Başarımlar'),
      page(
        '/ayarlar',
        'Ayarlar',
        routes: [
          page('setler', 'Pomodoro setleri', routes: [page(':id', 'Set')]),
        ],
      ),
    ],
  );
}

/// Stand-in for screens later tasks build: the page name, centered.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen(this.title, {super.key, this.tab = false});

  final String title;

  /// Tab roots have no app bar; pages above the tabs get one with a back
  /// button.
  final bool tab;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: tab ? null : AppBar(),
    body: Center(child: Text(title, style: MeskType.sectionTitle)),
  );
}
