import '../../domain/stats.dart';

/// A ready-made skill offered on first launch (spec Ek C).
class SkillTemplate {
  const SkillTemplate(this.name, this.primary, [this.secondary]);

  final String name;
  final Stat primary;
  final Stat? secondary;
}

const List<SkillTemplate> skillTemplates = [
  SkillTemplate('İngilizce', Stat.zihin, Stat.karizma),
  SkillTemplate('Okuma', Stat.zihin),
  SkillTemplate('Yazılım', Stat.zihin),
  SkillTemplate('Matematik', Stat.zihin),
  SkillTemplate('Satranç', Stat.zihin),
  SkillTemplate('Gitar', Stat.yaraticilik),
  SkillTemplate('Çizim', Stat.yaraticilik),
  SkillTemplate('Yazarlık', Stat.yaraticilik, Stat.zihin),
  SkillTemplate('Fitness', Stat.beden),
  SkillTemplate('Koşu', Stat.beden, Stat.denge),
  SkillTemplate('Yoga', Stat.denge, Stat.beden),
  SkillTemplate('Meditasyon', Stat.denge),
  SkillTemplate('Günlük yazma', Stat.denge, Stat.yaraticilik),
  SkillTemplate('Hitabet', Stat.karizma),
];

/// Suggested links, by skill name. A link is created only when both ends
/// are selected.
const List<(String, String)> templateLinks = [
  ('İngilizce', 'Okuma'),
  ('İngilizce', 'Hitabet'),
  ('Okuma', 'Yazarlık'),
  ('Okuma', 'Hitabet'),
  ('Yazılım', 'Matematik'),
  ('Matematik', 'Satranç'),
  ('Fitness', 'Koşu'),
  ('Yoga', 'Fitness'),
  ('Yoga', 'Meditasyon'),
  ('Günlük yazma', 'Meditasyon'),
  ('Günlük yazma', 'Yazarlık'),
];
