import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/failures.dart';
import 'package:pulse/core/rupiah.dart';
import 'package:pulse/domain/entities/action_item.dart';
import 'package:pulse/domain/entities/recurring_rule.dart';
import 'package:pulse/domain/entities/transaction.dart';
import 'package:pulse/domain/repositories/action_item_repository.dart';
import 'package:pulse/domain/services/bill_service_impl.dart';
import 'package:pulse/domain/services/item_service.dart';
import 'package:pulse/domain/services/reminder_scheduler.dart';

import '../data/support.dart';

class FakeScheduler implements ReminderScheduler {
  /// notifId -> the item whose alarm is currently set.
  final alarms = <int, ActionItem>{};

  @override
  Future<void> scheduleItem(ActionItem item) async =>
      alarms[item.notifId!] = item;

  @override
  Future<void> cancel(int notifId) async => alarms.remove(notifId);

  @override
  Future<void> scheduleRule(RecurringRule rule) async {}

  @override
  Future<void> resyncAll() async {}
}

/// Fails the write that follows the payment insert.
class _FailingUpdate implements ActionItemRepository {
  _FailingUpdate(this._items);

  final ActionItemRepository _items;

  @override
  Future<ActionItem?> find(String id) => _items.find(id);

  @override
  Future<ActionItem> update(String id, ActionItemPatch patch) =>
      throw const StorageFailure('disk full');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Harness h;
  late FakeScheduler reminders;
  late ItemService items;
  late DefaultBillService bills;

  DefaultBillService billsOn(ActionItemRepository repository) =>
      DefaultBillService(
        items: repository,
        tags: h.tags,
        wallets: h.wallets,
        categories: h.categories,
        transactions: h.transactions,
        reminders: reminders,
        unitOfWork: h.unitOfWork,
        clock: const FixedClock(),
      );

  setUp(() {
    h = Harness();
    reminders = FakeScheduler();
    items = ItemService(
      items: h.items,
      tags: h.tags,
      transactions: h.transactions,
      settings: h.settings,
      reminders: reminders,
      unitOfWork: h.unitOfWork,
      clock: const FixedClock(),
    );
    bills = billsOn(h.items);
  });
  tearDown(() => h.db.close());

  Future<ActionItem> bill({int? amount = 350000}) => items.create(
    ActionItemInput(
      title: 'Internet',
      dueDate: today,
      linkedAmount: amount == null ? null : Rupiah(amount),
    ),
    tagSlugs: ['bill'],
  );

  Future<List<Transaction>> payments() =>
      h.transactions.watchRange(today.addDays(-5), today.addDays(5)).first;

  Future<ActionItem> reload(ActionItem item) async =>
      (await h.items.find(item.id))!;

  test(
    'every dated item gets an alarm id; changes replace or cancel',
    () async {
      final plain = await items.create(const ActionItemInput(title: 'Someday'));
      expect(plain.notifId, isNull);
      expect(reminders.alarms, isEmpty);

      final due = await items.create(
        const ActionItemInput(title: 'Tax', dueDate: today),
      );
      expect(reminders.alarms.keys, [due.notifId]);

      final dated = await items.schedule(
        plain.id,
        DateTime.utc(2026, 11, 26, 2),
      );
      expect(dated.notifId, isNot(due.notifId));
      expect(reminders.alarms[dated.notifId]!.scheduledStart, isNotNull);

      final moved = await items.edit(
        plain.id,
        const ActionItemInput(title: 'Someday'),
      );
      expect(moved.notifId, dated.notifId);
      expect(reminders.alarms.keys, [due.notifId]);

      await items.complete(due.id);
      expect(reminders.alarms, isEmpty);
      expect((await reload(due)).completedAt, const FixedClock().nowUtc());
      expect((await reload(due)).billStatus, isNull);

      await items.reopen(due.id);
      expect(reminders.alarms.keys, [due.notifId]);
      expect((await reload(due)).completedAt, isNull);

      await items.delete(due.id);
      expect(reminders.alarms, isEmpty);
      expect(await h.items.find(due.id), isNull);
      await items.restore(due.id);
      expect(reminders.alarms.keys, [due.notifId]);
    },
  );

  test(
    'confirm records exactly one linked OUTCOME and closes the bill',
    () async {
      final item = await bill();
      final draft = (await bills.draftFor(item))!;
      expect(draft.amount, const Rupiah(350000));
      expect(draft.walletId, (await h.cash()).id);

      await bills.confirm(item.id, draft);
      await bills.confirm(item.id, draft);

      final paid = (await payments()).single;
      expect(paid.type, TxnType.outcome);
      expect(paid.sourceActionItemId, item.id);
      expect(paid.description, 'Internet');
      final done = await reload(item);
      expect(done.status, ActionStatus.done);
      expect(done.billStatus, BillStatus.recorded);
      expect(done.completedAt, isNotNull);
      expect(reminders.alarms, isEmpty);
      await expectLater(bills.skip(item.id), throwsA(isA<ConflictFailure>()));
    },
  );

  test('a failed insert leaves the item open', () async {
    final item = await bill();
    final draft = (await bills.draftFor(item))!;

    await expectLater(
      bills.confirm(item.id, draft.copyWith(walletId: 'gone')),
      throwsA(isA<AppFailure>()),
    );
    await expectLater(
      bills.confirm(item.id, draft.copyWith(amount: null)),
      throwsA(isA<ValidationFailure>()),
    );
    // The payment goes in, then the item write fails: both roll back.
    await expectLater(
      billsOn(_FailingUpdate(h.items)).confirm(item.id, draft),
      throwsA(isA<StorageFailure>()),
    );

    expect(await payments(), isEmpty);
    expect((await reload(item)).status, ActionStatus.open);
    expect((await reload(item)).billStatus, isNull);
    expect(reminders.alarms, hasLength(1));
  });

  test(
    'completing without paying leaves it pending; skip records none',
    () async {
      final item = await bill(amount: null);
      expect((await bills.draftFor(item))!.amount, isNull);

      await items.complete(item.id);
      expect((await reload(item)).billStatus, BillStatus.pending);
      expect(await h.items.watchPendingBills().first, hasLength(1));

      await bills.skip(item.id);
      expect((await reload(item)).billStatus, BillStatus.skipped);
      await bills.defer(item.id);
      expect((await reload(item)).billStatus, BillStatus.pending);
      expect(await payments(), isEmpty);
    },
  );

  test('reopening keeps or deletes the payment', () async {
    final item = await bill();
    final draft = (await bills.draftFor(item))!;
    await bills.confirm(item.id, draft);

    await items.reopen(item.id);
    expect((await reload(item)).status, ActionStatus.open);
    expect((await reload(item)).billStatus, isNull);
    expect(await payments(), hasLength(1));

    // Completing again finds the payment instead of asking for a second one.
    await items.complete(item.id);
    expect((await reload(item)).billStatus, BillStatus.recorded);
    expect(await payments(), hasLength(1));

    await items.reopen(item.id, deleteTransaction: true);
    expect(await payments(), isEmpty);
    expect(reminders.alarms, hasLength(1));
  });

  test('draft: not a bill is null; an archived wallet falls back', () async {
    final task = await items.create(const ActionItemInput(title: 'Walk'));
    expect(await bills.draftFor(task), isNull);

    final old = await h.addWallet('old');
    await h.wallets.archive(old.id);
    final item = await items.create(
      ActionItemInput(
        title: 'Rent',
        linkedAmount: const Rupiah(1),
        linkedWalletId: old.id,
      ),
    );
    expect((await bills.draftFor(item))!.walletId, (await h.cash()).id);
  });
}
