import 'package:flutter_test/flutter_test.dart';
import 'package:mesk/domain/models.dart';
import 'package:mesk/domain/xp.dart';

TimeEntry entry({
  String id = 'e',
  required String skill,
  required int seconds,
  required EntrySource source,
}) => TimeEntry(
  id: id,
  skillId: skill,
  startedAt: DateTime.utc(2026, 1, 1),
  endedAt: DateTime.utc(2026, 1, 1).add(Duration(seconds: seconds)),
  offsetMinutes: 0,
  seconds: seconds,
  source: source,
  pomodoros: 0,
);

String Function() idGen() {
  var n = 0;
  return () => 'id${n++}';
}

void main() {
  test('bonus: 10% to each direct link, not split, no chaining', () {
    final e = entry(
      id: 'e1',
      skill: 'A',
      seconds: 3600,
      source: EntrySource.manual,
    );
    final aw = awardsForEntry(e, {'B', 'C'}, 1000, idGen());
    expect(aw.map((a) => (a.skillId, a.seconds, a.rateBp, a.entryId)).toSet(), {
      ('B', 360, 1000, 'e1'),
      ('C', 360, 1000, 'e1'),
    });
    expect(
      awardsForEntry(
        e.copyWith(source: EntrySource.prior),
        {'B'},
        1000,
        idGen(),
      ),
      isEmpty,
    );
    expect(awardsForEntry(e, {'B'}, 0, idGen()), isEmpty);
  });
  test('rescale keeps recorded rate', () {
    final aw = [
      const XpAward(
        id: 'x',
        entryId: 'e1',
        skillId: 'B',
        seconds: 360,
        rateBp: 1000,
      ),
    ];
    expect(rescaleAwards(aw, 1800).single.seconds, 180);
    expect(rescaleAwards(aw, 1800).single.rateBp, 1000);
  });
  test('totals', () {
    final t = computeTotals(
      [
        entry(skill: 'A', seconds: 3600, source: EntrySource.manual),
        entry(skill: 'A', seconds: 1800, source: EntrySource.prior),
      ],
      [
        const XpAward(
          id: 'x',
          entryId: 'z',
          skillId: 'A',
          seconds: 600,
          rateBp: 1000,
        ),
      ],
    )['A']!;
    expect(
      (
        t.realSeconds,
        t.priorSeconds,
        t.bonusSeconds,
        t.xpSeconds,
        t.trackedSeconds,
      ),
      (5400, 1800, 600, 6000, 3600),
    );
    expect(SkillTotals.zero.xpSeconds, 0);
  });
  test('linkedSkillIds returns direct neighbours only', () {
    final d = DateTime.utc(2026);
    final links = [
      SkillLink(id: '1', a: 'A', b: 'B', createdAt: d),
      SkillLink(id: '2', a: 'B', b: 'C', createdAt: d),
      SkillLink(id: '3', a: 'A', b: 'D', createdAt: d),
    ];
    expect(linkedSkillIds('A', links), {'B', 'D'});
    expect(linkedSkillIds('C', links), {'B'});
    expect(linkedSkillIds('Z', links), isEmpty);
  });
}
