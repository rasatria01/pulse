import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/app/app.dart';
import 'package:pulse/app/bootstrap.dart';
import 'package:pulse/app/di.dart';
import 'package:pulse/data/db/app_database.dart';
import 'package:pulse/data/platform/file_backup_gateway.dart';
import 'package:pulse/domain/entities/action_item.dart';
import 'package:pulse/features/settings/settings_screen.dart';
import 'package:pulse/features/settings/settings_strings.dart';

import '../data/support.dart';

void main() {
  testWidgets('a restore starts the app again on the restored data', (
    tester,
  ) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final dir = Directory.systemTemp.createTempSync('pulse-restart');
    final file = File('${dir.path}/pulse.sqlite');
    final opened = <AppDatabase>[];
    AppDatabase open() {
      final db = AppDatabase(
        DatabaseConnection(
          NativeDatabase(file),
          closeStreamsSynchronously: true,
        ),
        clock: const FixedClock(),
      );
      opened.add(db);
      return db;
    }

    ProviderContainer container() => ProviderScope.containerOf(
      tester.element(find.byType(PulseApp)),
      listen: false,
    );
    Future<List<String>> titles() async => [
      for (final row
          in await opened.last
              .customSelect('SELECT title FROM action_items')
              .get())
        row.read<String>('title'),
    ];

    await tester.runAsync(
      () => bootstrap(
        open: open,
        overrides: [
          clockProvider.overrideWithValue(const FixedClock()),
          backupGatewayProvider.overrideWith(
            (ref) => FileBackupGateway(
              ref.watch(appDatabaseProvider),
              const FixedClock(),
              tempDir: () async => dir,
              databaseFile: () async => file,
              open: NativeDatabase.new,
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    final first = container();

    late String backup;
    await tester.runAsync(() async {
      final items = first.read(actionItemRepositoryProvider);
      await items.create(const ActionItemInput(title: 'In the backup'));
      backup = await first.read(backupGatewayProvider).exportSqlite();
      await items.create(const ActionItemInput(title: 'Added later'));
    });
    await tester.pumpAndSettle();

    var done = false;
    await tester.runAsync(() async {
      first
          .read(restoreRunnerProvider)(backup)
          .whenComplete(() => done = true)
          .ignore();
    });
    for (var i = 0; i < 500 && !done; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(done, isTrue);
    expect(opened, hasLength(2));
    expect(container(), isNot(same(first)));
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text(SettingsStrings.restored), findsOneWidget);
    await tester.runAsync(() async {
      expect(await titles(), ['In the backup']);
      expect(File(backup).existsSync(), isFalse); // the picked copy
    });
    expect(tester.takeException(), isNull);

    final second = container();
    await tester.pumpWidget(const SizedBox.shrink());
    second.dispose();
    await tester.runAsync(() async {
      await opened.last.close();
      dir.deleteSync(recursive: true);
    });
  });
}
