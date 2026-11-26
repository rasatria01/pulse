// Every screen and sheet, full of awkward data, on a 360 dp phone at 1.3x text
// (PRD section 10); and Today stays lazy with 200 items.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse/app/di.dart';
import 'package:pulse/core/routes.dart';
import 'package:pulse/core/rupiah.dart';
import 'package:pulse/domain/entities/action_item.dart';
import 'package:pulse/domain/entities/category.dart';
import 'package:pulse/domain/entities/note.dart';
import 'package:pulse/domain/entities/recurring_rule.dart';
import 'package:pulse/domain/entities/transaction.dart';
import 'package:pulse/domain/entities/wallet.dart';
import 'package:pulse/domain/services/backup_gateway.dart';
import 'package:pulse/features/capture/capture_sheet.dart';
import 'package:pulse/features/finance/budget_sheet.dart';
import 'package:pulse/features/finance/rule_sheet.dart';
import 'package:pulse/features/finance/transaction_sheet.dart';
import 'package:pulse/features/finance/wallet_sheet.dart';
import 'package:pulse/features/settings/widgets/restore_sheet.dart';
import 'package:pulse/features/today/today_screen.dart';
import 'package:pulse/ui/planner/bill_sheet.dart';
import 'package:pulse/ui/planner/item_sheet.dart';
import 'package:pulse/ui/planner/occurrence_sheet.dart';
import 'package:pulse/ui/planner/schedule_sheet.dart';
import 'package:pulse/ui/widgets/widgets.dart';
import 'package:shad/shad.dart';

import '../data/support.dart';
import 'support.dart';

const _long = 'Bayar tagihan listrik dan internet apartemen bulan November';
const _word = 'Pertanggungjawabanadministrasikependudukan';
const _huge = Rupiah(999999999999);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

Future<T> _db<T>(WidgetTester tester, Future<T> work) async {
  var done = false;
  final result = work.whenComplete(() => done = true);
  for (var i = 0; !done && i < 400; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 1));
  }
  expect(done, isTrue, reason: 'database work did not finish');
  return result;
}

void _phone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 740);
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = 1.3;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(PCaptureBar).first));

typedef _Seeded = ({
  Wallet wallet,
  Category category,
  ActionItem bill,
  RecurringRule rule,
  Transaction transaction,
  Note note,
});

