import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/app/di.dart';
import 'package:pulse/core/rupiah.dart';
import 'package:pulse/domain/entities/action_item.dart';
import 'package:pulse/domain/entities/recurring_rule.dart';
import 'package:pulse/domain/entities/transaction.dart';
import 'package:pulse/features/today/today_screen.dart';
import 'package:pulse/ui/planner/bill_sheet.dart';
import 'package:pulse/ui/planner/item_sheet.dart';
import 'package:pulse/ui/planner/planner_strings.dart';
import 'package:pulse/ui/planner/schedule_sheet.dart';
import 'package:pulse/ui/strings.dart';
import 'package:pulse/ui/widgets/widgets.dart';
import 'package:shad/shad.dart';

import '../data/support.dart';
import 'support.dart';

void _phone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 740);
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = 1.3;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

ProviderContainer _container(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(TodayScreen, skipOffstage: false)),
);

/// Lets the real event loop turn: cancelling a drift stream (`.first`) finishes
/// there, outside the test's fake clock.
Future<void> _turn(WidgetTester tester) =>
    tester.runAsync(() => Future<void>.delayed(Duration.zero));

/// A flow reads the database between frames, which pumpAndSettle alone won't
/// wait for.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await _turn(tester);
    await tester.pump(const Duration(milliseconds: 10));
  }
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await _settle(tester);
  expect(tester.takeException(), isNull);
}

Finder _button(String label) => find.byWidgetPredicate(
  (w) => w is PButton && (w.label ?? w.semanticLabel) == label,
);

Finder _chip(String field, String label) => find.byWidgetPredicate(
  (w) => w is PChip && w.field == field && w.label == label,
);

Finder _checkbox(String title) =>
    find.bySemanticsLabel(MelaStrings.complete(title));

/// Scrolls Today down until [finder] is on screen.
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  for (var i = 0; finder.evaluate().isEmpty && i < 20; i++) {
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -150));
    await tester.pumpAndSettle();
  }
  expect(finder, findsWidgets);
}

/// Lets the 5 s snackbar leave, so no timer outlives the test.
Future<void> _drain(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pumpAndSettle();
}

/// Awaits database work while pumping: drift needs the fake clock to move.
Future<T> _db<T>(WidgetTester tester, Future<T> work) async {
  var done = false;
  final result = work.whenComplete(() => done = true);
  for (var i = 0; !done && i < 100; i++) {
    await _turn(tester);
    await tester.pump(const Duration(milliseconds: 1));
  }
  expect(done, isTrue, reason: 'database work did not finish');
  return result;
}

Future<List<Transaction>> _payments(WidgetTester tester) => _db(
  tester,
  _container(tester)
      .read(transactionRepositoryProvider)
      .watchRange(today.addDays(-5), today.addDays(5))
      .first,
);

