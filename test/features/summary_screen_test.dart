import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/app/di.dart';
import 'package:pulse/domain/entities/category.dart';
import 'package:pulse/domain/entities/transaction.dart';
import 'package:pulse/features/finance/finance_strings.dart';
import 'package:pulse/features/finance/summary_entry.dart';
import 'package:pulse/ui/widgets/p_donut.dart';
import 'package:pulse/ui/widgets/p_month_bars.dart';
import 'package:pulse/ui/widgets/widgets.dart';

import '../data/support.dart';
import 'support.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }
}

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

void main() {
  testWidgets('opens from Finance, totals a month and steps back', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 2000);
    addTearDown(tester.view.reset);
    await pumpApp(tester);
    final c = ProviderScope.containerOf(
      tester.element(find.byType(PCaptureBar)),
    );
    final wallet = (await _db(
      tester,
      c.read(walletRepositoryProvider).refs(),
    )).first.id;
    final food = (await _db(
      tester,
      c
          .read(categoryRepositoryProvider)
          .watchAll(kind: CategoryKind.outcome)
          .first,
    )).firstWhere((cat) => cat.slug == 'food').id;
    final transactions = c.read(transactionRepositoryProvider);
    for (final input in [
      txn(TxnType.outcome, 30000, wallet, category: food),
      txn(TxnType.income, 100000, wallet),
    ]) {
      await _db(tester, transactions.create(input));
    }

    await tester.tap(find.byKey(const ValueKey('tab-finance')));
    await _settle(tester);
    await tester.tap(find.byType(SummaryEntry));
    await _settle(tester);

    expect(find.text('November 2026'), findsOneWidget);
    expect(find.text(FinanceStrings.leftOver('Rp 70.000')), findsOneWidget);
    expect(find.byType(PDonut), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.byType(PMonthBars), findsOneWidget);
    expect(find.text(FinanceStrings.walletsToday), findsOneWidget);
    expect(
      tester.widget<PButton>(_button(FinanceStrings.nextMonth)).onPressed,
      isNull,
    );

    await tester.tap(_button(FinanceStrings.previousMonth));
    await _settle(tester);
    expect(find.text('Oktober 2026'), findsOneWidget);
    expect(find.text(FinanceStrings.noRecords), findsOneWidget);
    expect(find.byType(PDonut), findsNothing);
    expect(find.text(FinanceStrings.walletsToday), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