Future<_Seeded> _seed(WidgetTester tester) async {
  final c = _container(tester);
  Future<T> db<T>(Future<T> work) => _db(tester, work);
  final wallets = c.read(walletRepositoryProvider);
  final wallet = await db(
    wallets.create(
      const WalletInput(
        name: 'Rekening tabungan bersama keluarga besar',
        slug: 'tabungan_bersama_keluarga',
        kind: WalletKind.bank,
        initialBalance: _huge,
        color: 0xFF3B74E0,
        icon: 'wallet',
      ),
    ),
  );
  final category = await db(
    c
        .read(categoryRepositoryProvider)
        .watchAll(kind: CategoryKind.outcome)
        .first,
  ).then((all) => all.first);
  await db(
    c.read(budgetRepositoryProvider).setCap(category.id, _huge, today.monthOf),
  );
  final transactions = c.read(transactionRepositoryProvider);
  final transaction = await db(
    transactions.create(
      txn(
        TxnType.outcome,
        99999999999,
        wallet.id,
        category: category.id,
        description: '$_long $_word',
      ),
    ),
  );
  await db(
    transactions.create(
      txn(
        TxnType.transfer,
        99999999999,
        wallet.id,
        to: (await db(wallets.refs())).first.id,
      ),
    ),
  );

  final items = c.read(itemServiceProvider);
  Future<ActionItem> item(ActionItemInput input) =>
      db(items.create(input, tagSlugs: ['pertanggungjawaban', 'rumah_tangga']));
  final start = const FixedClock().nowUtc();
  await item(
    ActionItemInput(
      title: '$_long $_word',
      priority: Priority.high,
      dueDate: today.addDays(-30),
      linkedAmount: _huge,
    ),
  );
  await item(
    ActionItemInput(
      title: _word,
      scheduledStart: start,
      scheduledEnd: start.add(const Duration(hours: 11, minutes: 45)),
      reminderOffsetMin: 1440,
      priority: Priority.high,
      linkedAmount: _huge,
    ),
  );
  await item(ActionItemInput(title: _long, dueDate: today));
  final bill = await item(
    ActionItemInput(title: _long, dueDate: today, linkedAmount: _huge),
  );
  await db(c.read(billServiceProvider).defer(bill.id));

  await db(
    c
        .read(recurringRuleServiceProvider)
        .create(
          RecurringRuleInput(
            name: '$_long $_word',
            type: TxnType.outcome,
            amount: _huge,
            walletId: wallet.id,
            categoryId: category.id,
            freq: RecurFreq.weekly,
            interval: 99,
            startDate: today,
            nextDueDate: today,
            endDate: today.addDays(4000),
          ),
        ),
  );
  final rule = await db(c.read(recurringRepositoryProvider).watchRules().first)
      .then((all) => all.single);

  final notes = c.read(noteRepositoryProvider);
  const body =
      '# $_word\n\n- [ ] $_long\n\n| $_word | $_word |\n|---|---|\n'
      '| 1 | 2 |\n\n```\n$_long $_long\n```\n\n> $_long\n\n$_word$_word';
  final note = await db(notes.create(const NoteInput(body: body)));
  final daily = await db(notes.ensureDaily(today));
  await db(notes.saveBody(daily.id, body));
  await _settle(tester);
  return (
    wallet: wallet,
    category: category,
    bill: bill,
    rule: rule,
    transaction: transaction,
    note: note,
  );
}

/// The main scroll view of the screen on top.
Finder get _scrollable => find
    .byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    )
    .hitTestable();