void main() {
  for (final mode in [ShadThemeMode.light, ShadThemeMode.dark]) {
    testWidgets('tasks: create, bill confirm, reopen, delete, ${mode.name}', (
      tester,
    ) async {
      _phone(tester);
      await pumpApp(tester, mode: mode);
      await _tap(tester, find.byKey(const ValueKey('tab-tasks')));

      // Create through the sheet, with every section of the form open.
      await _tap(tester, _button(PlannerStrings.addTask).first);
      expect(find.byType(ItemSheet), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('item-title')),
        'Pay internet bill for the whole house this month',
      );
      await _tap(tester, _chip(PlannerStrings.priority, PlannerStrings.high));
      await _tap(tester, _chip(PlannerStrings.dueDate, PlannerStrings.today));
      await _tap(
        tester,
        _chip(PlannerStrings.dueDate, PlannerStrings.pickDate),
      );
      await _tap(
        tester,
        _chip(PlannerStrings.dueDate, PlannerStrings.pickDate),
      );
      await tester.enterText(
        find.byKey(const ValueKey('item-tags')),
        '#bill #home',
      );
      await _tap(tester, _button(MelaStrings.save));
      const title = 'Pay internet bill for the whole house this month';
      expect(find.text(title), findsOneWidget);

      // A #bill item without an amount opens the sheet with Record disabled.
      await _tap(tester, _checkbox(title));
      expect(find.byType(BillSheet), findsOneWidget);
      expect(
        tester.widget<PButton>(_button(PlannerStrings.recordPayment)).onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(const ValueKey('bill-amount')),
        '350000',
      );
      await tester.pumpAndSettle();
      await _tap(tester, _button(PlannerStrings.recordPayment));
      expect(await _payments(tester), hasLength(1));
      await _drain(tester);

      // Reopening a recorded bill asks about its payment.
      await _tap(tester, _checkbox(title));
      expect(find.byType(ReopenBillSheet), findsOneWidget);
      await _tap(tester, _button(PlannerStrings.deletePayment));
      expect(await _payments(tester), isEmpty);

      // Delete from the edit sheet, then Undo.
      await _tap(tester, find.text(title));
      await _tap(tester, _button(PlannerStrings.delete));
      expect(find.text(title), findsNothing);
      await _tap(tester, _button(MelaStrings.undo));
      expect(find.text(title), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('today: confirm rows, timeline, inbox swipes, ${mode.name}', (
      tester,
    ) async {
      _phone(tester);
      await pumpApp(tester, mode: mode);
      final container = _container(tester);
      final service = container.read(itemServiceProvider);
      final bill = await _db(
        tester,
        service.create(
          const ActionItemInput(
            title: 'Electricity',
            linkedAmount: Rupiah(1250000),
          ),
        ),
      );
      await _db(tester, service.complete(bill.id));
      await _db(
        tester,
        service.create(
          ActionItemInput(
            title: 'Standup',
            scheduledStart: DateTime(2026, 11, 25, 9, 45).toUtc(),
          ),
          tagSlugs: ['dev'],
        ),
      );
      await _db(
        tester,
        service.create(
          ActionItemInput(title: 'Renew ID', dueDate: today.addDays(-2)),
        ),
      );
      final wallet = (await _db(
        tester,
        container.read(walletRepositoryProvider).refs(),
      )).first;
      final rules = container.read(recurringRepositoryProvider);
      final rule = await _db(
        tester,
        rules.create(
          RecurringRuleInput(
            name: 'Gym',
            type: TxnType.outcome,
            amount: const Rupiah(200000),
            walletId: wallet.id,
            freq: RecurFreq.monthly,
            startDate: today,
            nextDueDate: today,
          ),
        ),
      );
      await _db(tester, rules.insertOccurrence(rule.id, today));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await _reveal(tester, find.text('Electricity'));
      await _reveal(tester, find.text('Gym'));
      await _reveal(tester, find.text('Standup'));
      // No end draws as 30 minutes.
      expect(find.textContaining('09:45–10:15 · 30 min'), findsOneWidget);

      await _reveal(tester, find.textContaining('Overdue · 2 days'));
      // Swipe left schedules.
      final row = find.byType(PInboxItem);
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.drag(row, const Offset(-320, 0));
      await _settle(tester);
      expect(find.byType(ScheduleSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      // Swipe right completes.
      await tester.drag(row, const Offset(320, 0));
      await _settle(tester);
      expect(row, findsNothing);
      await _drain(tester);

      // Confirm on the row records the pre-filled payment.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 2000));
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('Electricity'));
      await _tap(tester, _button(MelaStrings.confirm).first);
      expect((await _payments(tester)).single.sourceActionItemId, bill.id);
      expect(find.text('Electricity'), findsNothing);
      // Undo puts it back in needs confirmation.
      await _tap(tester, _button(MelaStrings.undo));
      expect(await _payments(tester), isEmpty);
      expect(find.text('Electricity'), findsOneWidget);

      // Dismissing the edit sheet keeps it pending; Skip records nothing.
      await _tap(tester, _button(MelaStrings.edit).first);
      expect(find.byType(BillSheet), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await _tap(tester, _button(MelaStrings.skip).first);
      expect(find.text('Electricity'), findsNothing);
      expect(await _payments(tester), isEmpty);
      await _drain(tester);
    });

    testWidgets('calendar: day and week with the due lane, ${mode.name}', (
      tester,
    ) async {
      _phone(tester);
      await pumpApp(tester, mode: mode);
      final service = _container(tester).read(itemServiceProvider);
      await _db(
        tester,
        service.create(
          ActionItemInput(
            title: 'Dentist',
            scheduledStart: DateTime(2026, 11, 25, 13, 30).toUtc(),
            scheduledEnd: DateTime(2026, 11, 25, 14).toUtc(),
            reminderOffsetMin: 10,
          ),
        ),
      );
      await _db(
        tester,
        service.create(
          const ActionItemInput(title: 'File report', dueDate: today),
        ),
      );
      await _tap(tester, find.byKey(const ValueKey('tab-calendar')));
      expect(find.text('Dentist'), findsOneWidget);
      expect(find.text('File report'), findsOneWidget);
      expect(find.textContaining('13:30–14:00'), findsOneWidget);

      await _tap(tester, find.bySemanticsLabel('Next'));
      expect(find.text('Dentist'), findsNothing);
      expect(find.text(MelaStrings.noEvents), findsOneWidget);
      await _tap(tester, find.bySemanticsLabel('View: Week'));
      expect(find.text('Mon 23 Nov'), findsOneWidget);
      expect(find.text('Dentist'), findsOneWidget);

      // Tapping a row opens the editor with its values.
      await _tap(tester, find.text('Dentist'));
      expect(find.byType(ItemSheet), findsOneWidget);
      await _tap(tester, _button(PlannerStrings.complete));
      expect(find.textContaining('Done'), findsOneWidget);
      await _drain(tester);
    });
  }
}
