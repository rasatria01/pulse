import '../../core/clock.dart';
import '../../core/failures.dart';
import '../../core/local_date.dart';
import '../entities/action_item.dart';
import '../entities/category.dart';
import '../entities/transaction.dart';
import '../repositories/action_item_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/tag_repository.dart';
import '../repositories/transaction_repository.dart';
import '../repositories/wallet_repository.dart';
import 'bill_draft_builder.dart';
import 'bill_service.dart';
import 'item_service.dart';
import 'reminder_scheduler.dart';
import 'unit_of_work.dart';

/// PRD 9.1.
class DefaultBillService implements BillService {
  const DefaultBillService({
    required this._items,
    required this._tags,
    required this._wallets,
    required this._categories,
    required this._transactions,
    required this._reminders,
    required this._unitOfWork,
    required this._clock,
  });

  final ActionItemRepository _items;
  final TagRepository _tags;
  final WalletRepository _wallets;
  final CategoryRepository _categories;
  final TransactionRepository _transactions;
  final ReminderScheduler _reminders;
  final UnitOfWork _unitOfWork;
  final Clock _clock;

  @override
  Future<BillDraft?> draftFor(ActionItem item) async {
    final tags = await _tags.watchAll().first;
    if (!isBill(item, tags)) return null;
    final wallets = [
      for (final w in await _wallets.refs())
        if (!w.isArchived) w,
    ];
    final categories = [
      for (final c in await _categories.refs())
        if (c.kind == CategoryKind.outcome) c,
    ];
    if (wallets.isEmpty || categories.isEmpty) {
      throw const NotFoundFailure('no wallet or category for a bill');
    }
    String bySlug(String slug) => categories
        .firstWhere((c) => c.slug == slug, orElse: () => categories.first)
        .id;
    // An archived link takes no new transactions: fall back to the default.
    final linked = item.copyWith(
      linkedWalletId: wallets.any((w) => w.id == item.linkedWalletId)
          ? item.linkedWalletId
          : null,
      linkedCategoryId: categories.any((c) => c.id == item.linkedCategoryId)
          ? item.linkedCategoryId
          : null,
    );
    return buildBillDraft(
      linked,
      // A bill in flight stays one even if its tag was removed since.
      tagSlugs: const ['bill'],
      defaultWalletId: wallets
          .firstWhere((w) => w.isDefault, orElse: () => wallets.first)
          .id,
      billsCategoryId: bySlug('bills'),
      nowUtc: _clock.nowUtc(),
    );
  }

  /// One transaction per bill: a second confirm finds the first and adds none.
  @override
  Future<void> confirm(String actionItemId, BillDraft draft) async {
    final amount = draft.amount;
    if (amount == null || !amount.isPositive) {
      throw const ValidationFailure('amount must be above 0', field: 'amount');
    }
    await _close(actionItemId, (item, paid) async {
      if (!paid) {
        await _transactions.create(
          TransactionInput(
            type: TxnType.outcome,
            amount: amount,
            walletId: draft.walletId,
            categoryId: draft.categoryId,
            description: draft.description,
            occurredAt: draft.occurredAt,
            occurredOn: LocalDate.fromDateTime(draft.occurredAt.toLocal()),
            sourceActionItemId: actionItemId,
          ),
        );
      }
      return BillStatus.recorded;
    });
  }

  @override
  Future<void> defer(String actionItemId) => _close(
    actionItemId,
    (item, paid) async => paid ? BillStatus.recorded : BillStatus.pending,
  );

  @override
  Future<void> skip(String actionItemId) =>
      _close(actionItemId, (item, paid) async {
        if (paid) throw const ConflictFailure('this bill is already recorded');
        return BillStatus.skipped;
      });

  /// Marks the item done with the status [resolve] returns, all in one
  /// transaction, then cancels the alarm.
  Future<void> _close(
    String id,
    Future<BillStatus> Function(ActionItem item, bool paid) resolve,
  ) async {
    final item = await _unitOfWork.run(() async {
      final item =
          await _items.find(id) ?? (throw NotFoundFailure('action item $id'));
      final paid = await _transactions.findBySourceActionItem(id) != null;
      final status = await resolve(item, paid);
      return _items.update(
        id,
        ActionItemPatch(
          status: ActionStatus.done,
          completedAt: (value: item.completedAt ?? _clock.nowUtc()),
          billStatus: (value: status),
        ),
      );
    });
    await syncReminder(_reminders, item);
  }
}
