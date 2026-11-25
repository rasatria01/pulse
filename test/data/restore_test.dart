import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/failures.dart';
import 'package:pulse/data/db/app_database.dart';
import 'package:pulse/data/platform/file_backup_gateway.dart';
import 'package:pulse/domain/entities/action_item.dart';
import 'package:pulse/domain/entities/category.dart';
import 'package:pulse/domain/entities/note.dart';
import 'package:pulse/domain/entities/search.dart';
import 'package:pulse/domain/entities/transaction.dart';
import 'package:pulse/domain/services/backup_gateway.dart';
import 'package:sqlite3/sqlite3.dart';

import 'support.dart';

/// A database in a real file, as on a phone, with its gateway.
class _App {
  _App(Directory dir) : file = File('${dir.path}/pulse.sqlite') {
    h = Harness(NativeDatabase(file));
    gateway = FileBackupGateway(
      h.db,
      const FixedClock(),
      tempDir: () async => dir,
      databaseFile: () async => file,
      open: NativeDatabase.new,
    );
    addTearDown(h.db.close);
  }

  final File file;
  late final Harness h;
  late final FileBackupGateway gateway;
}

Directory _tempDir() {
  final dir = Directory.systemTemp.createTempSync('pulse-restore');
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}

Future<void> _fill(Harness h) async {
  final cash = await h.cash();
  final bank = await h.addWallet('bank', initial: 1000000);
  final food = await h.category('food', CategoryKind.outcome);
  await h.transactions.create(
    txn(
      TxnType.outcome,
      35000,
      cash.id,
      category: food.id,
      description: 'nasi goreng',
    ),
  );
  await h.transactions.create(
    txn(TxnType.transfer, 200000, bank.id, to: cash.id),
  );
  final gone = await h.items.create(const ActionItemInput(title: 'Deleted'));
  await h.items.softDelete(gone.id);
  await h.items.create(const ActionItemInput(title: 'Kept'));
  await h.notes.create(const NoteInput(title: 'Plan', body: '# Plan'));
  final tag = (await h.tags.ensure(['home'])).single;
  await h.settings.put('theme', 'dark');
  expect(tag.slug, 'home');
}

Future<Map<String, int>> _counts(File file) async {
  final db = sqlite3.open(file.path, mode: OpenMode.readOnly);
  try {
    return {
      for (final table in const [
        'wallets',
        'categories',
        'transactions',
        'action_items',
        'notes',
        'tags',
        'search_index',
      ])
        table: db.select('SELECT count(*) AS n FROM $table').single['n'] as int,
    };
  } finally {
    db.close();
  }
}

Future<Map<String, int>> _balances(File file) async {
  final h = Harness(NativeDatabase(file));
  try {
    return await h.balances();
  } finally {
    await h.db.close();
  }
}

