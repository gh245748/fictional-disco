import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../domain/format.dart';
import '../../domain/level_curve.dart';
import '../../domain/titles.dart';
import '../../ui/theme.dart';

/// "Unvan yolu" (§5.5): all 99 titles by band, reached ones bright with
/// their date, future ones faint. From level 99 on, the three hidden tiers
/// follow as "???" until reached; before that they are not mentioned at all
/// (§5.3, Ruling R16).
class TitlePathScreen extends ConsumerWidget {
  const TitlePathScreen({super.key, required this.skillId});

  final String skillId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(skillViewProvider(skillId)).value;
    final clock = ref.watch(clockProvider);
    final levelDates = {
      for (final r in ref.watch(levelReachedProvider).value ?? const [])
        if (r.skillId == skillId) r.level: r.at,
    };
    final tierDates = {
      for (final r in ref.watch(tierReachedProvider).value ?? const [])
        if (r.skillId == skillId) r.tier: r.at,
    };
    String date(DateTime utc) =>
        formatDate(utc.add(Duration(minutes: clock.offsetMinutesAt(utc))));

    final rows = <Widget>[
      if (view != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '${view.skill.name} · Sv. ${view.level}',
            style: MeskType.caption,
          ),
        ),
    ];
    Band? band;
    for (var level = 1; level <= maxLevel; level++) {
      final b = bandForLevel(level);
      if (b != band) {
        band = b;
        rows.add(_BandHeader(b));
      }
      final at = levelDates[level];
      rows.add(
        _TitleRow(
          number: '$level',
          title: titleForLevel(level),
          date: at == null ? null : date(at),
          current: view?.tier == null && view?.level == level,
          milestone: milestoneLevels.contains(level),
        ),
      );
    }
    final showTiers = (view?.level ?? 1) >= maxLevel;
    for (final t in showTiers ? HiddenTier.values : const <HiddenTier>[]) {
      final at = tierDates[t];
      rows.add(
        _TitleRow(
          number: '·',
          title: at == null ? '???' : hiddenTierName(t),
          date: at == null ? null : date(at),
          current: view?.tier == t,
          milestone: true,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Unvan yolu', style: MeskType.sectionTitle),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: rows,
        ),
      ),
    );
  }
}

class _BandHeader extends StatelessWidget {
  const _BandHeader(this.band);

  final Band band;

  @override
  Widget build(BuildContext context) {
    final levels = [
      for (var l = 1; l <= maxLevel; l++)
        if (bandForLevel(l) == band) l,
    ];
    final range = levels.length == 1
        ? 'Sv. ${levels.first}'
        : 'Sv. ${levels.first}–${levels.last}';
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 6),
      child: Semantics(
        header: true,
        child: Row(
          spacing: 8,
          children: [
            MeskLabel(band.label),
            Text(range, style: MeskType.caption),
          ],
        ),
      ),
    );
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({
    required this.number,
    required this.title,
    required this.date,
    required this.current,
    required this.milestone,
  });

  final String number;
  final String title;

  /// Local date the title was first reached; null while it is ahead.
  final String? date;
  final bool current;
  final bool milestone;

  @override
  Widget build(BuildContext context) {
    final reached = date != null;
    final color = reached ? MeskColors.text : MeskColors.faint;
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: current ? MeskColors.chipSelected : null,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        spacing: 12,
        children: [
          SizedBox(
            width: 30,
            child: Text(
              number,
              style: MeskType.levelNumber.copyWith(
                fontSize: 17,
                color: milestone && reached ? MeskColors.accent : color,
              ),
            ),
          ),
          Expanded(
            child: Text(
              title,
              style: MeskType.titleItalic.copyWith(fontSize: 18, color: color),
            ),
          ),
          if (date case final d?) Text(d, style: MeskType.caption),
        ],
      ),
    );
  }
}
