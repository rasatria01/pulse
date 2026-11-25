import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/db/app_database.dart';
import 'package:pulse/data/platform/file_backup_gateway.dart';
import 'package:pulse/domain/entities/action_item.dart';

import 'support.dart';

void main() {
  test('exports a dated Pulse database with the rows in it', () async {
    final dir = Directory.systemTemp.createTempSync('pulse-export');
    addTearDown(() => dir.deleteSync(recursive: true));
    final h = Harness(NativeDatabase(File('${dir.path}/live.sqlite')));
    addTearDown(h.db.close);
    await h.items.create(const ActionItemInput(title: 'Kept'));
    final gateway = FileBackupGateway(
      h.db,
      const FixedClock(),
      tempDir: () async => dir,
    );

    final path = await gateway.exportSqlite();
    // A second export in the same minute replaces the first.
    expect(await gateway.exportSqlite(), path);
    expect(path, endsWith('/pulse-backup-20261125-1000.sqlite'));

    final copy = AppDatabase(NativeDatabase(File(path)));
    addTearDown(copy.close);
    Future<Object?> value(String sql) async =>
        (await copy.customSelect(sql).getSingle()).data.values.single;
    expect(await value('PRAGMA integrity_check'), 'ok');
    expect(await value('PRAGMA application_id'), AppDatabase.applicationId);
    expect(await value('PRAGMA user_version'), 1);
    expect(await value('SELECT title FROM action_items'), 'Kept');
  });
}
