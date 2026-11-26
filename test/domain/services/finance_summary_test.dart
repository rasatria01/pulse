import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/local_date.dart';
import 'package:pulse/core/rupiah.dart';
import 'package:pulse/data/repositories/budget_period.dart';
import 'package:pulse/domain/entities/transaction.dart';
import 'package:pulse/domain/services/finance_summary.dart';

SummaryPeriod _period(int month, [String startDay = '1']) {
  final m = LocalMonth(2026, month);
  final (from, to) = budgetPeriod(m, startDay);
  return (month: m, from: from, to: to);
}

Transaction _txn(
  String on,
  int amount, {
  TxnType type = TxnType.outcome,
  String category = 'food',
}) => Transaction(
  id: '$on-$amount-$category',
  type: type,
  amount: Rupiah(amount),
  walletId: 'cash',
  categoryId: type == TxnType.transfer ? null : category,
  occurredAt: DateTime.utc(2026),
  occurredOn: LocalDate.parse(on),
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  const today = LocalDate(2026, 11, 25);

  test('follows the month start day and leaves transfers out', () {
    final summary = summarize(
      [
        _txn('2026-10-24', 1), // before the October period
        _txn('2026-10-25', 100),
        _txn('2026-11-24', 20),
        _txn('2026-11-25', 7),
        _txn('2026-11-25', 500, type: TxnType.income),
        _txn('2026-11-25', 9000, type: TxnType.transfer),
      ],
      [_period(10, '25'), _period(11, '25')],
      today,
    );
    expect(
      [for (final m in summary.months) (m.income.value, m.spent.value)],
      [(0, 120), (500, 7)],
    );
    expect(summary.categories.single.amount.value, 7);
  });

  test('compares the current month with the same days of the last one', () {
    final transactions = [
      _txn('2026-10-25', 40),
      _txn('2026-10-26', 1000), // after the same day
      _txn('2026-11-25', 100),
      _txn('2026-11-30', 5), // dated ahead of today
    ];
    final periods = [_period(10), _period(11)];
    expect(summarize(transactions, periods, today).change!.value, 60);
    // A past month is compared whole.
    expect(
      summarize(
        transactions,
        periods,
        const LocalDate(2026, 12, 3),
      ).change!.value,
      105 - 1040,
    );
    expect(summarize([_txn('2026-11-02', 1)], periods, today).change, isNull);
  });

  test('keeps the five largest categories and folds the rest', () {
    List<(String?, int)> slices(int count) => [
      for (final c in summarize(
        [
          for (var i = 1; i <= count; i++)
            _txn('2026-11-01', i, category: '$i'),
        ],
        [_period(11)],
        today,
      ).categories)
        (c.categoryId, c.amount.value),
    ];
    expect(slices(6), hasLength(6));
    expect(slices(6).map((s) => s.$1), isNot(contains(null)));
    expect(slices(8), [
      ('8', 8),
      ('7', 7),
      ('6', 6),
      ('5', 5),
      ('4', 4),
      (null, 6),
    ]);
  });
}
