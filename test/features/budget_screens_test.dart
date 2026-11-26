import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/app/bootstrap.dart';
import 'package:pulse/app/di.dart';
import 'package:pulse/core/clock.dart';
import 'package:pulse/core/local_date.dart';
import 'package:pulse/core/rupiah.dart';
import 'package:pulse/domain/entities/action_item.dart';
import 'package:pulse/domain/entities/category.dart';
import 'package:pulse/domain/entities/recurring_rule.dart';
import 'package:pulse/domain/entities/transaction.dart';
import 'package:pulse/features/finance/budget_sheet.dart';
import 'package:pulse/features/finance/rule_sheet.dart';
import 'package:pulse/features/finance/wallet_sheet.dart';
import 'package:pulse/ui/planner/occurrence_sheet.dart';
import 'package:pulse/ui/planner/planner_strings.dart';
import 'package:pulse/ui/strings.dart';
import 'package:pulse/ui/widgets/widgets.dart';

import '../data/support.dart';
import 'support.dart';

/// pumpAndSettle that also turns the real event loop, where a drift
/// `stream.first` finishes.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }
}

/// Awaits database work while pumping: drift needs the fake clock to move.
Future<T> _db<T>(WidgetTester tester, Future<T> work) async {
  var done = false;
  final result = work.whenComplete(() => done = true);
  for (var i = 0; !done && i < 200; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 1));
  }
  expect(done, isTrue, reason: 'database work did not finish');
  return result;
}

Finder _button(String label) => find.byWidgetPredicate(
  (w) => w is PButton && (w.semanticLabel ?? w.label) == label,
);

Finder _chip(String? field, String label) => find.byWidgetPredicate(
  (w) => w is PChip && w.field == field && w.label == label,
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await _settle(tester);
  await tester.tap(finder);
  await _settle(tester);
}

/// The screen's own scroll view, not a chip row inside it.
Finder get _list => find
    .descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 150, scrollable: _list);
  await _settle(tester);
}

Future<void> _fill(WidgetTester tester, String field, String text) async {
  await tester.enterText(
    find.descendant(
      of: find.byKey(ValueKey(field)),
      matching: find.byType(EditableText),
    ),
    text,
  );
  // Let the caret scroll finish, or it pulls the sheet back later.
  await _settle(tester);
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(PCaptureBar).first));

Future<void> _drain(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await _settle(tester);
}

void _phone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 740);
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = 1.3;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Future<List<Transaction>> _history(WidgetTester tester) => _db(
  tester,
  _container(tester)
      .read(transactionRepositoryProvider)
      .watchRange(const LocalDate(2000, 1, 1), const LocalDate(2100, 1, 1))
      .first,
);

Future<String> _walletId(WidgetTester tester) async => (await _db(
  tester,
  _container(tester).read(walletRepositoryProvider).refs(),
)).first.id;

