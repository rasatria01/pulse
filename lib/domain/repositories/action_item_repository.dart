import '../../core/local_date.dart';
import '../entities/action_item.dart';

abstract interface class ActionItemRepository {
  Stream<List<ActionItem>> watchInbox(LocalDate today);
  Stream<List<ActionItem>> watchScheduled(DateTime fromUtc, DateTime toUtc);
  Stream<List<ActionItem>> watchDueOn(LocalDate day);
  Stream<List<ActionItem>> watchTasks(TaskFilter filter);
  Stream<List<ActionItem>> watchPendingBills();
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
