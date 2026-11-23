import 'package:flutter_test/flutter_test.dart';
import 'package:mesk/domain/level_events.dart';
import 'package:mesk/domain/level_curve.dart';

void main() {
  test('diff 1→3 is one levelUp card', () {
    final changes = diffLevels({'A': 0}, {'A': 1800});
    expect(changes, hasLength(1));
    expect(changes.single.fromLevel, 1);
    expect(changes.single.toLevel, 3);
    final cards = celebrationsFor(changes);
    expect(cards, hasLength(1));
    expect(cards.single.kind, CelebrationKind.levelUp);
    expect(cards.single.skillId, 'A');
    expect(cards.single.fromLevel, 1);
    expect(cards.single.toLevel, 3);
  });

  test('milestone', () {
    final cards = celebrationsFor([
      const LevelChange(skillId: 'A', fromLevel: 9, toLevel: 11),
    ]);
    expect(cards.single.kind, CelebrationKind.milestone);
  });

  test('landing exactly on a milestone is a milestone, leaving it is not', () {
    expect(
      celebrationsFor([
        const LevelChange(skillId: 'A', fromLevel: 9, toLevel: 10),
      ]).single.kind,
      CelebrationKind.milestone,
    );
    expect(
      celebrationsFor([
        const LevelChange(skillId: 'A', fromLevel: 10, toLevel: 11),
      ]).single.kind,
      CelebrationKind.levelUp,
    );
  });

  test('tier', () {
    const h = 3600;
    final changes = diffLevels({'A': 2499 * h}, {'A': 2500 * h});
    expect(changes.single.fromTier, isNull);
    expect(changes.single.toTier, HiddenTier.cinar);
    final cards = celebrationsFor(changes);
    expect(cards, hasLength(1));
    expect(cards.single.kind, CelebrationKind.hiddenTier);
    expect(cards.single.tier, HiddenTier.cinar);
  });

  test('level card then tier cards, in input order', () {
    const h = 3600;
    final changes = diffLevels(
      {'A': 900 * h, 'B': 0},
      {'A': 10000 * h, 'B': 1800},
    );
    final cards = celebrationsFor(changes);
    expect(cards.map((c) => (c.skillId, c.kind)).toList(), [
      ('A', CelebrationKind.milestone),
      ('A', CelebrationKind.hiddenTier),
      ('A', CelebrationKind.hiddenTier),
      ('A', CelebrationKind.hiddenTier),
      ('B', CelebrationKind.levelUp),
    ]);
    expect(cards[1].tier, HiddenTier.cinar);
    expect(cards[2].tier, HiddenTier.zumruduanka);
    expect(cards[3].tier, HiddenTier.efsane);
  });

  test('decrease yields no celebration', () {
    final changes = diffLevels({'A': 1800}, {'A': 0});
    expect(celebrationsFor(changes), isEmpty);
  });

  test('unchanged and new skills', () {
    expect(diffLevels({'A': 10}, {'A': 10}), isEmpty);
    final c = diffLevels({}, {'N': 1800});
    expect(c.single.fromLevel, 1);
    expect(c.single.toLevel, 3);
  });

  test('bonus flag', () {
    final changes = diffLevels(
      {'A': 0, 'B': 0},
      {'A': 1800, 'B': 1800},
      bonusOnlySkillIds: {'B'},
    );
    expect(changes.firstWhere((c) => c.skillId == 'A').viaBonus, isFalse);
    expect(changes.firstWhere((c) => c.skillId == 'B').viaBonus, isTrue);
    expect(celebrationsFor(changes).last.viaBonus, isTrue);
  });
}
