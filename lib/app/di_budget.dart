// Providers owned by the budgets + recurring thread (H). Exported by di.dart.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/local_date.dart';
import '../core/rupiah.dart';
import '../data/repositories/budget_period.dart';
import '../domain/entities/budget.dart';
import '../domain/entities/recurring_rule.dart';
import '../domain/repositories/settings_repository.dart';
import '../domain/services/committed.dart';
import '../domain/services/recurring_engine_impl.dart';
import 'di.dart';

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

/// The current period's categories that have a cap.
final budgetStatusesProvider = StreamProvider<List<BudgetStatus>>((ref) async* {
  final budgets = ref.watch(budgetRepositoryProvider);
  final period = await ref.watch(budgetPeriodProvider.future);
  yield* budgets.watchMonth(period.month);
});

final _spentBeforeTodayProvider = StreamProvider<Rupiah>((ref) async* {
  final today = ref.watch(todayProvider);
  final transactions = ref.watch(transactionRepositoryProvider);
  final period = await ref.watch(budgetPeriodProvider.future);
  yield* transactions.watchOutcomeTotal(period.from, today.addDays(-1));
});

final _committedBillsProvider = StreamProvider((ref) async* {
  final today = ref.watch(todayProvider);
  final items = ref.watch(actionItemRepositoryProvider);
  final period = await ref.watch(budgetPeriodProvider.future);
  yield* items.watchCommitted(today, period.to, doneSince: today.startUtc());
});

final _windowOccurrencesProvider = StreamProvider((ref) async* {
  final today = ref.watch(todayProvider);
  final recurring = ref.watch(recurringRepositoryProvider);
  final period = await ref.watch(budgetPeriodProvider.future);
  yield* recurring.watchOccurrences(today, period.to);
});

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
  for (final part in <AsyncValue<Object?>>[
    period,
    statuses,
    spent,
    bills,
    occurrences,
    rules,
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
      rules: rules.requireValue,
      today: today,
      periodEnd: end,
    ),
    daysLeft: today.daysUntil(end) + 1,
  ));
});
