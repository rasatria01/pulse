import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/rupiah.dart';
import '../entities/action_item.dart';

part 'bill_service.freezed.dart';

/// Pre-fill of the confirmation sheet (PRD 9.1).
@freezed
abstract class BillDraft with _$BillDraft {
  const factory BillDraft({
    Rupiah? amount, // empty when the item only has #bill
    required String walletId,
    required String categoryId,
    required String description,
    required DateTime occurredAt, // UTC
  }) = _BillDraft;
}

abstract interface class BillService {
  BillDraft? draftFor(ActionItem item); // null when the item is not a bill
  Future<void> confirm(String actionItemId, BillDraft draft); // atomic
  Future<void> defer(String actionItemId); // done + bill_status pending
  Future<void> skip(String actionItemId); // done + bill_status skipped
}
