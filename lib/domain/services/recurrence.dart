import '../../core/local_date.dart';
import '../entities/recurring_rule.dart';

/// The occurrence after [from] (PRD 9.3). Pure; the caller applies endDate.
LocalDate advanceOccurrence(RecurringRule rule, LocalDate from) {
  final n = rule.interval;
  final start = rule.startDate;
  switch (rule.freq) {
    case RecurFreq.daily:
      return from.addDays(n);
    case RecurFreq.weekly:
      // The target weekday inside the Monday-based week N weeks on.
      final target = rule.byWeekday ?? start.weekday;
      return from.addDays(7 * n + target - from.weekday);
    case RecurFreq.monthly:
      // Clamped from the rule's day, not from.day, so 28 Feb goes back to 31.
      return from.monthOf.addMonths(n).day(rule.byMonthDay ?? start.day);
    case RecurFreq.yearly:
      return LocalMonth(from.year + n, start.month).day(start.day);
  }
}
