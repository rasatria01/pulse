// Providers owned by the budgets + recurring thread (H). Exported by di.dart.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/local_date.dart';
import '../core/rupiah.dart';
import '../data/repositories/budget_period.dart';
import '../domain/entities/budget.dart';
import '../domain/entities/recurring_rule.dart';
import '../domain/entities/transaction.dart';
import '../domain/repositories/settings_repository.dart';
import '../domain/services/committed.dart';
import '../domain/services/recurring_engine_impl.dart';
import 'di.dart';

export '../domain/services/finance_summary.dart';
export '../domain/services/recurring_engine.dart';
export '../domain/services/recurring_rule_service.dart';

final recurringEngineProvider = Provider<RecurringEngine>(
  (ref) => DefaultRecurringEngine(
    rules: ref.watch(recurringRepositoryProvider),
    transactions: ref.watch(transactionRepositoryProvider),
    reminders: ref.watch(reminderSchedulerProvider),
    unitOfWork: ref.watch(unitOfWorkProvider),
  ),
);

final recurringRuleServiceProvider = Provider<RecurringRuleService>(
  (ref) => RecurringRuleService(
    rules: ref.watch(recurringRepositoryProvider),
    engine: ref.watch(recurringEngineProvider),
    settings: ref.watch(settingsRepositoryProvider),
    reminders: ref.watch(reminderSchedulerProvider),
    unitOfWork: ref.watch(unitOfWorkProvider),
    clock: ref.watch(clockProvider),
  ),
);

final recurringRulesProvider = StreamProvider<List<RecurringRule>>(
  (ref) => ref.watch(recurringRepositoryProvider).watchRules(),
);

typedef BudgetPeriod = ({LocalMonth month, LocalDate from, LocalDate to});

/// The budget period today falls in, honouring budget_month_start_day.
final budgetPeriodProvider = StreamProvider<BudgetPeriod>((ref) {
  final today = ref.watch(todayProvider);
  return ref
      .watch(settingsRepositoryProvider)
      .watch(SettingKeys.budgetMonthStartDay)
      .map((startDay) {
        var month = today.monthOf;
        var (from, to) = budgetPeriod(month, startDay);
        if (today.isBefore(from)) {
          month = month.addMonths(-1);
          (from, to) = budgetPeriod(month, startDay);
        }
        return (month: month, from: from, to: to);
      });
});

/// A stream over the current period; stays loading until the period is known.
/// Not `await period.future`: disposing the scope (restore) while that is
/// loading throws an unhandled ProviderDisposedException.
Stream<T> _inPeriod<T>(Ref ref, Stream<T> Function(BudgetPeriod) watch) {
  final period = ref.watch(budgetPeriodProvider).value;
  return period == null ? Stream<T>.multi((_) {}) : watch(period);
}

/// The current period's categories that have a cap.
final budgetStatusesProvider = StreamProvider<List<BudgetStatus>>((ref) {
  final budgets = ref.watch(budgetRepositoryProvider);
  return _inPeriod(ref, (p) => budgets.watchMonth(p.month));
});

final _startDayProvider = StreamProvider<String?>(
  (ref) => ref
      .watch(settingsRepositoryProvider)
      .watch(SettingKeys.budgetMonthStartDay),
);

SummaryPeriod _summaryPeriod(LocalMonth month, String? startDay) {
  final (from, to) = budgetPeriod(month, startDay);
  return (month: month, from: from, to: to);
}

typedef MonthSummary = ({SummaryPeriod period, FinanceSummary summary});

/// The budget period [month] and the five before it.
final financeSummaryProvider = StreamProvider.autoDispose
    .family<MonthSummary, LocalMonth>((ref, month) {
      final today = ref.watch(todayProvider);
      final startDay = ref.watch(_startDayProvider);
      if (startDay.hasError) return Stream.error(startDay.error!);
      if (!startDay.hasValue) return Stream.multi((_) {});
      final periods = [
        for (var i = 5; i >= 0; i--)
          _summaryPeriod(month.addMonths(-i), startDay.value),
      ];
      return ref
          .watch(transactionRepositoryProvider)
          .watchRange(periods.first.from, periods.last.to)
          .map(
            (List<Transaction> transactions) => (
              period: periods.last,
              summary: summarize(transactions, periods, today),
            ),
          );
    });

/// The categories with a cap in budget period [month].
final monthBudgetsProvider = StreamProvider.autoDispose
    .family<List<BudgetStatus>, LocalMonth>(
      (ref, month) => ref.watch(budgetRepositoryProvider).watchMonth(month),
    );

final _spentBeforeTodayProvider = StreamProvider<Rupiah>((ref) {
  final today = ref.watch(todayProvider);
  final transactions = ref.watch(transactionRepositoryProvider);
  return _inPeriod(
    ref,
    (p) => transactions.watchOutcomeTotal(p.from, today.addDays(-1)),
  );
});

final _committedBillsProvider = StreamProvider((ref) {
  final today = ref.watch(todayProvider);
  final items = ref.watch(actionItemRepositoryProvider);
  return _inPeriod(
    ref,
    (p) => items.watchCommitted(today, p.to, doneSince: today.startUtc()),
  );
});

final _windowOccurrencesProvider = StreamProvider((ref) {
  final today = ref.watch(todayProvider);
  final recurring = ref.watch(recurringRepositoryProvider);
  return _inPeriod(ref, (p) => recurring.watchOccurrences(today, p.to));
});

final _unconfirmedProvider = StreamProvider(
  (ref) => ref.watch(recurringRepositoryProvider).watchPending(),
);

/// Everything safe-to-spend needs apart from today's spend (PRD 9.4).
typedef BudgetOutlook = ({
  Rupiah monthCaps,
  Rupiah spentBeforeToday,
  Rupiah committed,
  int daysLeft,
});

final budgetOutlookProvider = Provider<AsyncValue<BudgetOutlook>>((ref) {
  final today = ref.watch(todayProvider);
  final period = ref.watch(budgetPeriodProvider);
  final statuses = ref.watch(budgetStatusesProvider);
  final spent = ref.watch(_spentBeforeTodayProvider);
  final bills = ref.watch(_committedBillsProvider);
  final occurrences = ref.watch(_windowOccurrencesProvider);
  final rules = ref.watch(recurringRulesProvider);
  final pending = ref.watch(_unconfirmedProvider);
  for (final part in <AsyncValue<Object?>>[
    period,
    statuses,
    spent,
    bills,
    occurrences,
    rules,
    pending,
  ]) {
    if (part.hasError) return AsyncError(part.error!, part.stackTrace!);
    if (!part.hasValue) return const AsyncLoading();
  }
  final end = period.requireValue.to;
  return AsyncData((
    monthCaps: statuses.requireValue.fold(Rupiah.zero, (sum, s) => sum + s.cap),
    spentBeforeToday: spent.requireValue,
    committed: committedAmount(
      bills: bills.requireValue,
      occurrences: occurrences.requireValue,
      pending: pending.requireValue,
      rules: rules.requireValue,
      today: today,
      periodEnd: end,
    ),
    daysLeft: today.daysUntil(end) + 1,
  ));
});
