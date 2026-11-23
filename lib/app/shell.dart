import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../ui/theme.dart';
import '../ui/widgets/nav_icons.dart';

/// The five-tab frame: the active branch above the 72 px bottom navigation.
class MeskShell extends StatelessWidget {
  const MeskShell({super.key, required this.navigationShell});

  /// Key of the 72 px navigation bar (without the bottom safe area).
  static const navKey = ValueKey('mesk-nav');

  static const tabs = <(String, NavGlyph)>[
    ('Bugün', NavGlyph.bugun),
    ('Yetenekler', NavGlyph.yetenekler),
    ('Odak', NavGlyph.odak),
    ('Ağ', NavGlyph.ag),
    ('Karakter', NavGlyph.karakter),
  ];

  final StatefulNavigationShell navigationShell;

  void _select(int index) => navigationShell.goBranch(
    index,
    // Tapping the active tab goes back to its first page.
    initialLocation: index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: navigationShell,
    bottomNavigationBar: ColoredBox(
      color: MeskColors.navBg,
      child: SafeArea(
        top: false,
        child: SizedBox(
          key: navKey,
          height: 72,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: MeskColors.divider)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
              child: Semantics(
                container: true,
                label: 'Ana gezinme',
                // Equal-width tabs (about 75 px on a 390 px phone; the same
                // centres as the mockup's 68 px items with space-around).
                child: Row(
                  children: [
                    for (final (i, (label, glyph)) in tabs.indexed)
                      Expanded(
                        child: _NavItem(
                          label: label,
                          glyph: glyph,
                          active: i == navigationShell.currentIndex,
                          onTap: () => _select(i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.glyph,
    required this.active,
    required this.onTap,
  });

  final String label;
  final NavGlyph glyph;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? MeskColors.accent : MeskColors.faint;
    return Semantics(
      button: true,
      selected: active,
      child: InkResponse(
        onTap: onTap,
        radius: 34,
        highlightColor: Colors.transparent,
        child: SizedBox(
          height: 54,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 4,
            children: [
              NavIcon(glyph, color: color),
              // At large text scales a long label shrinks instead of clipping.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: MeskType.sans,
                      fontSize: 11,
                      height: 1.2,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      color: color,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
