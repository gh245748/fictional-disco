import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mesk/app/providers.dart';
import 'package:mesk/data/db.dart';
import 'package:mesk/data/log_pipeline.dart';
import 'package:mesk/domain/day.dart';
import 'package:mesk/services/notifications.dart';
import 'package:mesk/ui/theme.dart';

const _goldenKey = ValueKey('golden-root');

/// The base providers wired to [db] and [clock], as `main` does it.
List<Override> appOverrides(
  MeskDb db,
  Clock clock, {
  NotificationService? notifications,
  LogPipeline? pipeline,
}) => [
  dbProvider.overrideWithValue(db),
  clockProvider.overrideWithValue(clock),
  notificationsProvider.overrideWithValue(
    notifications ?? FakeNotificationService(permissionGranted: true),
  ),
  pipelineProvider.overrideWithValue(pipeline ?? LogPipeline(db, clock)),
];

/// Sets a 390x844 logical phone at DPR 2 for the rest of the test.
void setPhoneView(WidgetTester t) {
  t.view
    ..physicalSize = const Size(780, 1688)
    ..devicePixelRatio = 2;
  addTearDown(t.view.reset);
}

/// Pumps [child] as the home of a themed Turkish [MaterialApp] on a phone.
Future<void> pumpPhone(
  WidgetTester t,
  Widget child, {
  List<Override> overrides = const [],
}) async {
  setPhoneView(t);
  await t.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: RepaintBoundary(
        key: _goldenKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildMeskTheme(),
          locale: const Locale('tr', 'TR'),
          supportedLocales: const [Locale('tr', 'TR')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: child,
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

/// Compares the pumped phone with `goldens/<name>.png` next to the test.
Future<void> expectGolden(WidgetTester t, String name) =>
    expectLater(find.byKey(_goldenKey), matchesGoldenFile('goldens/$name.png'));
