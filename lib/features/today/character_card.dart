import 'package:material_ui/material_ui.dart';

import '../../app/views.dart';
import '../../domain/format.dart';
import '../../domain/stats.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/mesk_card.dart';
import '../../ui/widgets/radar_chart.dart';
import '../../ui/widgets/stat_dot.dart';

/// The character summary of Today: radar, total level and the six stats.
class CharacterCard extends StatelessWidget {
  const CharacterCard(this.view, {super.key});

  final CharacterView view;

  @override
  Widget build(BuildContext context) => MeskCard(
    child: Row(
      spacing: 16,
      children: [
        RadarChart(
          size: 104,
          values: {
            for (final e in view.stats.entries) e.key: e.value.toDouble(),
          },
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              const MeskLabel('Toplam seviye'),
              Text('${view.totalLevel}', style: MeskType.bigNumber),
              Text(
                '${formatHours(view.totalRealSeconds)} · '
                '${view.skillCount} yetenek',
                style: MeskType.caption,
              ),
              const SizedBox(height: 6),
              _StatGrid(view.stats),
            ],
          ),
        ),
      ],
    ),
  );
}

class _StatGrid extends StatelessWidget {
  const _StatGrid(this.stats);

  final Map<Stat, int> stats;

  @override
  Widget build(BuildContext context) {
    Widget cell(Stat s) => Row(
      spacing: 6,
      children: [
        StatDot(s, size: 6),
        Expanded(
          child: Text(
            s.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MeskType.caption,
          ),
        ),
        Text(
          '${stats[s] ?? 0}',
          style: const TextStyle(
            fontFamily: MeskType.sans,
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: MeskColors.text,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
    final all = Stat.values;
    return Column(
      spacing: 4,
      children: [
        for (var i = 0; i < all.length; i += 2)
          Row(
            spacing: 12,
            children: [
              Expanded(child: cell(all[i])),
              Expanded(child: cell(all[i + 1])),
            ],
          ),
      ],
    );
  }
}
