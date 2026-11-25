import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/failures.dart';
import 'package:pulse/core/local_date.dart';
import 'package:pulse/core/rupiah.dart';
import 'package:pulse/domain/entities/category.dart';
import 'package:pulse/domain/entities/transaction.dart';
import 'package:pulse/domain/entities/wallet.dart';
import 'package:pulse/domain/repositories/settings_repository.dart';

import 'support.dart';

void main() {
  late Harness h;
  setUp(() => h = Harness());
  tearDown(() => h.db.close());

  test('balances are derived; a transfer counts in neither total', () async {
    final cash = await h.cash();
    final bank = await h.addWallet('bca', initial: -1000);
    await h.transactions.create(txn(TxnType.income, 10000, cash.id));
    await h.transactions.create(txn(TxnType.outcome, 2500, cash.id));
    await h.transactions.create(
      txn(TxnType.transfer, 4000, cash.id, to: bank.id),
    );

    expect(await h.balances(), {cash.id: 3500, bank.id: 3000});
    expect(await h.wallets.watchLiquidTotal().first, const Rupiah(6500));
    expect(
      await h.transactions.watchOutcomeTotal(today, today).first,
      const Rupiah(2500),
    );
    final byCategory = await h.transactions
        .watchOutcomeByCategory(today.monthOf)
        .first;
    expect(byCategory.values.toList(), const [Rupiah(2500)]);
  });

  test('liquid total skips excluded and archived wallets', () async {
    final a = await h.addWallet('a', initial: 100);
    final b = await h.addWallet('b', initial: 20);
    await h.wallets.update(a.id, const WalletPatch(includeInTotal: false));
    await h.wallets.archive(b.id);

    expect(await h.wallets.watchLiquidTotal().first, Rupiah.zero);
    expect((await h.wallets.watchAll().first).length, 2); // Cash and a
    expect(await h.balances(), containsPair(b.id, 20));
  });

  test('the balance stream re-emits on writes', () async {
    final cash = await h.cash();
    final totals = expectLater(
      h.wallets.watchLiquidTotal(),
      emitsInOrder(const [Rupiah.zero, Rupiah(-5)]),
    );
    await pumpEventQueue();
    await h.transactions.create(txn(TxnType.outcome, 5, cash.id));
    await totals;
  });

  test('1,000 random creates, edits and deletes match a ledger', () async {
    final random = Random(42);
    final ids = [
      (await h.cash()).id,
      (await h.addWallet('bca', initial: 5000000)).id,
      (await h.addWallet('gopay', initial: -25000)).id,
    ];
    final initial = await h.balances();
    final live = <String, TransactionInput>{};
    final deleted = <String, TransactionInput>{};

    TransactionInput any() {
      final type = TxnType.values[random.nextInt(3)];
      final from = random.nextInt(3);
      final to = (from + 1 + random.nextInt(2)) % 3;
      return txn(
        type,
        1 + random.nextInt(2000000),
        ids[from],
        to: type == TxnType.transfer ? ids[to] : null,
        on: today.addDays(-random.nextInt(60)),
      );
    }

    String pick(Map<String, TransactionInput> from) =>
        from.keys.elementAt(random.nextInt(from.length));

    for (var i = 0; i < 1000; i++) {
      final op = random.nextInt(10);
      if (live.isEmpty || op < 4) {
        final input = any();
        live[(await h.transactions.create(input)).id] = input;
      } else if (op < 7) {
        final id = pick(live);
        final input = any();
        await h.transactions.update(id, input);
        live[id] = input;
      } else if (op < 9 || deleted.isEmpty) {
        final id = pick(live);
        await h.transactions.softDelete(id);
        deleted[id] = live.remove(id)!;
      } else {
        final id = pick(deleted);
        await h.transactions.undelete(id);
        live[id] = deleted.remove(id)!;
      }
    }

    final expected = {...initial};
    var income = 0, outcome = 0;
    for (final t in live.values) {
      final amount = t.amount.value;
      switch (t.type) {
        case TxnType.income:
          expected[t.walletId] = expected[t.walletId]! + amount;
          income += amount;
        case TxnType.outcome:
          expected[t.walletId] = expected[t.walletId]! - amount;
          outcome += amount;
        case TxnType.transfer:
          expected[t.walletId] = expected[t.walletId]! - amount;
          expected[t.toWalletId!] = expected[t.toWalletId!]! + amount;
      }
    }

    expect(income > 0 && outcome > 0 && deleted.isNotEmpty, isTrue);
    expect(await h.balances(), expected);
    final from = today.addDays(-60);
    expect(
      await h.transactions.watchOutcomeTotal(from, today).first,
      Rupiah(outcome),
    );
    final listed = await h.transactions.watchRange(from, today).first;
    expect(listed.map((t) => t.id).toSet(), live.keys.toSet());
  });

  test('soft-deleted transactions are filtered everywhere', () async {
    final cash = await h.cash();
    final bills = await h.category('bills', CategoryKind.outcome);
    await h.db.customStatement(
      "INSERT INTO action_items (id, title, created_at, updated_at) "
      "VALUES ('item', 'pay', 0, 0)",
    );
    final t = await h.transactions.create(
      txn(
        TxnType.outcome,
        100,
        cash.id,
        category: bills.id,
      ).copyWith(sourceActionItemId: 'item'),
    );
    final tag = (await h.tags.ensure(['work'])).single;
    await h.tags.setTags(.transaction, t.id, [tag.id]);

    expect((await h.transactions.watchDay(today).first).single.tagIds, [
      tag.id,
    ]);
    expect((await h.transactions.findBySourceActionItem('item'))?.id, t.id);

    await h.transactions.softDelete(t.id);
    expect(await h.transactions.watchDay(today).first, isEmpty);
    expect(await h.transactions.find(t.id), isNull);
    expect(await h.transactions.findBySourceActionItem('item'), isNull);
    expect(await h.balances(), {cash.id: 0});
    expect(
      await h.transactions.watchOutcomeByCategory(today.monthOf).first,
      isEmpty,
    );
    await expectLater(
      h.transactions.update(t.id, txn(TxnType.outcome, 1, cash.id)),
      throwsA(isA<NotFoundFailure>()),
    );
  });

  test('missing category becomes Uncategorized of the right kind', () async {
    final cash = await h.cash();
    for (final (type, kind) in [
      (TxnType.income, CategoryKind.income),
      (TxnType.outcome, CategoryKind.outcome),
    ]) {
      final t = await h.transactions.create(txn(type, 1, cash.id));
      expect(t.categoryId, (await h.category('uncategorized', kind)).id);
    }
  });

  test('invalid transactions are refused and leave nothing', () async {
    final cash = await h.cash();
    final old = await h.addWallet('old');
    final food = await h.category('food', CategoryKind.outcome);
    final kept = await h.transactions.create(txn(TxnType.outcome, 5, old.id));
    await h.wallets.archive(old.id);

    for (final input in [
      txn(TxnType.outcome, 0, cash.id),
      txn(TxnType.transfer, 1, cash.id),
      txn(TxnType.transfer, 1, cash.id, to: cash.id),
      txn(TxnType.income, 1, cash.id, category: food.id),
      txn(TxnType.outcome, 1, old.id),
    ]) {
      await expectLater(
        h.transactions.create(input),
        throwsA(isA<ValidationFailure>()),
      );
    }
    await expectLater(
      h.transactions.create(txn(TxnType.outcome, 1, 'nope')),
      throwsA(isA<NotFoundFailure>()),
    );
    // History in an archived wallet stays editable.
    await h.transactions.update(kept.id, txn(TxnType.outcome, 7, old.id));
    expect(await h.balances(), {cash.id: 0, old.id: -7});
  });

  test('category totals follow budget_month_start_day', () async {
    final cash = await h.cash();
    for (final (day, amount) in const [
      (LocalDate(2026, 11, 24), 1),
      (LocalDate(2026, 11, 25), 10),
      (LocalDate(2026, 12, 24), 100),
      (LocalDate(2026, 12, 25), 1000),
    ]) {
      await h.transactions.create(
        txn(TxnType.outcome, amount, cash.id, on: day),
      );
    }
    final november = h.transactions
        .watchOutcomeByCategory(today.monthOf)
        .map((m) => m.values.fold(0, (sum, r) => sum + r.value));
    final totals = expectLater(november, emitsInOrder([11, 110]));
    await pumpEventQueue();
    await h.settings.put(SettingKeys.budgetMonthStartDay, '25');
    await totals;
  });
}
