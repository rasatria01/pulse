// Open the database, draw the first frame, then bring recurring rules and
// reminders up to date.
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
  startUpkeep(container); // Lives as long as the process.
}

/// Brings recurring rules and reminders up to date: after the next frame, then
/// on every resume and when the day changes (PRD 9.3). Restore calls this again
/// for its new container; the returned function stops it.
void Function() startUpkeep(ProviderContainer container) {
  var stopped = false;
  Future<void> run() async {
    if (stopped) return;
    try {
      // From the clock: on resume todayProvider may not have refreshed yet.
      await container
          .read(recurringEngineProvider)
          .catchUp(container.read(clockProvider).today());
    } catch (e) {
      // The type only: messages may carry names.
      debugPrint('catch-up failed: ${e.runtimeType}');
    }
    // Also covers a timezone change: it can only be made outside the app, and
    // due-date reminders are recomputed on return.
    if (!stopped) await container.read(reminderSchedulerProvider).resyncAll();
  }

  WidgetsBinding.instance
    ..addPostFrameCallback((_) => run())
    ..ensureVisualUpdate();
  final lifecycle = AppLifecycleListener(onResume: run);
  final day = container.listen(todayProvider, (_, _) => run());
  return () {
    stopped = true;
    lifecycle.dispose();
    day.close();
  };
}
