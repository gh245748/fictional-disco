import 'dart:math' as math;

import 'models.dart';
import 'stats.dart';

/// Habit/goal points needed per point of İrade.
const int iradeDivisor = 8;

/// Points divided by [iradeDivisor], rounded half up.
int iradeFromPoints(int points) => (points + iradeDivisor ~/ 2) ~/ iradeDivisor;

/// Stat contributions of skills: the primary stat gets the full level, the
/// secondary stat half. Archived skills count. Has no [Stat.irade] key.
Map<Stat, double> skillStatValues(
  Iterable<Skill> skills,
  Map<String, int> levelBySkillId,
) {
  final out = <Stat, double>{for (final s in skillStats) s: 0};
  for (final skill in skills) {
    final level = levelBySkillId[skill.id] ?? 0;
    out[skill.primary] = out[skill.primary]! + level;
    final secondary = skill.secondary;
    if (secondary != null) out[secondary] = out[secondary]! + level / 2;
  }
  return out;
}

int totalLevel(Iterable<Skill> skills, Map<String, int> levelBySkillId) =>
    skills.fold(0, (sum, s) => sum + (levelBySkillId[s.id] ?? 0));

/// Extension point (§5.15): a character's stats are the sum of the
/// contribution maps of every source (skills, habits, later finance, health).
Map<Stat, double> sumContributions(Iterable<Map<Stat, double>> parts) {
  final out = <Stat, double>{};
  for (final part in parts) {
    part.forEach((stat, v) => out[stat] = (out[stat] ?? 0) + v);
  }
  return out;
}

/// Rounds half up.
int displayStatValue(double v) => (v + 0.5).floor();

double radarScale(Iterable<double> values) {
  final max = values.fold<double>(0, math.max);
  return math.max(25, (max / 25).ceil() * 25).toDouble();
}

double radarRadius(double value, double scale) =>
    value <= 0 ? 0 : math.sqrt(value / scale).clamp(0.0, 1.0);
