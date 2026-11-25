import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/local_date.dart';
import 'package:pulse/core/rupiah.dart';
import 'package:pulse/domain/entities/recurring_rule.dart';
import 'package:pulse/domain/entities/transaction.dart';
import 'package:pulse/domain/services/recurrence.dart';

RecurringRule _rule(
  RecurFreq freq,
  String start, {
  int interval = 1,
  int? byWeekday,
  int? byMonthDay,
}) => RecurringRule(
  id: 'r',
  name: 'rent',
  type: TxnType.outcome,
  amount: const Rupiah(1000),
  walletId: 'w',
  categoryId: 'c',
  freq: freq,
  interval: interval,
  byWeekday: byWeekday,
  byMonthDay: byMonthDay,
  startDate: LocalDate.parse(start),
  nextDueDate: LocalDate.parse(start),
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

/// [count] successive occurrences after the start date.
List<String> _run(RecurringRule rule, int count) {
  var date = rule.startDate;
  return [
    for (var i = 0; i < count; i++)
      (date = advanceOccurrence(rule, date)).toIso(),
  ];
}

void main() {
  test('daily adds N days across a year end', () {
    expect(_run(_rule(RecurFreq.daily, '2026-12-30', interval: 3), 2), [
      '2027-01-02',
      '2027-01-05',
    ]);
  });

  test('weekly keeps the start weekday, N weeks on', () {
    expect(_run(_rule(RecurFreq.weekly, '2026-11-25', interval: 2), 2), [
      '2026-12-09',
      '2026-12-23',
    ]);
  });

  test('weekly moves to by_weekday in the target week', () {
    // Start is a Wednesday; Monday and Sunday of the following weeks.
    expect(_run(_rule(RecurFreq.weekly, '2026-11-25', byWeekday: 1), 2), [
      '2026-11-30',
      '2026-12-07',
    ]);
    expect(_run(_rule(RecurFreq.weekly, '2026-11-25', byWeekday: 7), 2), [
      '2026-12-06',
      '2026-12-13',
    ]);
  });

  test('monthly on day 31 posts 2027-02-28, then returns to 31', () {
    expect(_run(_rule(RecurFreq.monthly, '2027-01-31'), 3), [
      '2027-02-28',
      '2027-03-31',
      '2027-04-30',
    ]);
  });

  test('monthly by_month_day wins over the start day and clamps', () {
    final rule = _rule(
      RecurFreq.monthly,
      '2027-11-05',
      interval: 3,
      byMonthDay: 30,
    );
    expect(_run(rule, 2), ['2028-02-29', '2028-05-30']);
  });

  test('yearly 29 Feb becomes 28 Feb until the next leap year', () {
    expect(_run(_rule(RecurFreq.yearly, '2028-02-29'), 4), [
      '2029-02-28',
      '2030-02-28',
      '2031-02-28',
      '2032-02-29',
    ]);
  });

  test('yearly honours the interval', () {
    expect(_run(_rule(RecurFreq.yearly, '2026-07-15', interval: 2), 1), [
      '2028-07-15',
    ]);
  });
}
