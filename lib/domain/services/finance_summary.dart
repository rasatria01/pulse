import '../../core/local_date.dart';
import '../../core/rupiah.dart';
import '../entities/transaction.dart';

/// A budget period: both dates inclusive.
typedef SummaryPeriod = ({LocalMonth month, LocalDate from, LocalDate to});

typedef MonthTotals = ({LocalMonth month, Rupiah income, Rupiah spent});

/// A null [categoryId] is everything outside the top categories.
typedef CategorySpend = ({String? categoryId, Rupiah amount});

typedef FinanceSummary = ({
  /// Oldest first; the last one is the picked month.
  List<MonthTotals> months,

  /// The picked month's spending, largest first.
  List<CategorySpend> categories,

  /// Spending minus the month before's. For the month [today] is in, both sides
  /// stop at the same day. Null when there is no spending to compare with.
  Rupiah? change,
});

const _top = 5;

/// Income and spending per period; transfers are neither.
FinanceSummary summarize(
  List<Transaction> transactions,
  List<SummaryPeriod> periods,
  LocalDate today,
) {
  final picked = periods.last;
  final previous = periods.length > 1 ? periods[periods.length - 2] : null;
  bool within(LocalDate day, LocalDate from, LocalDate to) =>
      !day.isBefore(from) && !day.isAfter(to);

  final current = previous != null && within(today, picked.from, picked.to);
  final until = current ? today : picked.to;
  var previousUntil = previous?.to;
  if (current) {
    final sameDay = previous.from.addDays(picked.from.daysUntil(today));
    if (sameDay.isBefore(previous.to)) previousUntil = sameDay;
  }

  final income = List.filled(periods.length, 0);
  final spent = List.filled(periods.length, 0);
  final byCategory = <String, int>{};
  var spentUntil = 0, previousSpent = 0;

  for (final t in transactions) {
    if (t.type == TxnType.transfer) continue;
    final i = periods.indexWhere((p) => within(t.occurredOn, p.from, p.to));
    if (i < 0) continue;
    final amount = t.amount.value;
    if (t.type == TxnType.income) {
      income[i] += amount;
      continue;
    }
    spent[i] += amount;
    if (i == periods.length - 1) {
      byCategory.update(
        t.categoryId!,
        (sum) => sum + amount,
        ifAbsent: () => amount,
      );
      if (!t.occurredOn.isAfter(until)) spentUntil += amount;
    } else if (i == periods.length - 2 &&
        !t.occurredOn.isAfter(previousUntil!)) {
      previousSpent += amount;
    }
  }

  final sorted = byCategory.entries.toList()
    ..sort((a, b) {
      final bySize = b.value.compareTo(a.value);
      return bySize != 0 ? bySize : a.key.compareTo(b.key);
    });
  // An "Other" of one category would only hide its name.
  final shown = sorted.length > _top + 1 ? _top : sorted.length;
  final rest = sorted.skip(shown).fold(0, (sum, e) => sum + e.value);

  return (
    months: [
      for (final (i, p) in periods.indexed)
        (month: p.month, income: Rupiah(income[i]), spent: Rupiah(spent[i])),
    ],
    categories: [
      for (final e in sorted.take(shown))
        (categoryId: e.key, amount: Rupiah(e.value)),
      if (rest > 0) (categoryId: null, amount: Rupiah(rest)),
    ],
    change: previousSpent == 0 ? null : Rupiah(spentUntil - previousSpent),
  );
}
