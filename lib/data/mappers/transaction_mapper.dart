import '../../core/local_date.dart';
import '../../core/rupiah.dart';
import '../../domain/entities/transaction.dart';
import '../db/app_database.dart';
import 'column_values.dart';

/// The column stores INCOME, OUTCOME, TRANSFER.
String txnTypeColumn(TxnType type) => type.name.toUpperCase();

extension TransactionRowMapper on TransactionRow {
  Transaction toEntity({List<String> tagIds = const []}) => Transaction(
    id: id,
    type: TxnType.values.byName(type.toLowerCase()),
    amount: Rupiah(amount),
    walletId: walletId,
    toWalletId: toWalletId,
    categoryId: categoryId,
    description: description,
    occurredAt: instant(occurredAt),
    occurredOn: LocalDate.parse(occurredOn),
    parentTransactionId: parentTransactionId,
    sourceActionItemId: sourceActionItemId,
    tagIds: tagIds,
    createdAt: instant(createdAt),
    updatedAt: instant(updatedAt),
  );
}
