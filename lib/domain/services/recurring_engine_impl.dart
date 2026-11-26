import '../../core/failures.dart';
import '../../core/local_date.dart';
import '../../core/rupiah.dart';
import '../entities/recurring_occurrence.dart';
import '../entities/recurring_rule.dart';
import '../entities/transaction.dart';
import '../repositories/recurring_repository.dart';
import '../repositories/transaction_repository.dart';
import 'item_service.dart' show quietly;
import 'recurrence.dart';
import 'recurring_engine.dart';
import 'reminder_scheduler.dart';
import 'unit_of_work.dart';

/// Occurrences one rule may catch up on in one run (PRD 9.3).
const maxOccurrencesPerRun = 366;

/// PRD 9.3. Exactly-once rests on the unique (rule, date) occurrence index and
/// on each rule running in its own transaction.
class DefaultRecurringEngine implements RecurringEngine {
  const DefaultRecurringEngine({
    required this._rules,
    required this._transactions,
    required this._reminders,
    required this._unitOfWork,
  });

  final RecurringRepository _rules;
  final TransactionRepository _transactions;
  final ReminderScheduler _reminders;
  final UnitOfWork _unitOfWork;

  /// A rule that fails is rolled back and the others still run; the first
  /// failure is then rethrown.
  @override
  Future<CatchUpReport> catchUp(LocalDate today) async {
    var posted = 0;
    var pending = 0;
    (AppFailure, StackTrace)? failed;
    for (final due in await _rules.dueOnOrBefore(today)) {
      try {
        final done = await _unitOfWork.run(() => _catchUpRule(due.id, today));
        if (done == null) continue;
        posted += done.posted;
        pending += done.pending;
        await quietly(() => _reminders.scheduleRule(done.rule));
      } on AppFailure catch (e, s) {
        failed ??= (e, s);
      }
    }
    if (failed != null) Error.throwWithStackTrace(failed.$1, failed.$2);
    return CatchUpReport(posted: posted, pending: pending);
  }

  Future<({RecurringRule rule, int posted, int pending})?> _catchUpRule(
    String ruleId,
    LocalDate today,
  ) async {
    // Read again inside the transaction: another run may have moved it on.
    final rule = await _rules.find(ruleId);
    if (rule == null || rule.isPaused) return null;
    final end = rule.endDate;
    var next = rule.nextDueDate;
    var steps = 0;
    var posted = 0;
    var pending = 0;
    while (steps < maxOccurrencesPerRun &&
        !next.isAfter(today) &&
        (end == null || !next.isAfter(end))) {
      String? occurrence;
      try {
        occurrence = await _rules.insertOccurrence(ruleId, next);
      } on ConflictFailure {
        // This date was already handled.
      }
      if (occurrence != null) {
        if (rule.autoPost && await _tryPost(rule, occurrence, next)) {
          posted++;
        } else {
          pending++;
        }
      }
      next = advance(rule, next);
      steps++;
    }
    if (steps == 0) return null;
    await _rules.setNextDue(ruleId, next);
    return (
      rule: rule.copyWith(nextDueDate: next),
      posted: posted,
      pending: pending,
    );
  }

  /// False leaves the occurrence pending: an archived wallet, say, must not
  /// stall the rule, and the person can fix it from Needs confirmation.
  Future<bool> _tryPost(
    RecurringRule rule,
    String occurrenceId,
    LocalDate date,
  ) async {
    try {
      await _post(rule, occurrenceId, date, rule.amount);
      return true;
    } on ValidationFailure {
      return false;
    } on NotFoundFailure {
      return false;
    }
  }

  Future<String> _post(
    RecurringRule rule,
    String occurrenceId,
    LocalDate date,
    Rupiah amount,
  ) => _unitOfWork.run(() async {
    final transaction = await _transactions.create(
      TransactionInput(
        type: rule.type,
        amount: amount,
        walletId: rule.walletId,
        toWalletId: rule.toWalletId,
        categoryId: rule.categoryId,
        description: rule.description.isEmpty ? rule.name : rule.description,
        // 12:00 local on the occurrence date.
        occurredAt: DateTime(date.year, date.month, date.day, 12).toUtc(),
        occurredOn: date,
      ),
    );
    // Throws if it is no longer pending, which rolls the transaction back.
    await _rules.resolveOccurrence(
      occurrenceId,
      OccurrenceStatus.posted,
      transactionId: transaction.id,
    );
    return transaction.id;
  });

  @override
  LocalDate advance(RecurringRule rule, LocalDate from) =>
      advanceOccurrence(rule, from);

  @override
  Future<String> postPending(String occurrenceId, {Rupiah? amount}) async {
    // Outside the transaction: a watched query must not run inside one.
    final found = (await _rules.watchPending().first)
        .where((p) => p.occurrence.id == occurrenceId)
        .firstOrNull;
    if (found == null) {
      throw const ConflictFailure('occurrence is not pending');
    }
    final transactionId = await _post(
      found.rule,
      occurrenceId,
      found.occurrence.occurrenceDate,
      amount ?? found.rule.amount,
    );
    await _remind(found.rule.id);
    return transactionId;
  }

  @override
  Future<void> skipPending(String occurrenceId) async => _remind(
    await _rules.resolveOccurrence(occurrenceId, OccurrenceStatus.skipped),
  );

  @override
  Future<void> reopenOccurrence(
    String occurrenceId, {
    String? transactionId,
  }) async => _remind(
    await _unitOfWork.run(() async {
      if (transactionId != null) {
        await _transactions.softDelete(transactionId);
      }
      return _rules.resolveOccurrence(occurrenceId, OccurrenceStatus.pending);
    }),
  );

  /// Today's alarm follows its occurrence. Outside the transaction.
  Future<void> _remind(String ruleId) => quietly(() async {
    final rule = await _rules.find(ruleId);
    if (rule != null) await _reminders.scheduleRule(rule);
  });
}