void main() {
  test(
    'export, then restore on a fresh install: same rows and money',
    () async {
      final old = _App(_tempDir());
      await _fill(old.h);
      final balances = await old.h.balances();
      final backup = await old.gateway.exportSqlite();

      final dir = _tempDir();
      final fresh = _App(dir);
      await fresh.h.items.create(const ActionItemInput(title: 'Replaced'));

      final check = await fresh.gateway.inspect(backup);
      expect(check.refusal, isNull);
      expect(check.schemaVersion, 1);
      expect(check.exportedAt, const FixedClock().nowUtc());
      expect(check.rowCounts['transactions'], 2);
      expect(check.rowCounts['action_items'], 1); // the deleted one not counted

      await fresh.gateway.restore(backup);

      final expected = await _counts(File(backup));
      expect(await _counts(fresh.file), expected);
      expect(await _balances(fresh.file), balances);
      expect(
        await _counts(File('${dir.path}/pulse-pre-restore.sqlite')),
        containsPair('action_items', 1),
      );
      expect(File('${fresh.file.path}-wal').existsSync(), isFalse);
      expect(File('${fresh.file.path}.restore').existsSync(), isFalse);

      final after = Harness(NativeDatabase(fresh.file));
      addTearDown(after.db.close);
      final hits = await after.search.search(const SearchQuery(text: 'nasi'));
      expect(hits.single.title, 'nasi goreng');
    },
  );

  test('refuses what it must, and leaves the data as it was', () async {
    final dir = _tempDir();
    final app = _App(dir);
    await _fill(app.h);
    final good = await app.gateway.exportSqlite();
    final before = await _counts(app.file);

    String copy(String name) => File(good).copySync('${dir.path}/$name').path;
    String changed(String name, String sql) {
      final path = copy(name);
      final db = sqlite3.open(path);
      db.execute(sql);
      db.close();
      return path;
    }

    final bytes = File(good).readAsBytesSync();
    String raw(String name, List<int> content) =>
        (File('${dir.path}/$name')..writeAsBytesSync(content)).path;
    final other = '${dir.path}/other.sqlite';
    sqlite3.open(other)
      ..execute('CREATE TABLE t (a)')
      ..close();

    final cases = {
      changed('newer', 'PRAGMA user_version = 2'): RestoreRefusal.newer,
      other: RestoreRefusal.notPulse,
      raw('text', utf8.encode('not a database ' * 100)):
          RestoreRefusal.notPulse,
      raw('empty', const []): RestoreRefusal.notPulse,
      raw('half', bytes.sublist(0, bytes.length ~/ 2)): RestoreRefusal.damaged,
      raw('cut', bytes.sublist(0, bytes.length - 4096)): RestoreRefusal.damaged,
      changed(
        'trigger',
        'CREATE TRIGGER evil AFTER INSERT ON notes BEGIN '
            'DELETE FROM transactions; END',
      ): RestoreRefusal.schema,
      changed('view', 'CREATE VIEW evil AS SELECT 1'): RestoreRefusal.schema,
      changed('missing', 'DROP TABLE budgets'): RestoreRefusal.schema,
      changed(
        'swapped',
        'DROP TRIGGER trg_note_fts_ins; CREATE TRIGGER trg_note_fts_ins '
            'AFTER INSERT ON notes BEGIN DELETE FROM wallets; END',
      ): RestoreRefusal.schema,
      changed('type', "UPDATE transactions SET occurred_at = 'noon'"):
          RestoreRefusal.damaged,
      changed('date', "UPDATE transactions SET occurred_on = 'today'"):
          RestoreRefusal.damaged,
      changed(
        'orphan',
        "UPDATE transactions SET wallet_id = 'nowhere' "
            "WHERE type = 'OUTCOME'",
      ): RestoreRefusal.damaged,
    };

    for (final MapEntry(key: path, value: refusal) in cases.entries) {
      final name = path.split('/').last;
      expect((await app.gateway.inspect(path)).refusal, refusal, reason: name);
      await expectLater(
        app.gateway.restore(path),
        throwsA(
          isA<ValidationFailure>().having((e) => e.message, name, refusal),
        ),
      );
    }
    // The database is still open and untouched.
    await app.h.items.create(const ActionItemInput(title: 'Still here'));
    expect((await _counts(app.file))['transactions'], before['transactions']);
    expect(File('${dir.path}/pulse-pre-restore.sqlite').existsSync(), isFalse);
  });

  test('a failure after the swap puts the old data back', () async {
    final source = _App(_tempDir());
    final backup = await source.gateway.exportSqlite();

    final dir = _tempDir();
    final file = File('${dir.path}/pulse.sqlite');
    final h = Harness(NativeDatabase(file));
    await _fill(h);
    final before = await _counts(file);
    final gateway = FileBackupGateway(
      h.db,
      const FixedClock(),
      tempDir: () async => dir,
      databaseFile: () async => file,
      open: (_) => throw const FileSystemException('cannot reopen'),
    );

    await expectLater(
      gateway.restore(backup),
      throwsA(isA<FileSystemException>()),
    );
    expect(await _counts(file), before);
  });

  test('the JSON export holds the live rows of every table', () async {
    final app = _App(_tempDir());
    await _fill(app.h);

    final path = await app.gateway.exportJson();

    expect(path, endsWith('/pulse-export-20261125-1000.json'));
    final json = jsonDecode(await File(path).readAsString()) as Map;
    final manifest = json['manifest'] as Map;
    expect(manifest['app_id'], AppDatabase.applicationId);
    expect(manifest['schema_version'], 1);
    expect(manifest['exported_at'], '2026-11-25T03:00:00.000Z');
    final counts = manifest['row_counts'] as Map;
    expect(json.keys.toSet(), {'manifest', ...counts.keys});
    expect(counts.keys, isNot(contains('search_index')));
    expect(counts, hasLength(11));
    for (final MapEntry(:key, :value) in counts.entries) {
      expect(json[key], hasLength(value as int), reason: '$key');
    }
    expect((json['action_items'] as List).single['title'], 'Kept');
    // Raw column values.
    final outcome = (json['transactions'] as List).firstWhere(
      (t) => (t as Map)['type'] == 'OUTCOME',
    );
    expect((outcome as Map)['amount'], 35000);
    expect(outcome['occurred_on'], '2026-11-25');
    expect(outcome['is_deleted'], 0);
  });
}
