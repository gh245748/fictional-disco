import 'models.dart';

/// Per-skill time totals, all in seconds.
class SkillTotals {
  const SkillTotals({
    required this.realSeconds,
    required this.priorSeconds,
    required this.bonusSeconds,
  });

  static const SkillTotals zero = SkillTotals(
    realSeconds: 0,
    priorSeconds: 0,
    bonusSeconds: 0,
  );

  /// All entry time, prior experience included.
  final int realSeconds;

  /// The part of [realSeconds] that came from prior-experience entries.
  final int priorSeconds;

  /// XP received through skill links.
  final int bonusSeconds;

  /// What levels are computed from: real time plus link bonus.
  int get xpSeconds => realSeconds + bonusSeconds;

  /// Real time excluding prior experience.
  int get trackedSeconds => realSeconds - priorSeconds;
}

Map<String, SkillTotals> computeTotals(
  Iterable<TimeEntry> entries,
  Iterable<XpAward> awards,
) {
  final real = <String, int>{};
  final prior = <String, int>{};
  final bonus = <String, int>{};
  for (final e in entries) {
    real.update(e.skillId, (v) => v + e.seconds, ifAbsent: () => e.seconds);
    if (e.isPrior) {
      prior.update(e.skillId, (v) => v + e.seconds, ifAbsent: () => e.seconds);
    }
  }
  for (final a in awards) {
    bonus.update(a.skillId, (v) => v + a.seconds, ifAbsent: () => a.seconds);
  }
  return {
    for (final id in {...real.keys, ...bonus.keys})
      id: SkillTotals(
        realSeconds: real[id] ?? 0,
        priorSeconds: prior[id] ?? 0,
        bonusSeconds: bonus[id] ?? 0,
      ),
  };
}

/// Skills directly linked to [skillId] (no chaining).
Set<String> linkedSkillIds(String skillId, Iterable<SkillLink> links) => {
  for (final l in links)
    if (l.a == skillId) l.b else if (l.b == skillId) l.a,
};

/// Bonus awards for [entry]: [rateBp] basis points of its seconds to each
/// linked skill. Prior-experience entries earn none.
List<XpAward> awardsForEntry(
  TimeEntry entry,
  Set<String> linked,
  int rateBp,
  String Function() newId,
) {
  if (entry.isPrior || rateBp <= 0) return const [];
  return [
    for (final skillId in linked)
      XpAward(
        id: newId(),
        entryId: entry.id,
        skillId: skillId,
        seconds: entry.seconds * rateBp ~/ 10000,
        rateBp: rateBp,
      ),
  ];
}

/// Recomputes award seconds after an entry changed, keeping each recorded rate.
List<XpAward> rescaleAwards(List<XpAward> awards, int newEntrySeconds) => [
  for (final a in awards)
    a.copyWith(seconds: newEntrySeconds * a.rateBp ~/ 10000),
];
