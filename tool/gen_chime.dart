// Generates the notification chime: 0.9 s, 44.1 kHz, 16-bit mono WAV of
// 880 Hz + 1320 Hz sines with an exponential decay, peaking at -12 dBFS.
//
// Run from the repository root: dart run tool/gen_chime.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const sampleRate = 44100;
const seconds = 0.9;
const peakDbfs = -12.0;

/// Time constant of the decay; amplitude falls to ~0.1 % by the end.
const decayTau = seconds / 6.9;

const outputs = [
  'assets/sounds/chime.wav',
  'android/app/src/main/res/raw/chime.wav',
  'ios/Runner/chime.wav',
];

Uint8List buildWav() {
  final n = (sampleRate * seconds).round();
  final raw = List<double>.generate(n, (i) {
    final t = i / sampleRate;
    final tone =
        math.sin(2 * math.pi * 880 * t) + math.sin(2 * math.pi * 1320 * t);
    return tone * math.exp(-t / decayTau);
  });
  final peak = raw.map((v) => v.abs()).reduce(math.max);
  final gain = math.pow(10, peakDbfs / 20) * 32767 / peak;

  final dataBytes = n * 2;
  final out = ByteData(44 + dataBytes);
  void tag(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      out.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  out.setUint32(4, 36 + dataBytes, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  out.setUint32(16, 16, Endian.little);
  out.setUint16(20, 1, Endian.little); // PCM
  out.setUint16(22, 1, Endian.little); // mono
  out.setUint32(24, sampleRate, Endian.little);
  out.setUint32(28, sampleRate * 2, Endian.little);
  out.setUint16(32, 2, Endian.little);
  out.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  out.setUint32(40, dataBytes, Endian.little);
  for (var i = 0; i < n; i++) {
    out.setInt16(44 + i * 2, (raw[i] * gain).round(), Endian.little);
  }
  return out.buffer.asUint8List();
}

void main() {
  final wav = buildWav();
  for (final path in outputs) {
    final file = File(path)..createSync(recursive: true);
    file.writeAsBytesSync(wav);
    stdout.writeln('wrote $path (${wav.length} bytes)');
  }
}
