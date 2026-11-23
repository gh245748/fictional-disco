import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'app/router.dart';
import 'data/db.dart';
import 'data/log_pipeline.dart';
import 'data/presets_repo.dart';
import 'domain/day.dart';
import 'services/local_notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await initializeDateFormatting('tr');
  final documents = await getApplicationDocumentsDirectory();
  final db = await MeskDb.openFile(p.join(documents.path, 'mesk.db'));
  await PresetsRepo(db).seedBuiltIns();
  final clock = SystemClock();
  // Tapping a notification opens Odak. The container exists only after the
  // service is built, hence the nullable reference (a tap before it exists is ignored).
  ProviderContainer? container;
  final notifications = await createLocalNotificationService(
    onOpenFocus: () => container?.read(routerProvider).go(focusRoute),
  );
  final ready = container = ProviderContainer(
    overrides: [
      dbProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(clock),
      notificationsProvider.overrideWithValue(notifications.service),
      pipelineProvider.overrideWithValue(LogPipeline(db, clock)),
    ],
  );
  runApp(UncontrolledProviderScope(container: ready, child: const MeskApp()));
  if (await notifications.launched()) {
    ready.read(routerProvider).go(focusRoute);
  }
}
