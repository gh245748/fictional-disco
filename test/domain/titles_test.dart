import 'package:flutter_test/flutter_test.dart';
import 'package:mesk/domain/level_curve.dart';
import 'package:mesk/domain/stats.dart';
import 'package:mesk/domain/titles.dart';

void main() {
  test('99 unique titles, verbatim milestones', () {
    expect(levelTitles.length, 99);
    expect(levelTitles.toSet().length, 99);
    expect(titleForLevel(1), 'Meraklı');
    expect(titleForLevel(10), 'Çırak');
    expect(titleForLevel(23), 'Marifetli');
    expect(titleForLevel(25), 'Kalfa');
    expect(titleForLevel(47), 'Rehber');
    expect(titleForLevel(50), 'Usta');
    expect(titleForLevel(75), 'Üstat');
    expect(titleForLevel(95), 'Mihenk Taşı');
    expect(titleForLevel(99), 'Pir');
    for (final t in HiddenTier.values) {
      expect(levelTitles.contains(hiddenTierName(t)), isFalse);
    }
    expect(HiddenTier.values.map(hiddenTierName), [
      'Çınar',
      'Zümrüdüanka',
      'Efsane',
    ]);
  });

  test('bands', () {
    expect(bandForLevel(9), Band.uyanis);
    expect(bandForLevel(10), Band.ciraklik);
    expect(bandForLevel(24), Band.ciraklik);
    expect(bandForLevel(25), Band.kalfalik);
    expect(bandForLevel(49), Band.kalfalik);
    expect(bandForLevel(50), Band.ustalik);
    expect(bandForLevel(74), Band.ustalik);
    expect(bandForLevel(75), Band.ustatlik);
    expect(bandForLevel(98), Band.ustatlik);
    expect(bandForLevel(99), Band.pir);
    expect(Band.values.map((b) => b.label), [
      'Uyanış',
      'Çıraklık',
      'Kalfalık',
      'Ustalık',
      'Üstatlık',
      'Pir',
    ]);
  });

  test('descriptions exist', () {
    expect(levelDescriptions.length, 99);
    expect(levelDescriptions.every((d) => d.trim().endsWith('.')), isTrue);
    expect(levelDescriptions.toSet().length, 99);
    for (final t in HiddenTier.values) {
      expect(hiddenTierDescription(t), isNotEmpty);
    }
  });

  test('hidden tier names never appear in level titles or descriptions', () {
    String lower(String s) =>
        s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
    final banned = HiddenTier.values.map((t) => lower(hiddenTierName(t)));
    for (final text in [...levelTitles, ...levelDescriptions]) {
      for (final name in banned) {
        expect(lower(text).contains(name), isFalse, reason: text);
      }
    }
  });

  test('milestones and stats', () {
    expect(milestoneLevels, {10, 25, 50, 75, 99});
    expect(skillStats.length, 5);
    expect(skillStats.contains(Stat.irade), isFalse);
    expect(radarOrder.length, 6);
    expect(Stat.values.map((s) => s.label), [
      'Zihin',
      'Beden',
      'Yaratıcılık',
      'Karizma',
      'Denge',
      'İrade',
    ]);
  });
}