void main() {
  testWidgets('safe-to-spend is the day\'s start: PRD 9.4 example', (
    tester,
  ) async {
    await pumpApp(tester);
    final container = _container(tester);
    final transactions = container.read(transactionRepositoryProvider);
    final wallet = await _walletId(tester);
    final food = (await _db(
      tester,
      container
          .read(categoryRepositoryProvider)
          .watchAll(kind: CategoryKind.outcome)
          .first,
    )).first;
    expect(find.text(MelaStrings.setBudget), findsOneWidget);

    await _db(
      tester,
      container
          .read(budgetRepositoryProvider)
          .setCap(food.id, const Rupiah(5000000), today.monthOf),
    );
    await _db(
      tester,
      transactions.create(
        txn(TxnType.outcome, 3200000, wallet, on: today.addDays(-10)),
      ),
    );
    final bill = await _db(
      tester,
      container
          .read(itemServiceProvider)
          .create(
            ActionItemInput(
              title: 'Internet',
              dueDate: today.addDays(3),
              linkedAmount: const Rupiah(150000),
            ),
          ),
    );
    // 200,000 of outcome rules: due on the 28th.
    await _db(
      tester,
      container
          .read(recurringRuleServiceProvider)
          .create(
            RecurringRuleInput(
              name: 'Gym',
              type: TxnType.outcome,
              amount: const Rupiah(200000),
              walletId: wallet,
              freq: RecurFreq.monthly,
              startDate: today.addDays(3),
              nextDueDate: today.addDays(3),
            ),
          ),
    );
    await _settle(tester);
    // The 3,200,000 and 5 days left of November, today included.
    var pulse = container.read(todayPulseProvider).requireValue;
    expect(today.daysUntil(const LocalDate(2026, 11, 30)) + 1, 6);
    expect(pulse.safeToSpend!.perDay, const Rupiah(241666));

    // Spending today and paying the bill today leave the target alone.
    await _db(
      tester,
      transactions.create(txn(TxnType.outcome, 100000, wallet)),
    );
    final bills = container.read(billServiceProvider);
    final draft = await _db(tester, bills.draftFor(bill));
    await _db(
      tester,
      bills.confirm(
        bill.id,
        draft!.copyWith(occurredAt: const FixedClock().nowUtc()),
      ),
    );
    await _settle(tester);
    pulse = container.read(todayPulseProvider).requireValue;
    expect(pulse.safeToSpend!.perDay, const Rupiah(241666));
    expect(pulse.safeToSpend!.remaining, const Rupiah(241666 - 250000));
    expect(find.text(MelaStrings.safeToSpend), findsOneWidget);
    await _drain(tester);
  });

  testWidgets('needs confirmation: own wallet, edit, confirm, skip', (
    tester,
  ) async {
    _phone(tester);
    await pumpApp(tester);
    final container = _container(tester);
    final cash = await _walletId(tester);
    final rules = container.read(recurringRuleServiceProvider);
    for (final name in ['Gym', 'Music', 'Cloud']) {
      await _db(
        tester,
        rules.create(
          RecurringRuleInput(
            name: name,
            type: TxnType.outcome,
            amount: const Rupiah(200000),
            walletId: cash,
            freq: RecurFreq.monthly,
            startDate: today,
            nextDueDate: today,
          ),
        ),
      );
    }
    await _settle(tester);

    Finder on(String row, String label) => find.descendant(
      of: find.ancestor(of: find.text(row), matching: find.byType(PConfirmRow)),
      matching: _button(label),
    );

    await _scrollTo(tester, find.text('Cloud'));
    await _tap(tester, on('Cloud', MelaStrings.edit));
    expect(find.byType(OccurrenceSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('occurrence-amount')),
        matching: find.byType(EditableText),
      ),
      '250000',
    );
    await tester.pumpAndSettle();
    await _tap(tester, _button(PlannerStrings.recordRecurring));
    expect((await _history(tester)).single.amount, const Rupiah(250000));
    await _tap(tester, _button(MelaStrings.undo));
    expect(await _history(tester), isEmpty);
    await _drain(tester);

    await _tap(tester, on('Cloud', MelaStrings.confirm));
    expect((await _history(tester)).single.description, 'Cloud');
    await _drain(tester);
    await _tap(tester, on('Gym', MelaStrings.skip));
    expect(await _history(tester), hasLength(1));
    expect(find.text('Gym'), findsNothing);
    expect(find.text('Music'), findsOneWidget);
    await _drain(tester);
  });

  testWidgets('finance: budget cap and recurring rule from the screen', (
    tester,
  ) async {
    _phone(tester);
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('tab-finance')));
    await _settle(tester);

    await _scrollTo(tester, _button('Add budget'));
    await _tap(tester, _button('Add budget'));
    expect(find.byType(BudgetSheet), findsOneWidget);
    await _tap(tester, _chip('Category', 'Food'));
    await _fill(tester, 'Monthly cap', '1.5jt');
    await _tap(tester, _button(MelaStrings.save));
    await _scrollTo(tester, find.byType(PBudgetBar));
    expect(
      tester.widget<PBudgetBar>(find.byType(PBudgetBar)).cap,
      const Rupiah(1500000),
    );
    expect(tester.takeException(), isNull);

    await _scrollTo(tester, _button('Add recurring'));
    await _tap(tester, _button('Add recurring'));
    expect(find.byType(RuleSheet), findsOneWidget);
    await _fill(tester, 'Name', 'Rent');
    await _fill(tester, 'Amount', '900k');
    await _tap(tester, _button(MelaStrings.save));
    expect(tester.takeException(), isNull);
    await _scrollTo(tester, find.text('Rent'));

    // Pause keeps what was typed.
    await _tap(tester, find.text('Rent'));
    await _fill(tester, 'Name', 'Rent B');
    await _tap(tester, _button('Pause'));
    await _scrollTo(tester, find.textContaining('Paused'));
    expect(find.text('Rent B'), findsOneWidget);

    await _tap(tester, find.text('Rent B'));
    await _tap(tester, _button('Delete'));
    await _tap(tester, _button('Confirm delete'));
    expect(find.text('Rent B'), findsNothing);
    expect(tester.takeException(), isNull);

    // Remove the cap.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 3000));
    await _settle(tester);
    await _scrollTo(tester, find.byType(PBudgetBar));
    await _tap(tester, find.byType(PBudgetBar));
    await _tap(tester, _button('Remove cap'));
    expect(find.byType(PBudgetBar), findsNothing);
  });

  testWidgets('Show older keeps the list and the scroll position', (
    tester,
  ) async {
    _phone(tester);
    await pumpApp(tester);
    final transactions = _container(tester).read(transactionRepositoryProvider);
    final wallet = await _walletId(tester);
    for (var i = 0; i < 12; i++) {
      await _db(
        tester,
        transactions.create(
          txn(
            TxnType.outcome,
            1000,
            wallet,
            description: 'row $i',
            on: today.addDays(-i),
          ),
        ),
      );
    }
    await tester.tap(find.byKey(const ValueKey('tab-finance')));
    await _settle(tester);
    await _scrollTo(tester, _button('Show older'));
    await tester.ensureVisible(_button('Show older'));
    await tester.pumpAndSettle();
    final before = tester.state<ScrollableState>(_list).position.pixels;

    await tester.tap(_button('Show older'));
    // The very next frame: the longer history is still loading.
    await tester.pump();
    expect(find.text('row 11'), findsOneWidget);
    expect(tester.state<ScrollableState>(_list).position.pixels, before);
    await _settle(tester);
    expect(tester.state<ScrollableState>(_list).position.pixels, before);
  });

  testWidgets('Set default and Archive keep unsaved wallet edits', (
    tester,
  ) async {
    _phone(tester);
    await pumpApp(tester);
    final repository = _container(tester).read(walletRepositoryProvider);
    for (final name in ['Bank', 'Jar']) {
      await tester.tap(find.byKey(const ValueKey('tab-finance')));
      await _settle(tester);
      await _tap(tester, _button('Add wallet'));
      await _fill(tester, 'Name', name);
      await _tap(tester, _button(MelaStrings.save));
    }

    await _tap(tester, find.byKey(const ValueKey('wallet-bank')));
    expect(find.byType(WalletSheet), findsOneWidget);
    await _fill(tester, 'Name', 'Main bank');
    await _tap(tester, _button('Set default'));
    await _tap(tester, find.byKey(const ValueKey('wallet-jar')));
    await _fill(tester, 'Name', 'Old jar');
    await _tap(tester, _button('Archive'));
    await _tap(tester, _button('Confirm archive'));

    final all = await _db(
      tester,
      repository.watchAll(includeArchived: true).first,
    );
    final bySlug = {for (final b in all) b.wallet.slug: b.wallet};
    expect(bySlug['bank']!.name, 'Main bank');
    expect(bySlug['bank']!.isDefault, isTrue);
    expect(bySlug['jar']!.name, 'Old jar');
    expect(bySlug['jar']!.isArchived, isTrue);
  });

  testWidgets('upkeep catches up after a frame, on resume and at midnight', (
    tester,
  ) async {
    await pumpApp(tester);
    final clock = _MovableClock();
    final db = _container(tester).read(appDatabaseProvider);
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(clock),
      ],
    );
    addTearDown(container.dispose);
    final wallet = await _walletId(tester);
    await _db(
      tester,
      container
          .read(recurringRepositoryProvider)
          .create(
            RecurringRuleInput(
              name: 'Daily',
              type: TxnType.outcome,
              amount: const Rupiah(1000),
              walletId: wallet,
              freq: RecurFreq.daily,
              startDate: today,
              nextDueDate: today,
              autoPost: true,
            ),
          ),
    );
    Future<int> posted() async => (await _history(tester)).length;

    final stop = startUpkeep(container);
    await _settle(tester);
    expect(await posted(), 1);

    clock.now = DateTime(2026, 11, 26, 0, 0, 1);
    await tester.pump(const Duration(days: 1));
    await _settle(tester);
    expect(await posted(), 2);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    clock.now = DateTime(2026, 11, 28, 8);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _settle(tester);
    expect(await posted(), 4);

    stop();
    container.dispose();
  });
}

final class _MovableClock implements Clock {
  DateTime now = DateTime(2026, 11, 25, 10);

  @override
  DateTime nowUtc() => now.toUtc();

  @override
  DateTime nowLocal() => now;

  @override
  LocalDate today() => LocalDate.fromDateTime(now);
}
