// Open the database, draw the first frame, then bring reminders up to date.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_database.dart';
import '../data/db/connection.dart';
import '../features/settings/controllers/settings_providers.dart';
import 'app.dart';
import 'di.dart';

Future<void> bootstrap() async {
  final db = AppDatabase(openConnection());
  // Drift opens lazily; create or migrate before the first frame.
  await db.customSelect('SELECT 1').get();
  final container = ProviderContainer(
    // No retries: a local database error will not fix itself.
    retry: (_, _) => null,
    overrides: [appDatabaseProvider.overrideWithValue(db)],
  );
  // Read the theme before the first frame, so it does not flash.
  container.listen(themeModeProvider, (_, _) {});
  await container.read(themeModeProvider.future);
  runApp(
    UncontrolledProviderScope(container: container, child: const PulseApp()),
  );
  void resync() => container.read(reminderSchedulerProvider).resyncAll();
  WidgetsBinding.instance.addPostFrameCallback((_) => resync());
  // Also covers a timezone change: it can only be made outside the app, and
  // due-date reminders are recomputed on return. Lives as long as the process.
  AppLifecycleListener(onResume: resync);
}
