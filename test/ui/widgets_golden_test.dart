@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mesk/domain/stats.dart';
import 'package:mesk/ui/theme.dart';
import 'package:mesk/ui/widgets/buttons.dart';
import 'package:mesk/ui/widgets/mesk_card.dart';
import 'package:mesk/ui/widgets/progress_bar.dart';
import 'package:mesk/ui/widgets/progress_ring.dart';
import 'package:mesk/ui/widgets/radar_chart.dart';
import 'package:mesk/ui/widgets/section_header.dart';
import 'package:mesk/ui/widgets/stat_dot.dart';

import '../support/golden.dart';

/// The character stats of the Klasik mockup.
const demoStats = <Stat, double>{
  Stat.zihin: 113,
  Stat.beden: 46,
  Stat.yaraticilik: 38,
  Stat.karizma: 17,
  Stat.denge: 25,
  Stat.irade: 42,
};

class _Components extends StatelessWidget {
  const _Components({required this.onFocus});

  final VoidCallback onFocus;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            const MeskLabel('21 Kasım · Cumartesi'),
            const Text('Bugün', style: MeskType.screenTitle),
            MeskCard(
              child: Row(
                spacing: 16,
                children: [
                  const RadarChart(values: demoStats, size: 104),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const MeskLabel('Toplam seviye'),
                        const Text('220', style: MeskType.bigNumber),
                        const Text(
                          '348 sa · 13 yetenek',
                          style: MeskType.caption,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            for (final s in radarOrder)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                spacing: 6,
                                children: [
                                  StatDot(s, size: 6),
                                  Text(s.label, style: MeskType.caption),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            MeskCard(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Bugün 1 sa 15 dk odak',
                      style: MeskType.body15,
                    ),
                  ),
                  MeskPrimaryButton(
                    label: 'Odaklan',
                    icon: Icons.play_arrow_rounded,
                    onPressed: onFocus,
                  ),
                ],
              ),
            ),
            const SectionHeader(
              title: 'Son çalıştıkların',
              trailing: Text('bugün 1 / 3', style: MeskType.caption),
            ),
            MeskCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 6,
                children: [
                  const Row(
                    spacing: 8,
                    children: [
                      StatDot(Stat.zihin),
                      Expanded(
                        child: Text('İngilizce', style: MeskType.body15),
                      ),
                      Text('Sv. 23', style: MeskType.levelNumber),
                    ],
                  ),
                  const Text('Marifetli', style: MeskType.titleItalic),
                  MeskProgressBar(value: 0.52, color: statColor(Stat.zihin)),
                ],
              ),
            ),
            const Row(
              spacing: 16,
              children: [
                ProgressRing(value: 0.67, size: 26, color: MeskColors.accent),
                ProgressRing(value: 0.27, size: 64, color: MeskColors.accent),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('components', (t) async {
    var taps = 0;
    await pumpPhone(t, _Components(onFocus: () => taps++));

    await expectGolden(t, 'components');

    final button = t.getSize(find.byType(MeskPrimaryButton));
    expect(button.height, greaterThanOrEqualTo(44));
    await t.tap(find.text('Odaklan'));
    expect(taps, 1);
    expect(
      find.bySemanticsLabel('Stat dağılımı, en yüksek stat Zihin'),
      findsOneWidget,
    );
  }, skip: !Platform.isLinux);
}
