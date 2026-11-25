// The steps behind a tap on an item or bill: sheets from ui/, writes through the
// services, Undo. Here because Tasks, Calendar and Today all run them and
// features can't import each other. Exported by di.dart.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:shad/shad.dart';

import '../core/failures.dart';
import '../core/local_date.dart';
import '../domain/entities/action_item.dart';
import '../domain/entities/category.dart';
import '../ui/planner/bill_sheet.dart';
import '../ui/planner/item_sheet.dart';
import '../ui/planner/planner_strings.dart';
import '../ui/planner/schedule_sheet.dart';
import '../ui/widgets/widgets.dart';
import 'di.dart';

/// Built from the tapped widget, but holds only the app-level context and
/// container: the row that started a flow may leave its list mid-way.
class PlannerFlows {
  PlannerFlows.of(BuildContext context)
    : _context = Navigator.of(context, rootNavigator: true).context,
      _read = ProviderScope.containerOf(context, listen: false).read;

  final BuildContext _context;
  final T Function<T>(ProviderListenable<T>) _read;

  // A second tap while a flow is open does nothing.
  static final _busy = <String>{};

  ItemService get _items => _read(itemServiceProvider);
  BillService get _bills => _read(billServiceProvider);
  LocalDate get _today => _read(todayProvider);

  Future<void> create({LocalDate? scheduleOn}) => _run('new', () async {
    final result = await showPSheet<ItemSheetResult>(
      context: _context,
      builder: (_) => ItemSheet(today: _today, scheduleOn: scheduleOn),
    );
    if (result == null) return;
    await _items.create(result.values, tagSlugs: result.tagSlugs);
  });

  Future<void> open(ActionItem item) async {
    ItemSheetResult? result;
    await _run(item.id, () async {
      final tags = await _read(tagRepositoryProvider).watchAll().first;
      if (!_context.mounted) return;
      result = await showPSheet<ItemSheetResult>(
        context: _context,
        builder: (_) => ItemSheet(
          today: _today,
          item: item,
          tagSlugs: [
            for (final t in tags)
              if (item.tagIds.contains(t.id)) t.slug,
          ],
        ),
      );
      final chosen = result;
      if (chosen != null && chosen.action != ItemSheetAction.delete) {
        await _items.edit(item.id, chosen.values, tagSlugs: chosen.tagSlugs);
      }
    });
    switch (result?.action) {
      case ItemSheetAction.delete:
        await delete(item);
      case ItemSheetAction.toggleDone:
        // Re-read: the edit may have made it a bill, or changed its title.
        final saved = await _read(actionItemRepositoryProvider).find(item.id);
        if (saved != null) await toggle(saved);
      case ItemSheetAction.save || null:
        break;
    }
  }

  Future<void> toggle(ActionItem item) =>
      item.status == ActionStatus.done ? reopen(item) : complete(item);

  /// A bill opens the confirmation sheet; dismissing it defers (PRD 9.1).
  Future<void> complete(ActionItem item) => _run(item.id, () async {
    final draft = await _bills.draftFor(item);
    final paid = draft == null
        ? null
        : await _read(transactionRepositoryProvider)
              .findBySourceActionItem(item.id);
    if (draft == null || paid != null) {
      await _items.complete(item.id);
      _snack(
        PlannerStrings.completed(item.title),
        () => _items.reopen(item.id),
      );
      return;
    }
    await _billSheet(item, draft, pending: false);
  });

  /// Needs confirmation: records the pre-filled payment, or asks when there is
  /// no amount.
  Future<void> confirmPending(ActionItem item) => _run(item.id, () async {
    final draft = await _bills.draftFor(item);
    if (draft == null) return;
    if (draft.amount == null) {
      await _billSheet(item, draft, pending: true);
    } else {
      await _record(item, draft, pending: true);
    }
  });

  Future<void> editPending(ActionItem item) => _run(item.id, () async {
    final draft = await _bills.draftFor(item);
    if (draft != null) await _billSheet(item, draft, pending: true);
  });

  Future<void> skipPending(ActionItem item) =>
      _run(item.id, () => _skip(item, pending: true));

