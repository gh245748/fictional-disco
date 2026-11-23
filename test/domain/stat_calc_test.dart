import 'package:flutter_test/flutter_test.dart';
import 'package:mesk/domain/stat_calc.dart';
import 'package:mesk/domain/stats.dart';

import '../support/mockup.dart';

void main() {
  test('mockup stats', () {
    final (skills, levels) = mockupSkillsAndLevels();
    final v = skillStatValues(skills, levels);
    expect(v[Stat.zihin], 113);
    expect(v[Stat.beden], 46);
    expect(v[Stat.yaraticilik], 38);
    expect(v[Stat.karizma], 16.5);
    expect(displayStatValue(v[Stat.karizma]!), 17);
    expect(v[Stat.denge], 25);
    expect(v.containsKey(Stat.irade), isFalse);
    expect(totalLevel(skills, levels), 220);
  });
  test('radar and irade', () {
    expect(radarScale([113, 46, 38, 17, 25, 42]), 125);
    expect(radarScale([0, 0]), 25);
    expect(radarRadius(113, 125), closeTo(0.9508, 1e-4));
    expect(radarRadius(500, 125), 1);
    expect(radarRadius(-1, 125), 0);
    expect(iradeFromPoints(336), 42);
    expect(iradeFromPoints(4), 1);
    expect(iradeFromPoints(3), 0);
    expect(iradeDivisor, 8);
  });
  test('contributions sum per stat', () {
    expect(
      sumContributions([
        {Stat.zihin: 10, Stat.karizma: 1.5},
        {Stat.irade: 42, Stat.zihin: 2},
      ]),
      {Stat.zihin: 12, Stat.karizma: 1.5, Stat.irade: 42},
    );
  });
}
