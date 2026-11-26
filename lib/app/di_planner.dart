// Providers owned by the tasks + calendar thread (F). Exported by di.dart.
// Names of shared lookups carry a `planner` prefix so they can't collide with
// another thread's exports.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/local_date.dart';
import '../domain/entities/action_item.dart';
import '../domain/entities/category.dart';
import '../domain/entities/recurring_occurrence.dart';
import '../domain/entities/tag.dart';
import '../domain/entities/wallet.dart';
import '../domain/repositories/settings_repository.dart';
import '../domain/services/bill_service_impl.dart';
import 'di.dart';

export '../domain/services/bill_service.dart';
export '../domain/services/item_service.dart';
export 'planner_flows.dart';

final itemServiceProvider = Provider<ItemService>(
  (ref) => ItemService(
    items: ref.watch(actionItemRepositoryProvider),
    tags: ref.watch(tagRepositoryProvider),
    transactions: ref.watch(transactionRepositoryProvider),
    settings: ref.watch(settingsRepositoryProvider),
    reminders: ref.watch(reminderSchedulerProvider),
    unitOfWork: ref.watch(unitOfWorkProvider),
    clock: ref.watch(clockProvider),
    notes: ref.watch(noteTaskSyncProvider),
  ),
);

final billServiceProvider = Provider<BillService>(
  (ref) => DefaultBillService(
    items: ref.watch(actionItemRepositoryProvider),
    tags: ref.watch(tagRepositoryProvider),
    wallets: ref.watch(walletRepositoryProvider),
    categories: ref.watch(categoryRepositoryProvider),
    transactions: ref.watch(transactionRepositoryProvider),
    reminders: ref.watch(reminderSchedulerProvider),
    unitOfWork: ref.watch(unitOfWorkProvider),
    clock: ref.watch(clockProvider),
    notes: ref.watch(noteTaskSyncProvider),
  ),
);

final inboxProvider = StreamProvider.autoDispose
    .family<List<ActionItem>, LocalDate>(
      (ref, day) => ref.watch(actionItemRepositoryProvider).watchInbox(day),
    );

/// Items scheduled inside [day]'s local day, earliest first.
final timelineProvider = StreamProvider.autoDispose
    .family<List<ActionItem>, LocalDate>(
      (ref, day) => ref
          .watch(actionItemRepositoryProvider)
          .watchScheduled(day.startUtc(), day.addDays(1).startUtc()),
    );

/// The Due lane: due on [day] and not already on that day's timeline.
final dueLaneProvider = StreamProvider.autoDispose
    .family<List<ActionItem>, LocalDate>(
      (ref, day) => ref
          .watch(actionItemRepositoryProvider)
          .watchDueOn(day)
          .map(
            (items) => [
              for (final item in items)
                if (item.scheduledStart == null ||
                    LocalDate.fromDateTime(item.scheduledStart!.toLocal()) !=
                        day)
                  item,
            ],
          ),
    );

/// Unscheduled items with one status, for the Tasks list.
final tasksProvider = StreamProvider.autoDispose
    .family<List<ActionItem>, ActionStatus>(
      (ref, status) => ref
          .watch(actionItemRepositoryProvider)
          .watchTasks(TaskFilter(statuses: {status})),
    );

final pendingBillsProvider = StreamProvider.autoDispose<List<ActionItem>>(
  (ref) => ref.watch(actionItemRepositoryProvider).watchPendingBills(),
);

final pendingOccurrencesProvider =
    StreamProvider.autoDispose<List<PendingOccurrence>>(
      (ref) => ref.watch(recurringRepositoryProvider).watchPending(),
    );

typedef NeedsConfirmation = ({
  List<ActionItem> bills,
  List<PendingOccurrence> occurrences,
});

final needsConfirmationProvider = Provider.autoDispose<NeedsConfirmation>(
  (ref) => (
    bills: ref.watch(pendingBillsProvider).value ?? const [],
    occurrences: ref.watch(pendingOccurrencesProvider).value ?? const [],
  ),
);

final plannerTagsProvider = StreamProvider.autoDispose<List<Tag>>(
  (ref) => ref.watch(tagRepositoryProvider).watchAll(),
);

final plannerWalletsProvider = StreamProvider.autoDispose<List<WalletBalance>>(
  (ref) => ref.watch(walletRepositoryProvider).watchAll(includeArchived: true),
);

final plannerOutcomeCategoriesProvider =
    StreamProvider.autoDispose<List<Category>>(
      (ref) => ref
          .watch(categoryRepositoryProvider)
          .watchAll(kind: CategoryKind.outcome),
    );

/// ISO weekday the calendar week starts on; Monday unless set.
final plannerWeekStartProvider = StreamProvider.autoDispose<int>(
  (ref) => ref
      .watch(settingsRepositoryProvider)
      .watch(SettingKeys.weekStart)
      .map((value) {
        final day = int.tryParse(value ?? '') ?? 1;
        return day >= 1 && day <= 7 ? day : 1;
      }),
);