  Future<void> reopen(ActionItem item) => _run(item.id, () async {
    final paid = await _read(transactionRepositoryProvider)
        .findBySourceActionItem(item.id);
    var deletePayment = false;
    if (paid != null) {
      if (!_context.mounted) return;
      final answer = await showPSheet<bool>(
        context: _context,
        builder: (_) => ReopenBillSheet(amount: paid.amount),
      );
      if (answer == null) return;
      deletePayment = answer;
    }
    await _items.reopen(item.id, deleteTransaction: deletePayment);
  });

  Future<void> schedule(ActionItem item) => _run(item.id, () async {
    final slot = await showPSheet<Slot>(
      context: _context,
      builder: (_) => ScheduleSheet(title: item.title, today: _today),
    );
    if (slot == null) return;
    await _items.schedule(item.id, slot.start, end: slot.end);
    _snack(
      PlannerStrings.scheduled(item.title),
      () => _items.edit(
        item.id,
        ActionItemInput(
          title: item.title,
          priority: item.priority,
          dueDate: item.dueDate,
          scheduledStart: item.scheduledStart,
          scheduledEnd: item.scheduledEnd,
          reminderOffsetMin: item.reminderOffsetMin,
        ),
      ),
    );
  });

  Future<void> delete(ActionItem item) => _run(item.id, () async {
    await _items.delete(item.id);
    _snack(PlannerStrings.deleted(item.title), () => _items.restore(item.id));
  });

  // TODO(wave 3): confirm, edit and skip a recurring occurrence with BillSheet
  // and RecurringEngine.postPending / skipPending. Until then, only say so.
  void recurringNotReady() => _toast(PlannerStrings.recurringLater);

  Future<void> _billSheet(
    ActionItem item,
    BillDraft draft, {
    required bool pending,
  }) async {
    final balances = await _read(walletRepositoryProvider).watchAll().first;
    final categories = await _read(categoryRepositoryProvider)
        .watchAll(kind: CategoryKind.outcome)
        .first;
    if (!_context.mounted) return;
    final result = await showPSheet<BillSheetResult>(
      context: _context,
      builder: (_) => BillSheet(
        wallets: [for (final b in balances) b.wallet],
        categories: categories,
        amount: draft.amount,
        walletId: draft.walletId,
        categoryId: draft.categoryId,
        description: draft.description,
      ),
    );
    switch (result) {
      case BillConfirmed():
        await _record(
          item,
          draft.copyWith(
            amount: result.amount,
            walletId: result.walletId,
            categoryId: result.categoryId,
            description: result.description,
            occurredAt: _read(clockProvider).nowUtc(),
          ),
          pending: pending,
        );
      case BillSkipped():
        await _skip(item, pending: pending);
      case null:
        if (pending) return;
        await _bills.defer(item.id);
        _snack(
          PlannerStrings.deferred(item.title),
          () => _items.reopen(item.id),
        );
    }
  }

  Future<void> _record(
    ActionItem item,
    BillDraft draft, {
    required bool pending,
  }) async {
    await _bills.confirm(item.id, draft);
    final wallets = await _read(walletRepositoryProvider).watchAll().first;
    final wallet = [
      for (final b in wallets)
        if (b.wallet.id == draft.walletId) b.wallet.name,
    ].join();
    _snack(
      PlannerStrings.recorded(formatRupiah(draft.amount!), wallet),
      () async {
        await _items.reopen(item.id, deleteTransaction: true);
        if (pending) await _bills.defer(item.id);
      },
    );
  }

  Future<void> _skip(ActionItem item, {required bool pending}) async {
    await _bills.skip(item.id);
    _snack(
      PlannerStrings.skipped(item.title),
      () => pending ? _bills.defer(item.id) : _items.reopen(item.id),
    );
  }

  Future<void> _run(String key, Future<void> Function() body) async {
    if (!_busy.add(key)) return;
    try {
      await body();
    } on AppFailure {
      _toast(PlannerStrings.failed);
    } finally {
      _busy.remove(key);
    }
  }

  void _snack(String message, Future<void> Function() undo) {
    if (!_context.mounted) return;
    showPSnackbar(_context, message: message, onUndo: () => _run('undo', undo));
  }

  void _toast(String message) {
    if (!_context.mounted) return;
    ShadToaster.of(_context).show(ShadToast(description: Text(message)));
  }
}
