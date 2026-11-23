import 'level_curve.dart';
import 'titles.dart';

/// A change of one skill's level (and hidden tier) between two XP snapshots.
class LevelChange {
  const LevelChange({
    required this.skillId,
    required this.fromLevel,
    required this.toLevel,
    this.fromTier,
    this.toTier,
    this.viaBonus = false,
  });

  final String skillId;
  final int fromLevel;
  final int toLevel;
  final HiddenTier? fromTier;
  final HiddenTier? toTier;

  /// The change came only from bonus XP, not from tracked time.
  final bool viaBonus;
}

/// Compares XP per skill. Skills missing from [xpBefore] count as 0 XP.
/// Only skills whose level or tier changed are returned, in [xpAfter] order.
List<LevelChange> diffLevels(
  Map<String, int> xpBefore,
  Map<String, int> xpAfter, {
  Set<String> bonusOnlySkillIds = const {},
}) {
  final changes = <LevelChange>[];
  for (final e in xpAfter.entries) {
    final before = xpBefore[e.key] ?? 0;
    final fromLevel = levelForXp(before);
    final toLevel = levelForXp(e.value);
    final fromTier = hiddenTierForXp(before);
    final toTier = hiddenTierForXp(e.value);
    if (fromLevel == toLevel && fromTier == toTier) continue;
    changes.add(
      LevelChange(
        skillId: e.key,
        fromLevel: fromLevel,
        toLevel: toLevel,
        fromTier: fromTier,
        toTier: toTier,
        viaBonus: bonusOnlySkillIds.contains(e.key),
      ),
    );
  }
  return changes;
}

enum CelebrationKind {
  levelUp,
  milestone,
  hiddenTier,
  achievement,
  goalCompleted,
}

class Celebration {
  const Celebration({
    required this.kind,
    this.skillId,
    this.fromLevel,
    this.toLevel,
    this.tier,
    this.achievementKey,
    this.goalId,
    this.viaBonus = false,
  });

  final CelebrationKind kind;
  final String? skillId;
  final int? fromLevel;
  final int? toLevel;
  final HiddenTier? tier;
  final String? achievementKey;
  final String? goalId;
  final bool viaBonus;
}

/// Cards for level increases only. One level card per skill (a milestone if
/// `(from, to]` contains a milestone level), followed by one card per newly
/// reached hidden tier. Output follows the order of [changes].
List<Celebration> celebrationsFor(List<LevelChange> changes) {
  final cards = <Celebration>[];
  for (final c in changes) {
    if (c.toLevel > c.fromLevel) {
      final milestone = milestoneLevels.any(
        (m) => m > c.fromLevel && m <= c.toLevel,
      );
      cards.add(
        Celebration(
          kind: milestone ? CelebrationKind.milestone : CelebrationKind.levelUp,
          skillId: c.skillId,
          fromLevel: c.fromLevel,
          toLevel: c.toLevel,
          viaBonus: c.viaBonus,
        ),
      );
    }
    final toTier = c.toTier;
    if (toTier != null) {
      final fromIndex = c.fromTier?.index ?? -1;
      for (final t in HiddenTier.values) {
        if (t.index > fromIndex && t.index <= toTier.index) {
          cards.add(
            Celebration(
              kind: CelebrationKind.hiddenTier,
              skillId: c.skillId,
              tier: t,
              viaBonus: c.viaBonus,
            ),
          );
        }
      }
    }
  }
  return cards;
}
