import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/app/app.dart';
import 'package:pulse/app/di.dart';
import 'package:pulse/data/db/app_database.dart';
import 'package:pulse/domain/repositories/settings_repository.dart';
import 'package:pulse/domain/services/backup_gateway.dart';
import 'package:pulse/features/settings/settings_screen.dart';
import 'package:pulse/features/settings/settings_strings.dart';
import 'package:pulse/ui/strings.dart';
import 'package:pulse/ui/widgets/widgets.dart';
import 'package:shad/shad.dart';

import '../data/support.dart';

class _FakeBackup implements BackupGateway {
  final calls = <String>[];

  @override
  Future<String> exportSqlite() async => 'x.sqlite';

  @override
  Future<void> share(String path) async => calls.add('share $path');

  @override
  Future<bool> saveAs(String path) async {
    calls.add('save $path');
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('theme is stored and applied; export shares or saves', (
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
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(const FixedClock()),
          backupGatewayProvider.overrideWithValue(backup),
        ],
        child: const PulseApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is PButton && w.semanticLabel == PulseStrings.settings,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('theme-dark')));
    await tester.pumpAndSettle();
    final screen = tester.element(find.byType(SettingsScreen));
    expect(ShadTheme.of(screen).brightness, Brightness.dark);
    final stored = await db
        .customSelect(
          "SELECT value FROM app_settings WHERE key = '${SettingKeys.theme}'",
        )
        .getSingle();
    expect(stored.read<String>('value'), 'dark');
    expect(find.text('08:00'), findsOneWidget);

    await tester.tap(find.text(SettingsStrings.shareBackup));
    await tester.pumpAndSettle();
    await tester.tap(find.text(SettingsStrings.saveBackup));
    await tester.pumpAndSettle();
    expect(backup.calls, ['share x.sqlite', 'save x.sqlite']);
    expect(find.text(SettingsStrings.backupSaved), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
