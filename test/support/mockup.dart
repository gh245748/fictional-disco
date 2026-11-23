import 'package:mesk/domain/models.dart';
import 'package:mesk/domain/stats.dart';

/// The 13 skills of the approved mockup with their levels.
(List<Skill>, Map<String, int>) mockupSkillsAndLevels() {
  final created = DateTime.utc(2026, 1, 1);
  const rows = <(String, String, Stat, Stat?, int)>[
    ('ingilizce', 'İngilizce', Stat.zihin, Stat.karizma, 23),
    ('okuma', 'Okuma', Stat.zihin, null, 31),
    ('yazilim', 'Yazılım', Stat.zihin, null, 47),
    ('satranc', 'Satranç', Stat.zihin, null, 12),
    ('hitabet', 'Hitabet', Stat.karizma, null, 5),
    ('gitar', 'Gitar', Stat.yaraticilik, null, 18),
    ('cizim', 'Çizim', Stat.yaraticilik, null, 9),
    ('muzik-teorisi', 'Müzik teorisi', Stat.yaraticilik, null, 7),
    ('gunluk-yazma', 'Günlük yazma', Stat.denge, Stat.yaraticilik, 8),
    ('meditasyon', 'Meditasyon', Stat.denge, null, 11),
    ('yoga', 'Yoga', Stat.denge, Stat.beden, 6),
    ('fitness', 'Fitness', Stat.beden, null, 28),
    ('kosu', 'Koşu', Stat.beden, null, 15),
  ];
  return (
    [
      for (final r in rows)
        Skill(
          id: r.$1,
          name: r.$2,
          primary: r.$3,
          secondary: r.$4,
          createdAt: created,
        ),
    ],
    {for (final r in rows) r.$1: r.$5},
  );
}

/// The 14 links of the approved mockup graph (skill id pairs).
const List<(String, String)> mockupLinks = [
  ('ingilizce', 'hitabet'),
  ('okuma', 'hitabet'),
  ('ingilizce', 'okuma'),
  ('ingilizce', 'yazilim'),
  ('okuma', 'yazilim'),
  ('yazilim', 'satranc'),
  ('okuma', 'gunluk-yazma'),
  ('gitar', 'muzik-teorisi'),
  ('cizim', 'gunluk-yazma'),
  ('gunluk-yazma', 'meditasyon'),
  ('meditasyon', 'yoga'),
  ('yoga', 'fitness'),
  ('fitness', 'kosu'),
  ('kosu', 'meditasyon'),
];
