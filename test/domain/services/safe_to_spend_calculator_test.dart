import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/rupiah.dart';
import 'package:pulse/domain/services/safe_to_spend.dart';
import 'package:pulse/domain/services/safe_to_spend_calculator.dart';

SafeToSpend? _compute({
  int caps = 5000000,
  int spent = 3200000,
  int committed = 350000,
  int days = 6,
  int today = 0,
}) => const DefaultSafeToSpendCalculator().compute(
  monthCaps: Rupiah(caps),
  spentBeforeToday: Rupiah(spent),
  committed: Rupiah(committed),
  daysLeft: days,
  spentToday: Rupiah(today),
);

void main() {
  test('worked example floors to Rp 241.666', () {
    final s = _compute()!;
    expect(s.perDay.value, 241666);
    expect(s.remaining.value, 241666);
  });

  test("today's spend lowers remaining only, which may go negative", () {
    final s = _compute(today: 300000)!;
    expect(s.perDay.value, 241666);
    expect(s.spentToday.value, 300000);
    expect(s.remaining.value, -58334);
  });

  test('an overspent month gives 0 per day', () {
    final s = _compute(spent: 6000000, today: 10000)!;
    expect(s.perDay.value, 0);
    expect(s.remaining.value, -10000);
  });

  test('no budgets gives null', () {
    expect(_compute(caps: 0), isNull);
  });

  test('days left must include today', () {
    expect(() => _compute(days: 0), throwsArgumentError);
  });
}
