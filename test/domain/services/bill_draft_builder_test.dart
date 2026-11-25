import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/rupiah.dart';
import 'package:pulse/domain/entities/action_item.dart';
import 'package:pulse/domain/services/bill_draft_builder.dart';
import 'package:pulse/domain/services/bill_service.dart';

final _now = DateTime.utc(2026, 11, 25, 3);

ActionItem _item({Rupiah? amount, String? walletId, String? categoryId}) =>
    ActionItem(
      id: 'a',
      title: 'Pay internet bill',
      linkedAmount: amount,
      linkedWalletId: walletId,
      linkedCategoryId: categoryId,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

BillDraft? _draft(ActionItem item, [List<String> slugs = const []]) =>
    buildBillDraft(
      item,
      tagSlugs: slugs,
      defaultWalletId: 'cash',
      billsCategoryId: 'bills',
      nowUtc: _now,
    );

void main() {
  test('linked values win over the defaults', () {
    final item = _item(
      amount: const Rupiah(350000),
      walletId: 'bca',
      categoryId: 'net',
    );
    expect(
      _draft(item),
      BillDraft(
        amount: const Rupiah(350000),
        walletId: 'bca',
        categoryId: 'net',
        description: 'Pay internet bill',
        occurredAt: _now,
      ),
    );
  });

  test('#bill alone leaves the amount empty and uses the defaults', () {
    expect(
      _draft(_item(), ['home', 'bill']),
      BillDraft(
        walletId: 'cash',
        categoryId: 'bills',
        description: 'Pay internet bill',
        occurredAt: _now,
      ),
    );
  });

  test('neither amount nor #bill is not a bill', () {
    expect(_draft(_item(walletId: 'bca'), ['billing']), isNull);
  });
}
