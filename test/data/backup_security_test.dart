// What a hostile backup is refused for, and what an export must not carry.
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/rupiah.dart';
import 'package:pulse/data/platform/file_backup_gateway.dart';
import 'package:pulse/domain/entities/action_item.dart';
import 'package:pulse/domain/entities/category.dart';
import 'package:pulse/domain/entities/note.dart';
import 'package:pulse/domain/entities/recurring_rule.dart';
import 'package:pulse/domain/entities/transaction.dart';
import 'package:pulse/domain/services/backup_gateway.dart';
import 'package:pulse/domain/services/note_task_sync_impl.dart';
import 'package:sqlite3/sqlite3.dart';

import '../features/planner_services_test.dart' show FakeScheduler;
import 'support.dart';

Directory _tempDir() {
  final dir = Directory.systemTemp.createTempSync('pulse-secure');
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}

(Harness, FileBackupGateway, File) _app() {
  final dir = _tempDir();
  final file = File('${dir.path}/pulse.sqlite');
  final h = Harness(NativeDatabase(file));
  addTearDown(h.db.close);
  final gateway = FileBackupGateway(
    h.db,
    const FixedClock(),
    tempDir: () async => dir,
    databaseFile: () async => file,
    open: NativeDatabase.new,
  );
  return (h, gateway, file);
}

DefaultNoteTaskSync _sync(Harness h) => DefaultNoteTaskSync(
  notes: h.notes,
  items: h.items,
  tags: h.tags,
  wallets: h.wallets,
  categories: h.categories,
  transactions: h.transactions,
  settings: h.settings,
  reminders: FakeScheduler(),
  unitOfWork: h.unitOfWork,
  clock: const FixedClock(),
);

void _change(String path, List<String> statements) {
  final db = sqlite3.open(path);
  try {
    // A hostile file is not bound by our checks.
    db.execute('PRAGMA ignore_check_constraints = ON');
    statements.forEach(db.execute);
  } finally {
    db.close();
  }
}