void main() {
  for (final mode in [ShadThemeMode.light, ShadThemeMode.dark]) {
    testWidgets('full screens and sheets fit at 1.3x text, ${mode.name}', (
      tester,
    ) async {
      _phone(tester);
      await pumpApp(tester, mode: mode);

      // Collected, so one run names every place that overflows.
      var where = 'seeding';
      final errors = <String>[];
      final report = FlutterError.onError;
      FlutterError.onError = (d) {
        final lines = d.toString().split('\n');
        final at = lines.indexWhere((l) => l.contains('error-causing widget'));
        final found =
            '$where: ${d.exceptionAsString().split('\n').first} '
            '${at < 0 ? '' : lines.skip(at + 1).take(2).join(' ')}';
        if (!errors.contains(found)) errors.add(found);
      };

      try {
        final s = await _seed(tester);
        final router = GoRouter.of(tester.element(find.byType(TodayScreen)));

        Future<void> scroll() async {
          for (var i = 0; i < 12; i++) {
            if (_scrollable.evaluate().isEmpty) return;
            await tester.drag(
              _scrollable.first,
              const Offset(0, -450),
              warnIfMissed: false,
            );
            await tester.pump(const Duration(milliseconds: 100));
          }
          await _settle(tester);
        }

        Future<void> screen(String route, {bool push = false}) async {
          where = route;
          push ? router.push<void>(route).ignore() : router.go(route);
          await _settle(tester);
          await scroll();
        }

        for (final route in [
          Routes.today,
          Routes.tasks,
          Routes.calendar,
          Routes.notes,
          Routes.finance,
        ]) {
          await screen(route);
        }
        router.go(Routes.calendar);
        await _settle(tester);
        where = 'calendar week';
        await tester.tap(find.bySemanticsLabel('View: Week'));
        await _settle(tester);
        await scroll();

        router.go(Routes.today);
        await _settle(tester);
        await screen(Routes.settings, push: true);
        router.pop();
        await _settle(tester);

        await screen(Routes.search, push: true);
        where = 'search results';
        await tester.enterText(find.byType(EditableText).last, 'bayar');
        await tester.pump(const Duration(milliseconds: 200));
        await _settle(tester);
        await scroll();
        router.pop();
        await _settle(tester);

        await screen(Routes.notePath(s.note.id), push: true);
        where = 'note preview';
        await tester.tap(find.bySemanticsLabel('Preview'));
        await _settle(tester);
        await scroll();
        router.pop();
        await _settle(tester);

        final root = Navigator.of(
          tester.element(find.byType(TodayScreen)),
          rootNavigator: true,
        ).context;
        final c = _container(tester);
        final walletList = await _db(
          tester,
          c.read(walletRepositoryProvider).watchAll().first,
        );
        final categoryList = await _db(
          tester,
          c.read(categoryRepositoryProvider).watchAll().first,
        );
        final sheets = <String, Widget>{
          'capture': const CaptureSheet(),
          'wallet': WalletSheet(wallet: s.wallet),
          'new wallet': const WalletSheet(),
          'budget': BudgetSheet(categoryId: s.category.id),
          'new budget': const BudgetSheet(),
          'rule': RuleSheet(rule: s.rule),
          'new rule': const RuleSheet(),
          'transaction': TransactionSheet(transaction: s.transaction),
          'transfer': const TransactionSheet(),
          'item': ItemSheet(
            today: today,
            item: s.bill,
            tagSlugs: const [_word, 'rumah_tangga'],
          ),
          'new item': const ItemSheet(today: today, scheduleOn: today),
          'schedule': const ScheduleSheet(title: _long, today: today),
          'occurrence': const OccurrenceSheet(
            title: _long,
            amount: _huge,
            walletName: _long,
          ),
          'bill': BillSheet(
            wallets: [for (final w in walletList) w.wallet],
            categories: categoryList,
            walletId: s.wallet.id,
            categoryId: s.category.id,
            description: _long,
            amount: _huge,
          ),
          'restore': RestoreSheet(
            check: RestoreCheck(
              exportedAt: const FixedClock().nowUtc(),
              rowCounts: const {
                'transactions': 99999999,
                'action_items': 99999999,
                'notes': 99999999,
                'wallets': 99999999,
              },
            ),
          ),
        };
        for (final MapEntry(key: name, value: sheet) in sheets.entries) {
          where = '$name sheet';
          showPSheet<Object?>(context: root, builder: (_) => sheet).ignore();
          await _settle(tester);
          expect(find.byWidget(sheet), findsOneWidget, reason: name);
          if (name == 'capture') {
            await tester.enterText(
              find.byType(EditableText).last,
              '-999999999k $_word @tabungan_bersama_keluarga #$_word besok',
            );
            await _settle(tester);
          }
          Navigator.of(root).pop();
          await _settle(tester);
        }

        await screen(Routes.gallery, push: true);
      } finally {
        FlutterError.onError = report;
      }
      // ignore: avoid_print
      errors.forEach(print);
      expect(errors, isEmpty);
      await tester.pump(const Duration(seconds: 6));
    });
  }

  testWidgets('Today with 200 items builds only the rows in view', (
    tester,
  ) async {
    _phone(tester);
    await pumpApp(tester);
    final items = _container(tester).read(actionItemRepositoryProvider);
    final unit = _container(tester).read(unitOfWorkProvider);
    await _db(
      tester,
      unit.run(() async {
        for (var i = 0; i < 100; i++) {
          await items.create(
            ActionItemInput(title: 'inbox $i', dueDate: today),
          );
          await items.create(
            ActionItemInput(
              title: 'timed $i',
              scheduledStart: today.startUtc().add(Duration(minutes: i * 10)),
            ),
          );
        }
      }),
    );
    await _settle(tester);

    final built =
        find.byType(PTimelineItem, skipOffstage: false).evaluate().length +
        find.byType(PInboxItem, skipOffstage: false).evaluate().length;
    expect(built, greaterThan(0));
    expect(built, lessThan(40));
    await tester.fling(
      find.byType(CustomScrollView).first,
      const Offset(0, -3000),
      5000,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
