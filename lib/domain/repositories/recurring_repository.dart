import '../../core/local_date.dart';
import '../entities/recurring_occurrence.dart';
import '../entities/recurring_rule.dart';

abstract interface class RecurringRepository {
  Stream<List<RecurringRule>> watchRules();
  Stream<List<PendingOccurrence>> watchPending();

  /// Occurrences dated in [from, to], resolved ones included.
  Stream<List<PendingOccurrence>> watchOccurrences(
    LocalDate from,
    LocalDate to,
  );
  Future<List<RecurringRule>> dueOnOrBefore(LocalDate day);
  Future<RecurringRule?> find(String id);
  Future<void> softDelete(String id);
  Future<RecurringRule> create(RecurringRuleInput input);
  Future<RecurringRule> update(String id, RecurringRulePatch patch);

  /// Returns the occurrence id. Throws ConflictFailure if (ruleId, date) exists.
  Future<String> insertOccurrence(
    String ruleId,
    LocalDate date, {
    String? transactionId,
  });
  Future<void> resolveOccurrence(
    String occurrenceId,
    OccurrenceStatus status, {
    String? transactionId,
  });
  Future<void> setNextDue(String ruleId, LocalDate next);
}
