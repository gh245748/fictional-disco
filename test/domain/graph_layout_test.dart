import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mesk/domain/graph_layout.dart';

import '../support/mockup.dart';

double _dist((double, double) a, (double, double) b) =>
    math.sqrt(math.pow(a.$1 - b.$1, 2) + math.pow(a.$2 - b.$2, 2));

GraphLayout _mockupLayout({int seed = 7}) {
  final (skills, levels) = mockupSkillsAndLevels();
  return GraphLayout(
    radii: {for (final s in skills) s.id: nodeDiameter(levels[s.id]!) / 2},
    edges: mockupLinks,
    seed: seed,
  );
}

void main() {
  test('nodeDiameter', () {
    expect(nodeDiameter(47), closeTo(34.05, 0.01));
    expect(nodeDiameter(5), closeTo(16.50, 0.01));
  });

  test('deterministic', () {
    final a = _mockupLayout()..settle();
    final b = _mockupLayout()..settle();
    expect(a.positions, b.positions);
    final c = _mockupLayout(seed: 99)..settle();
    expect(c.positions, isNot(a.positions));
  });

  test('linked closer than unlinked', () {
    final layout = _mockupLayout()..settle();
    final p = layout.positions;
    final linked = {
      for (final (a, b) in mockupLinks) '$a|$b',
      for (final (a, b) in mockupLinks) '$b|$a',
    };
    final ids = p.keys.toList();
    var edgeSum = 0.0, edgeN = 0, otherSum = 0.0, otherN = 0;
    for (var i = 0; i < ids.length; i++) {
      for (var j = i + 1; j < ids.length; j++) {
        final d = _dist(p[ids[i]]!, p[ids[j]]!);
        if (linked.contains('${ids[i]}|${ids[j]}')) {
          edgeSum += d;
          edgeN++;
        } else {
          otherSum += d;
          otherN++;
        }
      }
    }
    expect(edgeN, 14);
    expect(edgeSum / edgeN, lessThan(otherSum / otherN));
  });

  test('no overlap', () {
    final (skills, levels) = mockupSkillsAndLevels();
    final radii = {
      for (final s in skills) s.id: nodeDiameter(levels[s.id]!) / 2,
    };
    final layout = GraphLayout(radii: radii, edges: mockupLinks)..settle();
    final p = layout.positions;
    final ids = p.keys.toList();
    for (var i = 0; i < ids.length; i++) {
      for (var j = i + 1; j < ids.length; j++) {
        expect(
          _dist(p[ids[i]]!, p[ids[j]]!),
          greaterThanOrEqualTo(radii[ids[i]]! + radii[ids[j]]! + 8),
        );
      }
    }
  });

  test('pinned node stays', () {
    final layout = _mockupLayout();
    layout.pin('okuma', 500, -300);
    layout.settle();
    expect(layout.positions['okuma'], (500.0, -300.0));
    layout.unpin('okuma');
    layout.settle();
    expect(layout.positions['okuma'], isNot((500.0, -300.0)));
  });

  test('settles', () {
    final rng = math.Random(3);
    final radii = {for (var i = 0; i < 30; i++) 'n$i': 6.0 + rng.nextInt(12)};
    final edges = <(String, String)>[
      for (var i = 1; i < 30; i++) ('n${rng.nextInt(i)}', 'n$i'),
    ];
    final layout = GraphLayout(radii: radii, edges: edges);
    expect(layout.settled, isFalse);
    layout.settle(maxSteps: 600);
    expect(layout.settled, isTrue);
  });

  test('placeNear', () {
    final rng = math.Random(1);
    const neighbors = [(100.0, 50.0), (140.0, 90.0), (60.0, 20.0)];
    const cx = 100.0, cy = 160.0 / 3;
    for (var i = 0; i < 50; i++) {
      final p = GraphLayout.placeNear(neighbors, rng);
      expect(_dist(p, (cx, cy)), lessThanOrEqualTo(120));
    }
  });

  test('pin reheats so neighbours respond after cooling', () {
    final layout = _mockupLayout()..settle();
    final before = layout.positions['yazilim']!;
    layout.pin('ingilizce', 600, 600);
    for (var i = 0; i < 20; i++) {
      layout.step();
    }
    expect(_dist(layout.positions['yazilim']!, before), greaterThan(1));
  });

  test('step stays fast for ~150 nodes', () {
    final rng = math.Random(11);
    final radii = {for (var i = 0; i < 150; i++) 'n$i': 6.0 + rng.nextInt(12)};
    final edges = <(String, String)>[
      for (var i = 0; i < 200; i++)
        ('n${rng.nextInt(150)}', 'n${rng.nextInt(150)}'),
    ];
    final layout = GraphLayout(radii: radii, edges: edges);
    for (var i = 0; i < 5; i++) {
      layout.step();
    }
    final sw = Stopwatch()..start();
    for (var i = 0; i < 50; i++) {
      layout.step();
    }
    sw.stop();
    final avgMs = sw.elapsedMicroseconds / 1000 / 50;
    // ignore: avoid_print
    print('avg step: ${avgMs.toStringAsFixed(3)} ms');
    expect(avgMs, lessThan(4));
  });
}
