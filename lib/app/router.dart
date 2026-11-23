import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../features/achievements/achievements_screen.dart';
import '../features/character/character_screen.dart';
import '../features/entries/entry_form_screen.dart';
import '../features/focus/focus_screen.dart';
import '../features/goals/goal_edit_screen.dart';
import '../features/graph/graph_screen.dart';
import '../features/habits/habit_edit_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/settings/presets_screen.dart';
import '../features/skills/skill_detail_screen.dart';
import '../features/skills/skill_edit_screen.dart';
import '../features/skills/skills_screen.dart';
import '../features/skills/title_path_screen.dart';
import '../features/today/today_screen.dart';
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

  StatefulShellBranch tab(
    String path,
    String title, {
    Widget Function()? screen,
  }) => StatefulShellBranch(
    routes: [
      GoRoute(
        path: path,
        builder: (_, _) =>
            screen?.call() ?? PlaceholderScreen(title, tab: true),
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
          tab('/bugun', 'Bugün', screen: TodayScreen.new),
          tab('/yetenekler', 'Yetenekler', screen: SkillsScreen.new),
          // Query parameter: `skill` (skill id to preselect).
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/odak',
                builder: (_, state) =>
                    FocusScreen(skillId: state.uri.queryParameters['skill']),
              ),
            ],
          ),
          tab('/ag', 'Ağ', screen: GraphScreen.new),
          tab('/karakter', 'Karakter', screen: CharacterScreen.new),
        ],
      ),
      GoRoute(
        path: '/yetenekler/yeni',
        builder: (_, _) => const SkillEditScreen(),
      ),
      GoRoute(
        path: '/yetenekler/:id',
        builder: (_, state) =>
            SkillDetailScreen(skillId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'duzenle',
            builder: (_, state) =>
                SkillEditScreen(skillId: state.pathParameters['id']),
          ),
          GoRoute(
            path: 'unvanlar',
            builder: (_, state) =>
                TitlePathScreen(skillId: state.pathParameters['id']!),
          ),
        ],
      ),
      // Query parameters: `skill` (skill id) and `prior=1` (prior experience).
      GoRoute(
        path: '/kayit/yeni',
        builder: (_, state) => EntryFormScreen(
          skillId: state.uri.queryParameters['skill'],
          prior: state.uri.queryParameters['prior'] == '1',
        ),
      ),
      GoRoute(
        path: '/kayit/:entryId',
        builder: (_, state) =>
            EntryFormScreen(entryId: state.pathParameters['entryId']),
      ),
      GoRoute(
        path: '/aliskanlik/yeni',
        builder: (_, _) => const HabitEditScreen(),
      ),
      GoRoute(
        path: '/aliskanlik/:id',
        builder: (_, state) =>
            HabitEditScreen(habitId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/hedef/:skillId',
        builder: (_, state) =>
            GoalEditScreen(skillId: state.pathParameters['skillId']!),
      ),
      GoRoute(
        path: '/basarimlar',
        builder: (_, _) => const AchievementsScreen(),
      ),
      page(
        '/ayarlar',
        'Ayarlar',
        routes: [
          GoRoute(
            path: 'setler',
            builder: (_, _) => const PresetsScreen(),
            routes: [
              // `:id` is a preset id, or `yeni` for a new set.
              GoRoute(
                path: ':id',
                builder: (_, state) =>
                    PresetEditScreen(presetId: state.pathParameters['id']!),
              ),
            ],
          ),
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
