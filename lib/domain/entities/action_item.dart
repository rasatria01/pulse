import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/local_date.dart';
import '../../core/rupiah.dart';

part 'action_item.freezed.dart';

enum ActionStatus { open, done, cancelled }

/// Stored as 0–3.
enum Priority { none, low, med, high }

enum BillStatus { pending, recorded, skipped }

@freezed
abstract class ActionItem with _$ActionItem {
  const factory ActionItem({
    required String id,
    required String title,
    @Default('') String body,
    @Default(ActionStatus.open) ActionStatus status,
    @Default(Priority.none) Priority priority,
    LocalDate? dueDate,
    DateTime? scheduledStart, // UTC; null = lives in Tasks
    DateTime? scheduledEnd,
    int? reminderOffsetMin,
    int? notifId,
    Rupiah? linkedAmount,
    String? linkedWalletId,
    String? linkedCategoryId,
    BillStatus? billStatus,
    String? sourceNoteId,
    String? sourceBlockId,
    DateTime? completedAt,
    @Default(<String>[]) List<String> tagIds,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _ActionItem;
}

@freezed
abstract class ActionItemInput with _$ActionItemInput {
  const factory ActionItemInput({
    required String title,
    @Default('') String body,
    @Default(Priority.none) Priority priority,
    LocalDate? dueDate,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
    int? reminderOffsetMin,
    int? notifId,
    Rupiah? linkedAmount,
    String? linkedWalletId,
    String? linkedCategoryId,
    String? sourceNoteId, // set together with sourceBlockId
    String? sourceBlockId,
    String? rawInput,
  }) = _ActionItemInput;
}

/// Null field = unchanged. For a clearable column, `(value: null)` clears it.
@freezed
abstract class ActionItemPatch with _$ActionItemPatch {
  const factory ActionItemPatch({
    String? title,
    String? body,
    ActionStatus? status,
    Priority? priority,
    ({LocalDate? value})? dueDate,
    ({DateTime? value})? scheduledStart,
    ({DateTime? value})? scheduledEnd,
    ({int? value})? reminderOffsetMin,
    int? notifId,
    ({Rupiah? value})? linkedAmount,
    ({String? value})? linkedWalletId,
    ({String? value})? linkedCategoryId,
    ({BillStatus? value})? billStatus,
    ({DateTime? value})? completedAt,
  }) = _ActionItemPatch;
}

@freezed
abstract class TaskFilter with _$TaskFilter {
  const factory TaskFilter({
    @Default(<ActionStatus>{ActionStatus.open}) Set<ActionStatus> statuses,
    Priority? priority,
    String? tagId,
  }) = _TaskFilter;
}
