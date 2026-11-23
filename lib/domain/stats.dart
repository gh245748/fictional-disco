/// The six character stats. The first five are assignable to skills;
/// [Stat.irade] is derived from habits and goals only.
enum Stat { zihin, beden, yaraticilik, karizma, denge, irade }

extension StatLabel on Stat {
  String get label => switch (this) {
    Stat.zihin => 'Zihin',
    Stat.beden => 'Beden',
    Stat.yaraticilik => 'Yaratıcılık',
    Stat.karizma => 'Karizma',
    Stat.denge => 'Denge',
    Stat.irade => 'İrade',
  };
}

/// Stats a skill can be tagged with (everything except İrade).
const List<Stat> skillStats = [
  Stat.zihin,
  Stat.beden,
  Stat.yaraticilik,
  Stat.karizma,
  Stat.denge,
];

/// Clockwise order of the stat radar.
const List<Stat> radarOrder = [
  Stat.zihin,
  Stat.yaraticilik,
  Stat.karizma,
  Stat.irade,
  Stat.denge,
  Stat.beden,
];
