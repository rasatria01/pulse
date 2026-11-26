import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/app/di.dart';
import 'package:pulse/data/db/app_database.dart';
import 'package:pulse/domain/services/backup_gateway.dart';
import 'package:pulse/features/settings/settings_screen.dart';
import 'package:pulse/features/settings/settings_strings.dart';
import 'package:pulse/ui/theme.dart';
import 'package:shad/shad.dart';

import '../data/support.dart';

class _FakeBackup implements BackupGateway {
  var check = const RestoreCheck(refusal: RestoreRefusal.newer);
  final discarded = <String>[];

  @override
  Future<String?> pickBackup() async => 'picked';

  @override
  Future<RestoreCheck> inspect(String path) async => check;

  @override
  Future<void> discard(String path) async => discarded.add(path);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('a refusal says why; a good file needs a confirmation', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 740);
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
      clock: const FixedClock(),
    );
    addTearDown(db.close);
    final backup = _FakeBackup();
    final restored = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          backupGatewayProvider.overrideWithValue(backup),
          restoreRunnerProvider.overrideWithValue(
            (path) async => restored.add(path),
          ),
        ],
        child: ShadApp(
          theme: melaTheme(Brightness.light),
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> choose() async {
      await tester.scrollUntilVisible(
        find.text(SettingsStrings.chooseBackup),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(SettingsStrings.chooseBackup));
      await tester.pumpAndSettle();
    }

    await choose();
    expect(find.text(SettingsStrings.refusedNewer), findsOneWidget);
    expect(find.text(SettingsStrings.restoreConfirm), findsNothing);
    expect(backup.discarded, ['picked']);

    backup.check = RestoreCheck(
      schemaVersion: 1,
      exportedAt: DateTime.utc(2026, 11, 25, 3),
      rowCounts: const {'transactions': 2, 'notes': 1},
    );
    await choose();
    expect(find.textContaining('25 Nov 2026'), findsOneWidget);
    expect(find.text('2 rows'), findsOneWidget);
    expect(find.text('1 row'), findsOneWidget);
    await tester.tap(find.text(SettingsStrings.cancel));
    await tester.pumpAndSettle();
    expect(restored, isEmpty);
    expect(backup.discarded, ['picked', 'picked']);

    await choose();
    await tester.tap(find.text(SettingsStrings.restoreConfirm));
    await tester.pumpAndSettle();
    expect(restored, ['picked']);
    expect(tester.takeException(), isNull);
  });
}
