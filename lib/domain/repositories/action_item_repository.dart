import '../../core/local_date.dart';
import '../entities/action_item.dart';

abstract interface class ActionItemRepository {
  Stream<List<ActionItem>> watchInbox(LocalDate today);
  Stream<List<ActionItem>> watchScheduled(DateTime fromUtc, DateTime toUtc);
  Stream<List<ActionItem>> watchDueOn(LocalDate day);
  Stream<List<ActionItem>> watchTasks(TaskFilter filter);
  Stream<List<ActionItem>> watchPendingBills();

  /// Items with an amount, owed by [to] (overdue ones included), that are open
  /// or were completed at or after [doneSince], and not paid before [from]:
  /// safe-to-spend's committed bills. Bills pending confirmation are included
  /// whatever their status date or due date.
  Stream<List<ActionItem>> watchCommitted(
    LocalDate from,
    LocalDate to, {
    required DateTime doneSince,
  });
  Future<ActionItem?> find(String id);
  Future<List<ActionItem>> findBySourceNote(
    String noteId, {
    bool includeDeleted = false,
  });
  Future<List<ActionItem>> withFutureReminders(DateTime fromUtc);
  Future<ActionItem> create(ActionItemInput input);
  Future<ActionItem> update(String id, ActionItemPatch patch);
  Future<void> softDelete(String id);
  Future<void> undelete(String id);
}
