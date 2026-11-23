import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mesk/app/app.dart';
import 'package:mesk/app/router.dart';
import 'package:mesk/data/db.dart';
import 'package:mesk/data/log_pipeline.dart';
import 'package:mesk/domain/day.dart';
import 'package:mesk/services/notifications.dart';

import 'demo_data.dart';
import 'golden.dart';

/// An in-memory database prepared by [seed] (the demo data by default),
/// closed when the test ends.
Future<MeskDb> openTestDb(
  WidgetTester t, {
  Future<void> Function(MeskDb db) seed = seedDemo,
}) async {
  final db = (await t.runAsync(() async {
    final db = await MeskDb.openMemory();
    await seed(db);
    return db;
  }))!;
  addTearDown(() => t.runAsync(db.close));
  return db;
}

/// Pumps the whole app on a phone and navigates to [location].
Future<void> pumpMeskApp(
  WidgetTester t,
  MeskDb db,
  String location, {
  Clock? clock,
  NotificationService? notifications,
  LogPipeline? pipeline,
  List<Override> overrides = const [],
}) async {
  setPhoneView(t);
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        ...appOverrides(
          db,
          clock ?? demoClock(),
          notifications: notifications,
          pipeline: pipeline,
        ),
        ...overrides,
      ],
      child: const MeskApp(),
    ),
  );
  await t.pumpAndSettle();
  t.container().read(routerProvider).go(location);
  await t.pumpAndSettle();
}

/// Pushes [location] on top of the current page.
Future<void> pushRoute(WidgetTester t, String location) async {
  t.container().read(routerProvider).push(location);
  await t.pumpAndSettle();
}

String currentLocation(WidgetTester t) =>
    t.container().read(routerProvider).state.uri.toString();

/// Scrolls [f] into view if needed, taps it and settles.
Future<void> tapVisible(WidgetTester t, Finder f) async {
  if (f.evaluate().isEmpty) {
    await t.scrollUntilVisible(
      f,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await t.ensureVisible(f);
  await t.tap(f, warnIfMissed: false);
  await t.pumpAndSettle();
}
