import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/app/app.dart';
import 'package:pulse/app/di.dart';
import 'package:pulse/data/db/app_database.dart';
import 'package:shad/shad.dart';

import '../data/support.dart';

/// The whole app on a fresh in-memory database, fixed at 2026-11-25 10:00.
Future<AppDatabase> pumpApp(
  WidgetTester tester, {
  ShadThemeMode mode = ShadThemeMode.light,
}) async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final db = AppDatabase(
    // Closing streams at once leaves no timer behind when the test ends.
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
    clock: const FixedClock(),
  );
  addTearDown(db.close);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(const FixedClock()),
      ],
      child: MelaApp(themeMode: mode),
    ),
  );
  await tester.pumpAndSettle();
  return db;
}
