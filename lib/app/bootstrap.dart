// Open the database, draw the first frame, then bring reminders up to date.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import '../data/db/app_database.dart';
import '../data/db/connection.dart';
import '../features/settings/controllers/settings_providers.dart';
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
  final db = open();
  // Drift opens lazily; create or migrate before the first frame.
  await db.customSelect('SELECT 1').get();
  late final ProviderContainer container;
  late final AppLifecycleListener lifecycle;
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
          stop: () => lifecycle.dispose(),
        );
        await bootstrap(open: open, restored: replaced, overrides: overrides);
      }),
      ...overrides,
    ],
  );
  // Read the theme before the first frame, so it does not flash.
  container.listen(themeModeProvider, (_, _) {});
  await container.read(themeModeProvider.future);
  runApp(
    // A new key: a restart must not keep any state of the scope before it.
    UncontrolledProviderScope(
      key: UniqueKey(),
      container: container,
      child: const PulseApp(),
    ),
  );
  void resync() => container.read(reminderSchedulerProvider).resyncAll();
  WidgetsBinding.instance.addPostFrameCallback((_) => resync());
  // Also covers a timezone change: it can only be made outside the app, and
  // due-date reminders are recomputed on return. Lives until a restore.
  lifecycle = AppLifecycleListener(onResume: resync);
}

AppDatabase _openDatabase() => AppDatabase(openConnection());
