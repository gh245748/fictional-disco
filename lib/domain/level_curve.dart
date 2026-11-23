/// Highest regular level.
const int maxLevel = 99;

/// XP (seconds) needed to reach each level; index 0 is level 1.
/// Equals round(3600 * 1000 * (0.02 * x + 0.98 * x^2.5)), x = (level - 1) / 98
/// (asserted by a test).
const List<int> _thresholds = [
  0,
  772,
  1679,
  2783,
  4126,
  5748,
  7680,
  9954,
  12595,
  15629,
  19081,
  22973,
  27327,
  32162,
  37499,
  43357,
  49753,
  56706,
  64233,
  72350,
  81074,
  90420,
  100404,
  111040,
  122343,
  134329,
  147010,
  160400,
  174514,
  189364,
  204963,
  221324,
  238461,
  256384,
  275107,
  294641,
  314998,
  336190,
  358229,
  381125,
  404891,
  429536,
  455073,
  481511,
  508862,
  537136,
  566343,
  596494,
  627599,
  659668,
  692711,
  726739,
  761759,
  797784,
  834821,
  872881,
  911973,
  952106,
  993290,
  1035534,
  1078846,
  1123236,
  1168714,
  1215286,
  1262964,
  1311754,
  1361667,
  1412710,
  1464892,
  1518221,
  1572706,
  1628356,
  1685178,
  1743181,
  1802372,
  1862761,
  1924355,
  1987162,
  2051190,
  2116447,
  2182941,
  2250680,
  2319670,
  2389921,
  2461440,
  2534234,
  2608311,
  2683678,
  2760344,
  2838315,
  2917598,
  2998202,
  3080133,
  3163399,
  3248006,
  3333963,
  3421276,
  3509953,
  3600000,
];

/// Total XP seconds needed to reach [level] (1..99).
int thresholdSeconds(int level) {
  assert(level >= 1 && level <= maxLevel);
  return _thresholds[level - 1];
}

/// The level for [xpSeconds] of experience, clamped to 1..99.
int levelForXp(int xpSeconds) {
  if (xpSeconds <= 0) return 1;
  var lo = 0;
  var hi = maxLevel - 1;
  while (lo < hi) {
    final mid = (lo + hi + 1) ~/ 2;
    if (_thresholds[mid] <= xpSeconds) {
      lo = mid;
    } else {
      hi = mid - 1;
    }
  }
  return lo + 1;
}

/// Fraction (0..1) of the way from the current level to the next.
double levelProgress(int xpSeconds) {
  final level = levelForXp(xpSeconds);
  if (level >= maxLevel) return 1.0;
  final start = thresholdSeconds(level);
  final end = thresholdSeconds(level + 1);
  return (xpSeconds - start) / (end - start);
}

/// Seconds remaining until the next level; 0 at level 99.
int secondsToNextLevel(int xpSeconds) {
  final level = levelForXp(xpSeconds);
  if (level >= maxLevel) return 0;
  return thresholdSeconds(level + 1) - xpSeconds;
}

/// Hidden tiers beyond level 99.
enum HiddenTier { cinar, zumruduanka, efsane }

int hiddenTierThresholdSeconds(HiddenTier t) => switch (t) {
  HiddenTier.cinar => 2500 * 3600,
  HiddenTier.zumruduanka => 5000 * 3600,
  HiddenTier.efsane => 10000 * 3600,
};

/// The highest hidden tier reached, or null.
HiddenTier? hiddenTierForXp(int xp) {
  HiddenTier? result;
  for (final t in HiddenTier.values) {
    if (xp >= hiddenTierThresholdSeconds(t)) result = t;
  }
  return result;
}

/// The next hidden tier to aim for. Only hinted once level 99 is reached.
HiddenTier? nextHiddenTier(int xp) {
  if (xp < thresholdSeconds(maxLevel)) return null;
  for (final t in HiddenTier.values) {
    if (xp < hiddenTierThresholdSeconds(t)) return t;
  }
  return null;
}

/// Progress (0..1) toward the next hidden tier, measured from the previous
/// threshold (level 99 for Çınar); 1.0 after Efsane.
double hiddenTierProgress(int xp) {
  final next = nextHiddenTier(xp);
  if (next == null) {
    return xp >= hiddenTierThresholdSeconds(HiddenTier.efsane) ? 1.0 : 0.0;
  }
  final start = next.index == 0
      ? thresholdSeconds(maxLevel)
      : hiddenTierThresholdSeconds(HiddenTier.values[next.index - 1]);
  final end = hiddenTierThresholdSeconds(next);
  return (xp - start) / (end - start);
}
