import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mesk/domain/level_curve.dart';

void main() {
  test('thresholds match spec Ek A', () {
    expect(thresholdSeconds(1), 0);
    expect(thresholdSeconds(2), 772);
    expect(thresholdSeconds(10), 15629);
    expect(thresholdSeconds(25), 122343);
    expect(thresholdSeconds(50), 659668);
    expect(thresholdSeconds(75), 1802372);
    expect(thresholdSeconds(99), 3600000);
  });

  test('precomputed table equals the formula', () {
    for (var level = 1; level <= maxLevel; level++) {
      final x = (level - 1) / 98;
      final expected = (3600 * 1000 * (0.02 * x + 0.98 * math.pow(x, 2.5)))
          .round();
      expect(thresholdSeconds(level), expected, reason: 'level $level');
    }
  });

  test('levelForXp matches spec check values', () {
    const h = 3600;
    expect(levelForXp(0), 1);
    expect(levelForXp(771), 1);
    expect(levelForXp(772), 2);
    expect(levelForXp(25 * 60), 2);
    expect(levelForXp(1 * h), 4);
    expect(levelForXp(10 * h), 14);
    expect(levelForXp(30 * h), 23);
    expect(levelForXp(100 * h), 39);
    expect(levelForXp(250 * h), 56);
    expect(levelForXp(500 * h), 74);
    expect(levelForXp(730 * h), 87);
    expect(levelForXp(1000 * h), 99);
    expect(levelForXp(4000 * h), 99);
  });

  test('progress and remaining', () {
    expect(levelProgress(772), 0.0);
    expect(secondsToNextLevel(0), 772);
    expect(secondsToNextLevel(3600000), 0);
    expect(levelProgress(3600000), 1.0);
  });

  test('hidden tiers', () {
    expect(hiddenTierForXp(2499 * 3600), isNull);
    expect(hiddenTierForXp(2500 * 3600), HiddenTier.cinar);
    expect(hiddenTierForXp(5000 * 3600), HiddenTier.zumruduanka);
    expect(hiddenTierForXp(10000 * 3600), HiddenTier.efsane);
    expect(nextHiddenTier(3599999), isNull); // below level 99: not hinted
    expect(nextHiddenTier(3600000), HiddenTier.cinar);
    expect(hiddenTierProgress(1750 * 3600), closeTo(0.5, 1e-9));
    expect(nextHiddenTier(10000 * 3600), isNull);
  });
}
