import '../../core/local_date.dart';
import '../../core/rupiah.dart';
import '../../domain/entities/recurring_occurrence.dart';
import '../../domain/entities/recurring_rule.dart';
import '../../domain/entities/transaction.dart';
import '../db/app_database.dart';
import 'column_values.dart';

extension RecurringRuleRowMapper on RecurringRuleRow {
  RecurringRule toEntity() {
    final end = endDate;
    return RecurringRule(
      id: id,
      name: name,
      type: TxnType.values.byName(type.toLowerCase()),
      amount: Rupiah(amount),
      walletId: walletId,
      toWalletId: toWalletId,
      categoryId: categoryId,
      description: description,
      freq: RecurFreq.values.byName(freq),
      interval: intervalN,
      byWeekday: byWeekday,
      byMonthDay: byMonthDay,
      startDate: LocalDate.parse(startDate),
      endDate: end == null ? null : LocalDate.parse(end),
      nextDueDate: LocalDate.parse(nextDueDate),
      autoPost: autoPost == 1,
      isPaused: isPaused == 1,
      notifId: notifId,
      createdAt: instant(createdAt),
      updatedAt: instant(updatedAt),
    );
  }
}

extension RecurringOccurrenceRowMapper on RecurringOccurrenceRow {
  RecurringOccurrence toEntity() => RecurringOccurrence(
    id: id,
    ruleId: ruleId,
    occurrenceDate: LocalDate.parse(occurrenceDate),
    status: OccurrenceStatus.values.byName(status),
    transactionId: transactionId,
    createdAt: instant(createdAt),
    updatedAt: instant(updatedAt),
  );
}
