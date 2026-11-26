// C of safe-to-spend: what is owed but not yet in "spent before today".
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/rupiah.dart';
import 'package:pulse/domain/entities/action_item.dart';
import 'package:pulse/domain/entities/recurring_occurrence.dart';
import 'package:pulse/domain/entities/recurring_rule.dart';
import 'package:pulse/domain/entities/transaction.dart';
import 'package:pulse/domain/services/committed.dart';

import 'support.dart';

void main() {
  late Harness h;
  setUp(() => h = Harness());
  tearDown(() => h.db.close());

  final end = today.addDays(5);

  Future<ActionItem> bill(
    String title, {
    int due = 0,
    DateTime? start,
    bool noDue = false,
  }) => h.items.create(
    ActionItemInput(
      title: title,
      dueDate: noDue ? null : today.addDays(due),
      scheduledStart: start,
      linkedAmount: const Rupiah(1000),
    ),
  );

  Future<Set<String>> committed() async => {
    for (final item
        in await h.items
            .watchCommitted(today, end, doneSince: today.startUtc())
            .first)
      item.title,
  };

  Future<void> pay(ActionItem item, int day) async {
    final wallet = (await h.cash()).id;
    await h.transactions.create(
      txn(
        TxnType.outcome,
        1000,
        wallet,
        on: today.addDays(day),
      ).copyWith(sourceActionItemId: item.id),
    );
  }

  test('overdue open bills count; finished and later ones do not', () async {
    await bill('overdue', due: -40);
    await bill(
      'overdue start',
      noDue: true,
      start: today.addDays(-2).startUtc(),
    );
    await bill('this period', due: 2);
    await bill('later', due: 6);
    // Scheduled earlier but not due until after the period: not owed yet.
    await bill('due later', due: 30, start: today.addDays(-2).startUtc());
    final old = await bill('done before today', due: -3);
    await h.items.update(
      old.id,
      ActionItemPatch(
        status: ActionStatus.done,
        completedAt: (value: today.addDays(-1).startUtc()),
      ),
    );
    final paidToday = await bill('overdue, done today', due: -3);
    await h.items.update(
      paidToday.id,
      ActionItemPatch(
        status: ActionStatus.done,
        completedAt: (value: today.startUtc()),
      ),
    );

    expect(await committed(), {
      'overdue',
      'overdue start',
      'this period',
      'overdue, done today',
    });
  });

  test('a reopened bill whose earlier payment was kept is not owed', () async {
    final earlier = await bill('paid yesterday', due: -1);
    final todays = await bill('paid today');
    final removed = await bill('payment deleted', due: -1);
    await pay(earlier, -1);
    await pay(todays, 0);
    await pay(removed, -1);
    final payment = await h.transactions.findBySourceActionItem(removed.id);
    await h.transactions.softDelete(payment!.id);

    // Paying today is not in "spent before today", so it still counts.
    expect(await committed(), {'paid today', 'payment deleted'});
  });

  test('the stream follows a payment', () async {
    final item = await bill('rent', due: -1);
    final seen = h.items
        .watchCommitted(today, end, doneSince: today.startUtc())
        .map((items) => items.length);
    final expected = expectLater(seen, emitsInOrder([1, 0]));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await pay(item, -1);
    await expected;
  });

  test('unconfirmed recurring outcomes from before today count once', () async {
    final rule = await h.recurring.create(
      RecurringRuleInput(
        name: 'Rent',
        type: TxnType.outcome,
        amount: const Rupiah(500),
        walletId: (await h.cash()).id,
        freq: RecurFreq.yearly,
        startDate: today.addDays(-60),
        nextDueDate: today.addDays(300),
      ),
    );
    await h.recurring.insertOccurrence(rule.id, today.addDays(-60));
    final skipped = await h.recurring.insertOccurrence(
      rule.id,
      today.addDays(-30),
    );
    await h.recurring.resolveOccurrence(skipped, OccurrenceStatus.skipped);
    await h.recurring.insertOccurrence(rule.id, today);

    final total = committedAmount(
      bills: const [],
      occurrences: await h.recurring.watchOccurrences(today, end).first,
      pending: await h.recurring.watchPending().first,
      rules: await h.recurring.watchRules().first,
      today: today,
      periodEnd: end,
    );
    // The one from 60 days ago and today's, which is in both lists.
    expect(total, const Rupiah(1000));
  });
}
