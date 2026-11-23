import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mesk/domain/stats.dart';
import 'package:mesk/ui/theme.dart';

void main() {
  test('tokens match spec', () {
    expect(MeskColors.bg, const Color(0xFF0E0D0C));
    expect(MeskColors.surface, const Color(0xFF161513));
    expect(MeskColors.surfaceBorder, const Color(0xFF24221F));
    expect(MeskColors.divider, const Color(0xFF1F1D1A));
    expect(MeskColors.navBg, const Color(0xFF121110));
    expect(MeskColors.text, const Color(0xFFEEE9E1));
    expect(MeskColors.muted, const Color(0xFFA39C91));
    expect(MeskColors.faint, const Color(0xFF8A8379));
    expect(MeskColors.accent, const Color(0xFFC9A86A));
    expect(MeskColors.accentHover, const Color(0xFFDEC089));
    expect(MeskColors.track, const Color(0xFF2A2722));

    expect(statColor(Stat.zihin), const Color(0xFF7891B4));
    expect(statColor(Stat.beden), const Color(0xFFB57A60));
    expect(statColor(Stat.yaraticilik), const Color(0xFFA08BBB));
    expect(statColor(Stat.karizma), const Color(0xFFC995A4));
    expect(statColor(Stat.denge), const Color(0xFF86A78A));
    expect(statColor(Stat.irade), const Color(0xFFADA491));
  });

  test('type scale matches spec', () {
    void check(
      TextStyle s,
      String family,
      FontWeight weight,
      double size, {
      FontStyle style = FontStyle.normal,
    }) {
      expect(
        (
          s.fontFamily,
          s.fontWeight,
          s.fontSize,
          s.fontStyle ?? FontStyle.normal,
        ),
        (family, weight, size, style),
      );
    }

    const c = 'CormorantGaramond';
    const m = 'Manrope';
    check(MeskType.screenTitle, c, FontWeight.w600, 40);
    check(MeskType.sectionTitle, c, FontWeight.w600, 24);
    check(MeskType.bigNumber, c, FontWeight.w500, 50);
    check(MeskType.levelNumber, c, FontWeight.w600, 21);
    check(
      MeskType.titleItalic,
      c,
      FontWeight.w500,
      16,
      style: FontStyle.italic,
    );
    check(MeskType.body15, m, FontWeight.w600, 15);
    check(MeskType.body14, m, FontWeight.w600, 14);
    check(MeskType.caption, m, FontWeight.w400, 12);
    check(MeskType.label, m, FontWeight.w600, 10.5);

    expect(MeskType.bigNumber.fontFeatures, [
      const FontFeature.liningFigures(),
      const FontFeature.tabularFigures(),
    ]);
    expect(MeskType.caption.color, MeskColors.muted);
    expect(MeskType.label.color, MeskColors.muted);
    expect(MeskType.label.letterSpacing, closeTo(1.68, 1e-9));
  });

  testWidgets('labels are upper-cased the Turkish way', (t) async {
    await t.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: MeskLabel('Toplam seviye · istanbul'),
      ),
    );
    expect(find.text('TOPLAM SEVİYE · İSTANBUL'), findsOneWidget);
  });

  test('contrast', () {
    expect(
      contrastRatio(MeskColors.muted, MeskColors.bg),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrastRatio(MeskColors.faint, MeskColors.bg),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrastRatio(MeskColors.text, MeskColors.surface),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrastRatio(MeskColors.bg, MeskColors.accent),
      greaterThanOrEqualTo(4.5),
    );
    // Symmetric, and 21:1 for black on white.
    expect(
      contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
      closeTo(21, 1e-9),
    );
    expect(
      contrastRatio(MeskColors.bg, MeskColors.accent),
      contrastRatio(MeskColors.accent, MeskColors.bg),
    );
  });

  test('theme uses the tokens', () {
    final theme = buildMeskTheme();
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, MeskColors.bg);
    expect(theme.colorScheme.primary, MeskColors.accent);
    expect(theme.colorScheme.onPrimary, MeskColors.bg);
    expect(theme.colorScheme.surface, MeskColors.surface);
    expect(theme.colorScheme.onSurface, MeskColors.text);
    expect(theme.dividerColor, MeskColors.divider);
  });
}
