import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/local_date.dart';
import '../../core/rupiah.dart';

part 'transaction.freezed.dart';

/// Stored uppercase: INCOME, OUTCOME, TRANSFER.
enum TxnType { income, outcome, transfer }

@freezed
abstract class Transaction with _$Transaction {
  const factory Transaction({
    required String id,
    required TxnType type,
    required Rupiah amount,
    required String walletId,
    String? toWalletId,
    String? categoryId,
    @Default('') String description,
    required DateTime occurredAt, // UTC
    required LocalDate occurredOn,
    String? parentTransactionId,
    String? sourceActionItemId,
    @Default(<String>[]) List<String> tagIds,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Transaction;
}

/// Used for both create and full update. Tags go through TagRepository.
@freezed
abstract class TransactionInput with _$TransactionInput {
  const factory TransactionInput({
    required TxnType type,
    required Rupiah amount,
    required String walletId,
    String? toWalletId,
    String? categoryId,
    @Default('') String description,
    required DateTime occurredAt, // UTC
    required LocalDate occurredOn,
    String? parentTransactionId,
    String? sourceActionItemId,
    String? rawInput,
  }) = _TransactionInput;
}
