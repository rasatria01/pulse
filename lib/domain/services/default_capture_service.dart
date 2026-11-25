import '../../core/failures.dart';
import '../../core/local_date.dart';
import '../../core/rupiah.dart';
import '../entities/action_item.dart';
import '../entities/note.dart';
import '../entities/search.dart';
import '../entities/tag.dart';
import '../entities/transaction.dart';
import '../parser/parse_result.dart';
import '../repositories/action_item_repository.dart';
import '../repositories/note_repository.dart';
import '../repositories/search_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/tag_repository.dart';
import '../repositories/transaction_repository.dart';
import 'capture_service.dart';
import 'reminder_scheduler.dart';
import 'unit_of_work.dart';

final class DefaultCaptureService implements CaptureService {
  DefaultCaptureService({
    required this.unitOfWork,
    required this.transactions,
    required this.actionItems,
    required this.notes,
    required this.tags,
    required this.search,
    required this.settings,
    required this.reminders,
  });

  final UnitOfWork unitOfWork;
  final TransactionRepository transactions;
  final ActionItemRepository actionItems;
  final NoteRepository notes;
  final TagRepository tags;
  final SearchRepository search;
  final SettingsRepository settings;
  final ReminderScheduler reminders;

  @override
  Future<CaptureOutcome> commit(ParseResult draft) async {
    if (!draft.canSave) {
      throw const ValidationFailure('the draft has blocking issues');
    }
    final known = {for (final tag in await tags.watchAll().first) tag.id};
    ActionItem? reminded;
    final outcome = await unitOfWork.run(() async {
      final EntityType type;
      final String id;
      final List<String> slugs;
      switch (draft) {
        case TransactionDraft d:
          type = EntityType.transaction;
          id = (await transactions.create(_transaction(d))).id;
          slugs = d.tagSlugs;
        case ActionItemDraft d:
          type = EntityType.actionItem;
          final item = await actionItems.create(await _actionItem(d));
          if (item.notifId != null) reminded = item;
          id = item.id;
          slugs = d.tagSlugs;
        case NoteDraft d:
          type = EntityType.note;
          id = (await notes.create(NoteInput(title: d.title, body: d.body))).id;
          slugs = d.tagSlugs;
      }
      if (slugs.isEmpty) return CaptureOutcome(type: type, entityId: id);
      final used = await tags.ensure(slugs);
      await tags.setTags(type, id, [for (final tag in used) tag.id]);
      return CaptureOutcome(
        type: type,
        entityId: id,
        createdTagIds: [
          for (final tag in used)
            if (!known.contains(tag.id)) tag.id,
        ],
      );
    });
    // After the commit: an alarm cannot be rolled back.
    final item = reminded;
    if (item != null) await _quietly(() => reminders.scheduleItem(item));
    return outcome;
  }

  @override
  Future<void> undo(CaptureOutcome outcome) async {
    final all = await tags.watchAll().first;
    final id = outcome.entityId;
    int? notifId;
    await unitOfWork.run(() async {
      switch (outcome.type) {
        case EntityType.transaction:
          await transactions.softDelete(id);
        case EntityType.actionItem:
          notifId = (await actionItems.find(id))?.notifId;
          await actionItems.softDelete(id);
        case EntityType.note:
          await notes.softDelete(id);
      }
      await tags.setTags(outcome.type, id, const []);
      for (final tag in all) {
        if (!outcome.createdTagIds.contains(tag.id)) continue;
        // Search lists only live entities, so no hit means orphaned.
        final hits = await search.search(
          SearchQuery(tagSlugs: [tag.slug]),
          limit: 1,
        );
        if (hits.isEmpty) await tags.softDelete(tag.id);
      }
    });
    final alarm = notifId;
    if (alarm != null) await _quietly(() => reminders.cancel(alarm));
  }

  /// The write has happened; failing here would make the user save it twice.
  /// resyncAll() on the next start repairs the alarms.
  Future<void> _quietly(Future<void> Function() body) async {
    try {
      await body();
    } on Exception catch (_) {}
  }

  TransactionInput _transaction(TransactionDraft d) => TransactionInput(
    type: d.type,
    amount: Rupiah(d.amount!),
    walletId: d.walletId!,
    toWalletId: d.toWalletId,
    categoryId: d.categoryId,
    description: d.description,
    occurredAt: d.occurredAt.toUtc(),
    occurredOn: LocalDate.fromDateTime(d.occurredAt),
    rawInput: d.raw,
  );

  Future<ActionItemInput> _actionItem(ActionItemDraft d) async {
    final amount = d.linkedAmount;
    final timed = d.scheduledStart != null || d.dueDate != null;
    return ActionItemInput(
      title: d.title,
      priority: d.priority,
      dueDate: d.dueDate,
      scheduledStart: d.scheduledStart?.toUtc(),
      scheduledEnd: d.scheduledEnd?.toUtc(),
      notifId: timed ? await settings.nextNotificationId() : null,
      linkedAmount: amount == null ? null : Rupiah(amount),
      linkedWalletId: d.linkedWalletId,
      linkedCategoryId: d.linkedCategoryId,
      rawInput: d.raw,
    );
  }
}
