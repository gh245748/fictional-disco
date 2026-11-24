// Renders assets/icon/icon.png. Run explicitly (it is outside test/):
//   flutter test tool/icon/icon_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = 1024.0;
const _ground = Color(0xFF0E0D0C);
const _gold = Color(0xFFC9A86A);

void _paint(Canvas canvas) {
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, _size, _size),
    Paint()..color = _ground,
  );
  // Soft warm glow behind the nodes.
  canvas.drawCircle(
    const Offset(_size / 2, _size / 2),
    380,
    Paint()
      ..shader = ui.Gradient.radial(
        const Offset(_size / 2, _size / 2),
        380,
        [_gold.withValues(alpha: 0.16), _gold.withValues(alpha: 0)],
      ),
  );
  // Three linked nodes (the "Ağ" glyph), kept inside the adaptive safe zone.
  const a = Offset(352, 392);
  const b = Offset(672, 360);
  const c = Offset(512, 672);
  final line = Paint()
    ..color = _gold.withValues(alpha: 0.7)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 14
    ..strokeCap = StrokeCap.round;
  canvas
    ..drawLine(a, b, line)
    ..drawLine(a, c, line)
    ..drawLine(b, c, line);
  final fill = Paint()..color = _gold;
  final ring = Paint()
    ..color = _gold.withValues(alpha: 0.35)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 8;
  for (final (center, r) in [(a, 54.0), (b, 54.0), (c, 66.0)]) {
    canvas
      ..drawCircle(center, r + 26, ring)
      ..drawCircle(center, r, fill);
  }
}

void main() {
  test('renders assets/icon/icon.png', () async {
    final recorder = ui.PictureRecorder();
    _paint(Canvas(recorder));
    final image = await recorder.endRecording().toImage(
      _size.toInt(),
      _size.toInt(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File('assets/icon/icon.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}
