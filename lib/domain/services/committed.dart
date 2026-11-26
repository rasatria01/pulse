import '../../core/local_date.dart';
import '../../core/rupiah.dart';
import '../entities/action_item.dart';
import '../entities/recurring_occurrence.dart';
import '../entities/recurring_rule.dart';
import '../entities/transaction.dart';
import 'recurrence.dart';

/// C of PRD 9.4 as it stood at the start of [today]: bills plus outcome rules'
/// occurrences dated in [today, periodEnd].
///
/// [bills] is ActionItemRepository.watchCommitted and [occurrences] is
/// RecurringRepository.watchOccurrences over that window. An occurrence resolved
/// today still counts, so confirming it does not move today's target.
Rupiah committedAmount({
  required List<ActionItem> bills,
  required List<PendingOccurrence> occurrences,
  required List<RecurringRule> rules,
  required LocalDate today,
  required LocalDate periodEnd,
}) {
  var total = Rupiah.zero;
  for (final bill in bills) {
    total += bill.linkedAmount ?? Rupiah.zero;
  }
  final counted = <(String, LocalDate)>{};
  for (final found in occurrences) {
    if (found.rule.type != TxnType.outcome) continue;
    counted.add((found.rule.id, found.occurrence.occurrenceDate));
    total += found.rule.amount;
  }
  for (final rule in rules) {
    if (rule.type != TxnType.outcome || rule.isPaused) continue;
    final end = rule.endDate;
    final last = end != null && end.isBefore(periodEnd) ? end : periodEnd;
    for (
      var date = rule.nextDueDate;
      !date.isAfter(last);
      date = advanceOccurrence(rule, date)
    ) {
      if (!date.isBefore(today) && !counted.contains((rule.id, date))) {
        total += rule.amount;
      }
    }
  }
  return total;
}
