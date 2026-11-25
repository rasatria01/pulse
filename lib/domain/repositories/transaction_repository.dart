import '../../core/local_date.dart';
import '../../core/rupiah.dart';
import '../entities/transaction.dart';

abstract interface class TransactionRepository {
  Stream<List<Transaction>> watchDay(LocalDate day);
  Stream<List<Transaction>> watchRange(
    LocalDate from,
    LocalDate to, {
    String? walletId,
    String? categoryId,
  });
  Stream<Rupiah> watchOutcomeTotal(
    LocalDate from,
    LocalDate to,
  ); // no transfers
  Stream<Map<String, Rupiah>> watchOutcomeByCategory(LocalMonth month);
  Future<Transaction?> find(String id);
  Future<Transaction?> findBySourceActionItem(String actionItemId);
  Future<Transaction> create(TransactionInput input);
  Future<Transaction> update(String id, TransactionInput input);
  Future<void> softDelete(String id);
  Future<void> undelete(String id); // snackbar Undo
}
