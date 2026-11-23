import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../domain/format.dart';
import '../domain/stats.dart';

/// Color tokens of the Klasik mockup (spec §5.13).
abstract final class MeskColors {
  static const Color bg = Color(0xFF0E0D0C);
  static const Color surface = Color(0xFF161513);
  static const Color surfaceBorder = Color(0xFF24221F);
  static const Color divider = Color(0xFF1F1D1A);
  static const Color navBg = Color(0xFF121110);
  static const Color text = Color(0xFFEEE9E1);
  static const Color muted = Color(0xFFA39C91);
  static const Color faint = Color(0xFF8A8379);
  static const Color accent = Color(0xFFC9A86A);
  static const Color accentHover = Color(0xFFDEC089);
  static const Color track = Color(0xFF2A2722);

  /// Fill of selected chips.
  static const Color chipSelected = Color(0xFF2A2418);

  /// Muted red for destructive actions.
  static const Color danger = Color(0xFFE08A73);

  /// [bg] at 88 % behind celebration cards.
  static const Color scrim = Color(0xE00E0D0C);
}

Color statColor(Stat s) => switch (s) {
  Stat.zihin => const Color(0xFF7891B4),
  Stat.beden => const Color(0xFFB57A60),
  Stat.yaraticilik => const Color(0xFFA08BBB),
  Stat.karizma => const Color(0xFFC995A4),
  Stat.denge => const Color(0xFF86A78A),
  Stat.irade => const Color(0xFFADA491),
};

/// Border of a selected chip.
const BorderSide meskSelectedChipSide = BorderSide(color: MeskColors.accent);

/// The shared chip look, also set as the theme's `chipTheme`.
const ChipThemeData meskChipTheme = ChipThemeData(
  shape: StadiumBorder(),
  showCheckmark: false,
  backgroundColor: MeskColors.surface,
  selectedColor: MeskColors.chipSelected,
  side: BorderSide(color: MeskColors.surfaceBorder),
  labelStyle: MeskType.body14,
  padding: EdgeInsets.symmetric(horizontal: 6),
);

/// Type scale (spec §5.13).
abstract final class MeskType {
  static const String serif = 'CormorantGaramond';
  static const String sans = 'Manrope';

  static const TextStyle screenTitle = TextStyle(
    fontFamily: serif,
    fontWeight: FontWeight.w600,
    fontSize: 40,
    height: 1.05,
    color: MeskColors.text,
    fontFeatures: [FontFeature.liningFigures()],
  );
  static const TextStyle sectionTitle = TextStyle(
    fontFamily: serif,
    fontWeight: FontWeight.w600,
    fontSize: 24,
    height: 1.1,
    color: MeskColors.text,
    fontFeatures: [FontFeature.liningFigures()],
  );
  static const TextStyle bigNumber = TextStyle(
    fontFamily: serif,
    fontWeight: FontWeight.w500,
    fontSize: 50,
    height: 0.95,
    color: MeskColors.text,
    fontFeatures: [FontFeature.liningFigures(), FontFeature.tabularFigures()],
  );
  static const TextStyle levelNumber = TextStyle(
    fontFamily: serif,
    fontWeight: FontWeight.w600,
    fontSize: 21,
    height: 1,
    color: MeskColors.text,
    fontFeatures: [FontFeature.liningFigures()],
  );
  static const TextStyle titleItalic = TextStyle(
    fontFamily: serif,
    fontWeight: FontWeight.w500,
    fontStyle: FontStyle.italic,
    fontSize: 16,
    color: MeskColors.text,
  );
  static const TextStyle body15 = TextStyle(
    fontFamily: sans,
    fontWeight: FontWeight.w600,
    fontSize: 15,
    color: MeskColors.text,
  );
  static const TextStyle body14 = TextStyle(
    fontFamily: sans,
    fontWeight: FontWeight.w600,
    fontSize: 14,
    color: MeskColors.text,
  );
  static const TextStyle caption = TextStyle(
    fontFamily: sans,
    fontWeight: FontWeight.w400,
    fontSize: 12,
    color: MeskColors.muted,
  );

  /// Small caps-style label; use [MeskLabel] so the text is upper-cased with
  /// [trUpper].
  static const TextStyle label = TextStyle(
    fontFamily: sans,
    fontWeight: FontWeight.w600,
    fontSize: 10.5,
    letterSpacing: 1.68, // 0.16 em
    color: MeskColors.muted,
  );
}

/// A [MeskType.label] whose text is upper-cased the Turkish way.
class MeskLabel extends StatelessWidget {
  const MeskLabel(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    trUpper(text),
    style: color == null
        ? MeskType.label
        : MeskType.label.copyWith(color: color),
  );
}

/// WCAG 2.x contrast ratio between two opaque colors (1..21).
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

ThemeData buildMeskTheme() {
  const scheme = ColorScheme.dark(
    primary: MeskColors.accent,
    onPrimary: MeskColors.bg,
    secondary: MeskColors.accentHover,
    onSecondary: MeskColors.bg,
    surface: MeskColors.surface,
    onSurface: MeskColors.text,
    onSurfaceVariant: MeskColors.muted,
    outline: MeskColors.surfaceBorder,
    outlineVariant: MeskColors.divider,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    fontFamily: MeskType.sans,
    scaffoldBackgroundColor: MeskColors.bg,
    canvasColor: MeskColors.bg,
    dividerColor: MeskColors.divider,
    splashFactory: InkRipple.splashFactory,
  );
  return base.copyWith(
    textTheme: base.textTheme
        .apply(
          bodyColor: MeskColors.text,
          displayColor: MeskColors.text,
          fontFamily: MeskType.sans,
        )
        .copyWith(
          headlineLarge: MeskType.screenTitle,
          headlineMedium: MeskType.sectionTitle,
          titleMedium: MeskType.body15,
          bodyLarge: MeskType.body15.copyWith(fontWeight: FontWeight.w400),
          bodyMedium: MeskType.body14.copyWith(fontWeight: FontWeight.w400),
          bodySmall: MeskType.caption,
          labelLarge: MeskType.body14,
          labelSmall: MeskType.label,
        ),
    chipTheme: meskChipTheme,
    dividerTheme: const DividerThemeData(
      color: MeskColors.divider,
      thickness: 1,
      space: 1,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: MeskColors.bg,
      foregroundColor: MeskColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: MeskColors.accent,
      linearTrackColor: MeskColors.track,
    ),
  );
}
