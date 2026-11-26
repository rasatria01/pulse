// Open the database, draw the first frame, then bring recurring rules and
// reminders up to date.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../data/db/app_database.dart';
import '../data/db/connection.dart';
import '../features/settings/controllers/settings_providers.dart';
import '../ui/day_label.dart';
import 'app.dart';
import 'di.dart';
import 'restart.dart';

/// The app's start path. A restore runs it again on the replaced database, so
/// whatever a start does also happens after a restore.
Future<void> bootstrap({
  AppDatabase Function() open = _openDatabase,
  bool? restored,
  List<Override> overrides = const [], // for tests
}) async {
  await initializeDateFormatting(dateLocale);
  final db = open();
  // Drift opens lazily; create or migrate before the first frame.
  await db.customSelect('SELECT 1').get();
  late final ProviderContainer container;
  late final void Function() stopUpkeep;
  container = ProviderContainer(
    // No retries: a local database error will not fix itself.
    retry: (_, _) => null,
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      restoreResultProvider.overrideWithValue(restored),
      restoreRunnerProvider.overrideWithValue((path) async {
        final replaced = await restoreAndStop(
          container,
          db,
          path,
          // Everything this start made that would outlive its database.
          stop: () => stopUpkeep(),
        );
        await bootstrap(open: open, restored: replaced, overrides: overrides);
      }),
      ...overrides,
    ],
  );
  // Read the theme before the first frame, so it does not flash.
  container.listen(themeModeProvider, (_, _) {});
  try {
    await container.read(themeModeProvider.future);
  } catch (e) {
    // A bad settings row must not keep the app from starting.
    debugPrint('theme not read: ${e.runtimeType}');
  }
  runApp(
    // A new key: a restart must not keep any state of the scope before it.
    UncontrolledProviderScope(
      key: UniqueKey(),
      container: container,
      child: const MelaApp(),
    ),
  );
  // Lives until a restore.
  stopUpkeep = startUpkeep(container);
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

AppDatabase _openDatabase() => AppDatabase(openConnection());
