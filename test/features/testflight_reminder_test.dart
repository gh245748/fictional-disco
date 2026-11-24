import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mesk/app/providers.dart';
import 'package:mesk/domain/day.dart';
import 'package:mesk/features/settings/testflight_reminder.dart';

const _today = LocalDay(2026, 11, 24);

String _built(int daysAgo) => _today.addDays(-daysAgo).toIso();

Future<void> _pump(
  WidgetTester t, {
  required String buildDate,
  required bool ios,
}) async {
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        buildDateProvider.overrideWithValue(buildDate),
        isIosProvider.overrideWithValue(ios),
        todayProvider.overrideWith((ref) => Stream.value(_today)),
      ],
      child: const MaterialApp(home: Scaffold(body: TestflightReminder())),
    ),
  );
  await t.pump();
}

void main() {
  group('testflightDaysLeft', () {
    int? left(String build) =>
        testflightDaysLeft(buildDate: build, today: _today);

    test('no reminder before 80 days', () {
      expect(left(_built(0)), isNull);
      expect(left(_built(79)), isNull);
    });

    test('reminder shows days left at 80 and 85 days', () {
      expect(left(_built(80)), 10);
      expect(left(_built(85)), 5);
    });

    test('never goes below zero', () {
      expect(left(_built(120)), 0);
    });

    test('no define, no reminder', () {
      expect(left(''), isNull);
      expect(left('not-a-date'), isNull);
    });
  });

  group('TestflightReminder', () {
    const text =
        'Bu TestFlight sürümü 5 gün içinde sona erecek. '
        'Yeni bir sürüm yükle.';

    testWidgets('shows on iOS for an old build', (t) async {
      await _pump(t, buildDate: _built(85), ios: true);
      expect(find.text(text), findsOneWidget);
    });

    testWidgets('hidden off iOS', (t) async {
      await _pump(t, buildDate: _built(85), ios: false);
      expect(find.text(text), findsNothing);
    });

    testWidgets('hidden without a build date', (t) async {
      await _pump(t, buildDate: '', ios: true);
      expect(find.textContaining('TestFlight'), findsNothing);
    });
  });
}
