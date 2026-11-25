import '../../core/rupiah.dart';
import '../entities/wallet.dart';

/// For every repository: reads return a Stream, one-off lookups a Future, writes
/// return the saved entity or throw an AppFailure. Soft-deleted rows never show.
abstract interface class WalletRepository {
  Stream<List<WalletBalance>> watchAll({bool includeArchived = false});
  Stream<Rupiah> watchLiquidTotal();
  Future<List<WalletRef>> refs(); // parser snapshot
  Future<Wallet> create(WalletInput input);
  Future<Wallet> update(String id, WalletPatch patch);
  Future<void> setDefault(String id);
  Future<void> archive(String id);
}