void main() {
  test('refuses text, dates and alarm ids the app cannot read', () async {
    final (h, gateway, _) = _app();
    final cash = await h.cash();
    final food = await h.category('food', CategoryKind.outcome);
    await h.transactions.create(
      txn(TxnType.outcome, 1000, cash.id, category: food.id),
    );
    await h.items.create(const ActionItemInput(title: 'a', notifId: 1));
    await h.budgets.setCap(food.id, const Rupiah(5000), today.monthOf);
    await h.settings.put('theme', 'dark');
    await h.settings.nextNotificationId();
    final good = await gateway.exportSqlite();
    expect((await gateway.inspect(good)).refusal, isNull);

    const badText = "CAST(x'ff' AS TEXT)";
    final cases = [
      "UPDATE app_settings SET value = $badText WHERE key = 'theme'",
      'UPDATE action_items SET title = $badText',
      'UPDATE categories SET name = $badText',
      "UPDATE transactions SET occurred_on = 'abcd-ef-gh'",
      "UPDATE transactions SET occurred_on = '2026-02-30'",
      "UPDATE transactions SET occurred_on = '2026-13-01'",
      "UPDATE action_items SET due_date = 'now'",
      "UPDATE budgets SET effective_from = '2026-13'",
      "UPDATE budgets SET effective_from = 'abcd-ef'",
      'UPDATE action_items SET notif_id = 2147483648',
      'UPDATE action_items SET notif_id = -2147483649',
      "UPDATE app_settings SET value = '2147483648' "
          "WHERE key = 'next_notif_id'",
      "UPDATE app_settings SET value = 'abc' WHERE key = 'next_notif_id'",
    ];
    for (final (i, sql) in cases.indexed) {
      final path = File(good).copySync('$good.$i').path;
      _change(path, [sql]);
      expect(
        (await gateway.inspect(path)).refusal,
        RestoreRefusal.damaged,
        reason: sql,
      );
    }

    // Leap days and the int32 limit are fine.
    _change(good, [
      "UPDATE transactions SET occurred_on = '2028-02-29'",
      'UPDATE action_items SET notif_id = 2147483647',
    ]);
    expect((await gateway.inspect(good)).refusal, isNull);
  });

  test('a Unicode space in the schema is not a space', () async {
    final (_, gateway, _) = _app();
    for (final space in const [' ', ' ', '　', '﻿']) {
      final path = await gateway.exportSqlite();
      // The column becomes one name, `value<space>TEXT`, with no type.
      _change(path, [
        'PRAGMA writable_schema = ON',
        'UPDATE sqlite_schema SET '
            "sql = replace(sql, 'value TEXT', 'value${space}TEXT'), "
            "name = name WHERE name = 'app_settings'",
        'UPDATE sqlite_schema SET '
            "sql = replace(sql, '\"value\" TEXT', '\"value\"${space}TEXT') "
            "WHERE name = 'app_settings'",
      ]);
      final db = sqlite3.open(path);
      final sql = db
          .select("SELECT sql FROM sqlite_schema WHERE name = 'app_settings'")
          .single
          .values
          .single;
      db.close();
      expect(sql, contains(space));
      expect(
        (await gateway.inspect(path)).refusal,
        RestoreRefusal.schema,
        reason: 'U+${space.codeUnitAt(0).toRadixString(16)}',
      );
    }
  });

  test('an export keeps no text of what was deleted', () async {
    final (h, gateway, file) = _app();
    final cash = await h.cash();
    final food = await h.category('food', CategoryKind.outcome);
    // One word each: the search index stores words.
    final note = await h.notes.create(
      const NoteInput(title: 'zqnotetitle', body: 'zqnotebody'),
    );
    final item = await h.items.create(
      const ActionItemInput(
        title: 'zqitemtitle',
        body: 'zqitembody',
        rawInput: 'zqitemraw',
      ),
    );
    final spent = await h.transactions.create(
      txn(
        TxnType.outcome,
        1000,
        cash.id,
        category: food.id,
        description: 'zqspent',
      ).copyWith(rawInput: 'zqspentraw'),
    );
    final rule = await h.recurring.create(
      RecurringRuleInput(
        name: 'zqrulename',
        description: 'zqruledesc',
        type: TxnType.outcome,
        amount: const Rupiah(1000),
        walletId: cash.id,
        freq: RecurFreq.monthly,
        startDate: today,
        nextDueDate: today,
      ),
    );
    final tag = (await h.tags.ensure(['zqtagname'])).single;
    await h.items.create(const ActionItemInput(title: 'Kept'));

    await h.notes.softDelete(note.id);
    await h.items.softDelete(item.id);
    await h.transactions.softDelete(spent.id);
    await h.recurring.softDelete(rule.id);
    await h.tags.softDelete(tag.id);

    final path = await gateway.exportSqlite();

    final bytes = latin1.decode(File(path).readAsBytesSync());
    expect(bytes, isNot(contains('zq')));
    final copy = sqlite3.open(path);
    addTearDown(copy.close);
    copy.execute(
      'CREATE VIRTUAL TABLE temp.words USING '
      "fts5vocab(main, search_index, 'row')",
    );
    expect(
      copy.select("SELECT term FROM temp.words WHERE term LIKE 'zq%'"),
      isEmpty,
    );
    // The rows and their ids stay.
    for (final (table, id) in [
      ('notes', note.id),
      ('action_items', item.id),
      ('transactions', spent.id),
      ('recurring_rules', rule.id),
      ('tags', tag.id),
    ]) {
      expect(
        copy.select('SELECT is_deleted FROM $table WHERE id = ?', [
          id,
        ]).single['is_deleted'],
        1,
        reason: table,
      );
    }
    expect((await gateway.inspect(path)).refusal, isNull);
    // Only the copy is blanked.
    expect(await h.sql('SELECT 1 FROM notes WHERE title = \'zqnotetitle\''), [
      anything,
    ]);
    expect(file.existsSync(), isTrue);
  });

  test('after a restore, a deleted note line can come back', () async {
    final (h, gateway, file) = _app();
    final noteId = (await h.notes.create(const NoteInput())).id;
    final sync = _sync(h);
    final body = await sync.onNoteSaved(noteId, '- [ ] water plants');
    await sync.onNoteSaved(noteId, '');
    await gateway.restore(await gateway.exportSqlite());

    final after = Harness(NativeDatabase(file));
    addTearDown(after.db.close);
    // Pasted back with its token, ticked or not, or with no words left.
    expect(await _sync(after).onNoteSaved(noteId, body), body);
    var item = (await after.items.findBySourceNote(noteId)).single;
    expect(item.title, 'water plants');

    await _sync(after).onNoteSaved(noteId, '');
    final bare = '- [x] ^${item.sourceBlockId}';
    await _sync(after).onNoteSaved(noteId, bare);
    item = (await after.items.findBySourceNote(noteId)).single;
    expect(item.status, ActionStatus.done);
  });
}
