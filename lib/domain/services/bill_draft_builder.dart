import '../entities/action_item.dart';
import 'bill_service.dart';

/// Sheet pre-fill (PRD 9.1). Null when the item is not a bill: no linked
/// amount and no #bill tag. BillService.draftFor does the lookups.
BillDraft? buildBillDraft(
  ActionItem item, {
  required Iterable<String> tagSlugs,
  required String defaultWalletId,
  required String billsCategoryId,
  required DateTime nowUtc,
}) {
  if (item.linkedAmount == null && !tagSlugs.contains('bill')) return null;
  return BillDraft(
    amount: item.linkedAmount,
    walletId: item.linkedWalletId ?? defaultWalletId,
    categoryId: item.linkedCategoryId ?? billsCategoryId,
    description: item.title,
    occurredAt: nowUtc,
  );
}
