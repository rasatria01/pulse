import '../../core/clock.dart';
import '../../core/failures.dart';
import '../entities/action_item.dart';
import '../entities/tag.dart';
import '../repositories/action_item_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/tag_repository.dart';
import '../repositories/transaction_repository.dart';
import 'reminder_scheduler.dart';
import 'unit_of_work.dart';

/// Makes the alarm match [item]: scheduled while it is open and has a time or a
/// due date, cancelled otherwise.
Future<void> syncReminder(ReminderScheduler reminders, ActionItem item) async {
  final id = item.notifId;
  if (id == null) return;
  final wanted =
      item.status == ActionStatus.open &&
      (item.scheduledStart != null || item.dueDate != null);
  await quietly(
    () => wanted ? reminders.scheduleItem(item) : reminders.cancel(id),
  );
}

/// Runs an alarm call that follows a committed write. The write stands even if
/// the platform refuses: ReminderScheduler.resyncAll repairs alarms later.
Future<void> quietly(Future<void> Function() alarm) async {
  try {
    await alarm();
  } catch (_) {}
}

/// Create, edit, complete, reopen and delete of action items (PRD F4), with
/// their reminders. Bill confirmation is BillService.
class ItemService {
  const ItemService({
    required this._items,
    required this._tags,
    required this._transactions,
    required this._settings,
    required this._reminders,
    required this._unitOfWork,
    required this._clock,
  });

  final ActionItemRepository _items;
  final TagRepository _tags;
  final TransactionRepository _transactions;
  final SettingsRepository _settings;
  final ReminderScheduler _reminders;
  final UnitOfWork _unitOfWork;
  final Clock _clock;

  Future<ActionItem> create(
    ActionItemInput input, {
    List<String> tagSlugs = const [],
  }) async {
    final item = await _unitOfWork.run(() async {
      final anchored = input.scheduledStart != null || input.dueDate != null;
      final created = await _items.create(
        anchored && input.notifId == null
            ? input.copyWith(notifId: await _settings.nextNotificationId())
            : input,
      );
      await _setTags(created.id, tagSlugs);
      return _require(created.id);
    });
    await syncReminder(_reminders, item);
    return item;
  }

  /// Writes the fields the edit form owns: title, priority, due date, schedule
  /// and reminder offset. A null [tagSlugs] keeps the tags.
  Future<ActionItem> edit(
    String id,
    ActionItemInput input, {
    List<String>? tagSlugs,
  }) => _change(
    id,
    ActionItemPatch(
      title: input.title,
      priority: input.priority,
      dueDate: (value: input.dueDate),
      scheduledStart: (value: input.scheduledStart),
      scheduledEnd: (value: input.scheduledEnd),
      reminderOffsetMin: (value: input.reminderOffsetMin),
    ),
    tagSlugs: tagSlugs,
  );

  Future<ActionItem> schedule(String id, DateTime start, {DateTime? end}) =>
      _change(
        id,
        ActionItemPatch(
          scheduledStart: (value: start),
          scheduledEnd: (value: end),
        ),
      );

  /// Marks the item done without a payment. A bill is left pending (or recorded
  /// if its payment already exists), so it can't silently disappear (PRD 9.1).
  Future<void> complete(String id) async {
    // Outside the transaction: a watched query must not run inside one.
    final tags = await _tags.watchAll().first;
    final item = await _unitOfWork.run(() async {
      final item = await _require(id);
      if (item.status == ActionStatus.done) return item;
      BillStatus? bill;
      if (isBill(item, tags)) {
        bill = await _transactions.findBySourceActionItem(id) == null
            ? BillStatus.pending
            : BillStatus.recorded;
      }
      return _items.update(
        id,
        ActionItemPatch(
          status: ActionStatus.done,
          completedAt: (value: _clock.nowUtc()),
          billStatus: (value: bill),
        ),
      );
    });
    await syncReminder(_reminders, item);
    // TODO(F5): NoteTaskSync.onItemChanged for items with a source note.
  }

  /// [deleteTransaction] also removes the bill's recorded payment, atomically.
  Future<void> reopen(String id, {bool deleteTransaction = false}) async {
    final item = await _unitOfWork.run(() async {
      await _require(id);
      if (deleteTransaction) {
        var paid = await _transactions.findBySourceActionItem(id);
        while (paid != null) {
          await _transactions.softDelete(paid.id);
          paid = await _transactions.findBySourceActionItem(id);
        }
      }
      return _write(
        id,
        const ActionItemPatch(
          status: ActionStatus.open,
          completedAt: (value: null),
          billStatus: (value: null),
        ),
      );
    });
    await syncReminder(_reminders, item);
  }

  /// Soft delete; [restore] is the snackbar's Undo. A payment stays.
  Future<void> delete(String id) async {
    final item = await _require(id);
    await _items.softDelete(id);
    final notifId = item.notifId;
    if (notifId != null) await quietly(() => _reminders.cancel(notifId));
  }

  Future<void> restore(String id) async {
    await _items.undelete(id);
    await syncReminder(_reminders, await _require(id));
  }

  Future<ActionItem> _change(
    String id,
    ActionItemPatch patch, {
    List<String>? tagSlugs,
  }) async {
    final item = await _unitOfWork.run(() async {
      await _require(id);
      await _write(id, patch);
      if (tagSlugs != null) await _setTags(id, tagSlugs);
      return _require(id);
    });
    await syncReminder(_reminders, item);
    return item;
  }

  /// Updates, then hands out an alarm id if the item now needs one.
  Future<ActionItem> _write(String id, ActionItemPatch patch) async {
    final item = await _items.update(id, patch);
    final anchored = item.scheduledStart != null || item.dueDate != null;
    if (!anchored || item.notifId != null) return item;
    return _items.update(
      id,
      ActionItemPatch(notifId: await _settings.nextNotificationId()),
    );
  }

  Future<void> _setTags(String id, List<String> slugs) async {
    final tags = await _tags.ensure(slugs);
    await _tags.setTags(EntityType.actionItem, id, [
      for (final t in tags) t.id,
    ]);
  }

  Future<ActionItem> _require(String id) async =>
      await _items.find(id) ?? (throw NotFoundFailure('action item $id'));
}

/// A linked amount, the #bill tag, or a bill already in flight (PRD 9.1).
bool isBill(ActionItem item, List<Tag> tags) =>
    item.billStatus != null ||
    item.linkedAmount != null ||
    tags.any((t) => t.slug == 'bill' && item.tagIds.contains(t.id));
