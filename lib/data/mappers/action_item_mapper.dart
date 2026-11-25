import '../../core/local_date.dart';
import '../../core/rupiah.dart';
import '../../domain/entities/action_item.dart';
import '../db/app_database.dart';
import 'column_values.dart';

extension ActionItemRowMapper on ActionItemRow {
  ActionItem toEntity({List<String> tagIds = const []}) {
    final due = dueDate;
    final start = scheduledStart;
    final end = scheduledEnd;
    final amount = linkedAmount;
    final bill = billStatus;
    final completed = completedAt;
    return ActionItem(
      id: id,
      title: title,
      body: body,
      status: ActionStatus.values.byName(status),
      priority: Priority.values[priority],
      dueDate: due == null ? null : LocalDate.parse(due),
      scheduledStart: start == null ? null : instant(start),
      scheduledEnd: end == null ? null : instant(end),
      reminderOffsetMin: reminderOffsetMin,
      notifId: notifId,
      linkedAmount: amount == null ? null : Rupiah(amount),
      linkedWalletId: linkedWalletId,
      linkedCategoryId: linkedCategoryId,
      billStatus: bill == null ? null : BillStatus.values.byName(bill),
      sourceNoteId: sourceNoteId,
      sourceBlockId: sourceBlockId,
      completedAt: completed == null ? null : instant(completed),
      tagIds: tagIds,
      isDeleted: isDeleted == 1,
      createdAt: instant(createdAt),
      updatedAt: instant(updatedAt),
    );
  }
}
