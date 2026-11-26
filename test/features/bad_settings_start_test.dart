import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/app/app.dart';
import 'package:pulse/app/bootstrap.dart';
import 'package:pulse/app/di.dart';
import 'package:pulse/core/local_date.dart';
import 'package:pulse/data/db/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

import '../data/support.dart';

class _IdleEngine implements RecurringEngine {
  @override
  Future<CatchUpReport> catchUp(LocalDate today) async => const CatchUpReport();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('a settings row that cannot be read does not stop the start', (
    tester,
  ) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final dir = Directory.systemTemp.createTempSync('pulse-start');
    final file = File('${dir.path}/pulse.sqlite');
    late AppDatabase db;
    AppDatabase open() => db = AppDatabase(
      DatabaseConnection(NativeDatabase(file), closeStreamsSynchronously: true),
      clock: const FixedClock(),
    );

    await tester.runAsync(() async {
      await open().customSelect('SELECT 1').get();
      await db.close();
      // A theme that is not UTF-8, as a damaged file would hold it.
      sqlite3.open(file.path)
        ..execute(
          'INSERT INTO app_settings (key, value, updated_at) '
          "VALUES ('theme', CAST(x'ff' AS TEXT), 0)",
        )
        ..close();
      await bootstrap(
        open: open,
        overrides: [
          clockProvider.overrideWithValue(const FixedClock()),
          recurringEngineProvider.overrideWithValue(_IdleEngine()),
        ],
      ).timeout(const Duration(seconds: 20));
    });
    await tester.pump();

    expect(find.byType(PulseApp), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PulseApp)),
      listen: false,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.runAsync(() async {
      await db.close();
      dir.deleteSync(recursive: true);
    });
  });
}
