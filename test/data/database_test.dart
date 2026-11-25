import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/failures.dart';
import 'package:pulse/data/db/app_database.dart';
import 'package:pulse/domain/entities/category.dart';
import 'package:pulse/domain/entities/transaction.dart';

import 'support.dart';

void main() {
  late Harness h;
  setUp(() => h = Harness());
  tearDown(() => h.db.close());

  test('seeds the first-run rows', () async {
    final cash = await h.cash();
    expect((cash.name, cash.slug, cash.isDefault), ('Cash', 'cash', true));

    final categories = await h.categories.watchAll().first;
    expect(
      {for (final c in categories) '${c.kind.name}/${c.slug}/${c.isSystem}'},
      {
        'outcome/uncategorized/true',
        'income/uncategorized/true',
        'outcome/food/false',
        'outcome/transport/false',
        'outcome/bills/false',
        'income/income/false',
      },
    );
  });

  test('sets application_id and foreign keys', () async {
    final id = await h.sql('PRAGMA application_id');
    expect(id.single.data.values.single, AppDatabase.applicationId);
    final fk = await h.sql('PRAGMA foreign_keys');
    expect(fk.single.data.values.single, 1);
  });

  test('unique indexes ignore soft-deleted rows', () async {
    final first = await h.tags.ensure(['Dev']);
    await expectLater(h.addWallet('cash'), throwsA(isA<ConflictFailure>()));

    Future<void> insertTag(String id) => h.db.customStatement(
      "INSERT INTO tags (id, name, slug, created_at, updated_at) "
      "VALUES ('$id', 'dev', 'dev', 0, 0)",
    );
    await expectLater(insertTag('dup'), throwsA(isA<SqliteException>()));
    await h.tags.softDelete(first.single.id);
    await insertTag('reused');

    // Same slug under the other kind is a different category.
    await h.categories.create(
      const CategoryInput(
        name: 'Food refunds',
        slug: 'food',
        kind: CategoryKind.income,
        color: 0,
        icon: 'x',
      ),
    );
  });

  test('FTS triggers follow insert, update, soft delete and delete', () async {
    Future<List<String>> match(String word) async => [
      for (final row in await h.sql(
        "SELECT entity_type FROM search_index WHERE search_index "
        "MATCH '$word*' ORDER BY entity_type",
      ))
        row.read<String>('entity_type'),
    ];

    final cash = await h.cash();
    final input = txn(TxnType.outcome, 100, cash.id, description: 'bakso');
    final t = await h.transactions.create(input);
    await h.db.customStatement(
      "INSERT INTO action_items (id, title, created_at, updated_at) "
      "VALUES ('a', 'bakso run', 0, 0)",
    );
    await h.db.customStatement(
      "INSERT INTO notes (id, body, created_at, updated_at) "
      "VALUES ('n', 'resep bakso', 0, 0)",
    );
    expect(await match('bak'), ['action_item', 'note', 'transaction']);

    await h.transactions.update(t.id, input.copyWith(description: 'soto'));
    expect(await match('bak'), ['action_item', 'note']);
    expect(await match('soto'), ['transaction']);

    await h.transactions.softDelete(t.id);
    expect(await match('soto'), isEmpty);
    await h.transactions.undelete(t.id);
    expect(await match('soto'), ['transaction']);

    await h.db.customStatement('DELETE FROM transactions');
    await h.db.customStatement("UPDATE notes SET is_deleted = 1");
    await h.db.customStatement("DELETE FROM action_items");
    expect(await h.sql('SELECT * FROM search_index'), isEmpty);
  });

  test('on a background isolate: WAL, and failures still map', () async {
    final dir = Directory.systemTemp.createTempSync('pulse_test');
    final bg = Harness(
      NativeDatabase.createInBackground(File('${dir.path}/p.sqlite')),
    );
    addTearDown(() async {
      await bg.db.close();
      dir.deleteSync(recursive: true);
    });

    await expectLater(bg.addWallet('cash'), throwsA(isA<ConflictFailure>()));
    final mode = await bg.sql('PRAGMA journal_mode');
    expect(mode.single.data.values.single, 'wal');
  });
}
