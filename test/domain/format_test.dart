import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mesk/domain/format.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr'));

  test('turkish casing', () {
    expect(trUpper('21 kasım · cumartesi'), '21 KASIM · CUMARTESİ');
    expect(trUpper('ılık'), 'ILIK');
    expect(trLower('İSTANBUL'), 'istanbul');
    expect(trLower('IŞIK'), 'ışık');
  });

  test('turkish sorting', () {
    final names = [
      'Zihin',
      'Çizim',
      'Cesaret',
      'İngilizce',
      'Işık',
      'Okuma',
      'Ödev',
    ]..sort(trCompare);
    expect(names, [
      'Cesaret',
      'Çizim',
      'Işık',
      'İngilizce',
      'Okuma',
      'Ödev',
      'Zihin',
    ]);
  });

  test('trCompare falls back to code-unit order outside the alphabet', () {
    expect(trCompare('Kitap okuma', 'Kitaplık'), lessThan(0));
    expect(trCompare('1abc', 'zzz'), lessThan(0));
  });

  test('trCompare is a total order (non-alphabet before letters)', () {
    expect(['z', 'é', 'ö']..sort(trCompare), ['é', 'ö', 'z']);
    expect(['ö', 'z', 'é']..sort(trCompare), ['é', 'ö', 'z']);
  });

  test('trCompare places q, w and x inside the alphabet', () {
    expect(
      [
        'Zihin',
        'Web tasarımı',
        'Akıl',
        'Wushu',
        'Xilofon',
        'Quiz',
        'Vatan',
        'Yol',
      ]..sort(trCompare),
      [
        'Akıl',
        'Quiz',
        'Vatan',
        'Web tasarımı',
        'Wushu',
        'Xilofon',
        'Yol',
        'Zihin',
      ],
    );
    expect(trCompare('p', 'q'), lessThan(0));
    expect(trCompare('q', 'r'), lessThan(0));
    expect(trCompare('v', 'w'), lessThan(0));
    expect(trCompare('x', 'y'), lessThan(0));
    expect(trCompare('w', 'x'), lessThan(0));
  });

  test('durations and hours', () {
    expect(formatDuration(59), '0 dk');
    expect(formatDuration(60), '1 dk');
    expect(formatDuration(4500), '1 sa 15 dk');
    expect(formatDuration(7200), '2 sa');
    expect(formatHours(105840), '29,4 sa');
    expect(formatHours(36000), '10 sa');
    expect(formatHours(1800), '0,5 sa');
    expect(formatHours(579600), '161 sa');
    expect(formatHours(1240 * 3600), '1.240 sa');
    expect(formatPercent(0.271), '%27');
    expect(formatPercent(1.0), '%100');
  });

  test('dates', () {
    expect(formatDayMonth(DateTime(2026, 11, 21)), '21 Kasım');
    expect(formatWeekday(DateTime(2026, 11, 21)), 'Cumartesi');
    expect(formatDate(DateTime(2026, 11, 21)), '21 Kasım 2026');
  });
}
