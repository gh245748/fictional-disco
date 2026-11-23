import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'data/db.dart';
import 'data/log_pipeline.dart';
import 'data/presets_repo.dart';
import 'domain/day.dart';
import 'services/notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await initializeDateFormatting('tr');
  final documents = await getApplicationDocumentsDirectory();
  final db = await MeskDb.openFile(p.join(documents.path, 'mesk.db'));
  await PresetsRepo(db).seedBuiltIns();
  final clock = SystemClock();
  runApp(
    ProviderScope(
      overrides: [
        dbProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(clock),
        // The real notification service arrives in Task 19.
        notificationsProvider.overrideWithValue(
          FakeNotificationService(permissionGranted: true),
        ),
        pipelineProvider.overrideWithValue(LogPipeline(db, clock)),
      ],
      child: const MeskApp(),
    ),
  );
}
