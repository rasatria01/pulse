import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/failures.dart';
import 'package:pulse/domain/entities/category.dart';
import 'package:pulse/domain/entities/tag.dart';
import 'package:pulse/domain/entities/transaction.dart';
import 'package:pulse/domain/entities/wallet.dart';
import 'package:pulse/domain/repositories/settings_repository.dart';

import 'support.dart';

void main() {
  late Harness h;
  setUp(() => h = Harness());
  tearDown(() => h.db.close());

  test('UnitOfWork rolls back every repository write', () async {
    final cash = await h.cash();
    await expectLater(
      h.unitOfWork.run(() async {
        await h.transactions.create(txn(TxnType.outcome, 50, cash.id));
        await h.tags.ensure(['gone']);
        await h.settings.put(SettingKeys.theme, 'dark');
        throw StateError('boom');
      }),
      throwsStateError,
    );

    expect(await h.balances(), {cash.id: 0});
    expect(await h.tags.watchAll().first, isEmpty);
    expect(await h.settings.watch(SettingKeys.theme).first, isNull);
    expect(await h.sql('SELECT * FROM search_index'), isEmpty);
  });

  test('exactly one default wallet; archived ones cannot be it', () async {
    final cash = await h.cash();
    final bank = await h.addWallet('bca');
    await expectLater(
      h.wallets.archive(cash.id),
      throwsA(isA<ValidationFailure>()),
    );
    await h.wallets.setDefault(bank.id);
    await h.wallets.archive(cash.id);
    await expectLater(
      h.wallets.setDefault(cash.id),
      throwsA(isA<ValidationFailure>()),
    );

    final refs = await h.wallets.refs();
    expect(
      {for (final r in refs) r.slug: (r.isDefault, r.isArchived)},
      {'cash': (false, true), 'bca': (true, false)},
    );
  });

  test('wallet input is normalised, checked and patched', () async {
    final w = await h.wallets.create(
      const WalletInput(
        name: ' GoPay ',
        slug: 'GoPay',
        aliases: ['gp', 'Gojek'],
        kind: WalletKind.ewallet,
        color: 1,
        icon: 'i',
      ),
    );
    expect((w.name, w.slug), ('GoPay', 'gopay'));
    expect(w.aliases, ['gp', 'gojek']);

    final patched = await h.wallets.update(
      w.id,
      const WalletPatch(name: 'Gopay 2'),
    );
    expect(patched.aliases, w.aliases);
    expect(patched.name, 'Gopay 2');

    await expectLater(
      h.wallets.update(w.id, const WalletPatch(aliases: ['a,b'])),
      throwsA(isA<ValidationFailure>()),
    );
    await expectLater(
      h.wallets.update('nope', const WalletPatch()),
      throwsA(isA<NotFoundFailure>()),
    );
  });

  test('categories: kind filter, archive, system rows protected', () async {
    final food = await h.category('food', CategoryKind.outcome);
    final system = await h.category('uncategorized', CategoryKind.outcome);
    await h.categories.update(food.id, const CategoryPatch(name: 'Makan'));
    await h.categories.archive(food.id);

    expect((await h.categories.refs()).map((c) => c.id), isNot(food.id));
    final outcome = await h.categories
        .watchAll(kind: CategoryKind.outcome, includeArchived: true)
        .first;
    expect(outcome.map((c) => c.name), contains('Makan'));
    expect(outcome.every((c) => c.kind == CategoryKind.outcome), isTrue);
    await expectLater(
      h.categories.archive(system.id),
      throwsA(isA<ValidationFailure>()),
    );

    await h.db.customStatement(
      "UPDATE categories SET is_deleted = 1 WHERE id = '${food.id}'",
    );
    final all = await h.categories.watchAll(includeArchived: true).first;
    expect(all.map((c) => c.id), isNot(contains(food.id)));
  });

  test('tags: ensure is idempotent; setTags replaces and revives', () async {
    final cash = await h.cash();
    final t = await h.transactions.create(txn(TxnType.outcome, 1, cash.id));
    final first = await h.tags.ensure(['Dev', 'work', 'dev']);
    expect(first.map((x) => x.name), ['Dev', 'work']);
    expect(first.map((x) => x.slug), ['dev', 'work']);
    expect(await h.tags.ensure(['DEV']), [first.first]);

    Future<List<String>> tagsOf() async =>
        (await h.transactions.find(t.id))!.tagIds;
    final ids = [for (final tag in first) tag.id]..sort();

    await h.tags.setTags(EntityType.transaction, t.id, ids);
    expect(await tagsOf(), ids);
    await h.tags.setTags(EntityType.transaction, t.id, [ids.first]);
    expect(await tagsOf(), [ids.first]);
    await h.tags.setTags(EntityType.transaction, t.id, ids);
    expect(await tagsOf(), ids);

    await h.tags.softDelete(ids.first);
    expect(await tagsOf(), [ids.last]);
    expect((await h.tags.watchAll().first).map((x) => x.id), [ids.last]);

    await expectLater(
      h.tags.setTags(EntityType.note, 'missing', [ids.last]),
      throwsA(isA<NotFoundFailure>()),
    );
    await expectLater(
      h.tags.setTags(EntityType.transaction, t.id, [ids.first]),
      throwsA(isA<NotFoundFailure>()),
    );
  });

  test('settings: put, watch and notification ids', () async {
    await h.settings.put(SettingKeys.theme, 'dark');
    await h.settings.put(SettingKeys.theme, 'light');
    expect(await h.settings.watch(SettingKeys.theme).first, 'light');

    final ids = await Future.wait([
      for (var i = 0; i < 5; i++) h.settings.nextNotificationId(),
    ]);
    expect(ids.toSet(), {1, 2, 3, 4, 5});
    expect(await h.settings.watch(SettingKeys.nextNotifId).first, '6');
  });
}
