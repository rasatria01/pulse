import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:pulse/core/clock.dart';
import 'package:pulse/core/local_date.dart';
import 'package:pulse/core/rupiah.dart';
import 'package:pulse/data/db/app_database.dart';
import 'package:pulse/data/platform/uuid_id_generator.dart';
import 'package:pulse/data/repositories/drift_category_repository.dart';
import 'package:pulse/data/repositories/drift_settings_repository.dart';
import 'package:pulse/data/repositories/drift_tag_repository.dart';
import 'package:pulse/data/repositories/drift_transaction_repository.dart';
import 'package:pulse/data/repositories/drift_unit_of_work.dart';
import 'package:pulse/data/repositories/drift_wallet_repository.dart';
import 'package:pulse/domain/entities/category.dart';
import 'package:pulse/domain/entities/transaction.dart';
import 'package:pulse/domain/entities/wallet.dart';

final class FixedClock implements Clock {
  const FixedClock();

  @override
  DateTime nowUtc() => DateTime.utc(2026, 11, 25, 3);

  @override
  DateTime nowLocal() => DateTime(2026, 11, 25, 10);

  @override
  LocalDate today() => const LocalDate(2026, 11, 25);
}

const today = LocalDate(2026, 11, 25);

/// A fresh seeded database with every repository on it.
class Harness {
  Harness([QueryExecutor? executor]) : db = _open(executor);

  static AppDatabase _open(QueryExecutor? executor) {
    // Each database here has its own executor.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    return AppDatabase(executor ?? NativeDatabase.memory(), clock: _clock);
  }

  static const _clock = FixedClock();
  static const _ids = UuidIdGenerator();

  final AppDatabase db;
  late final wallets = DriftWalletRepository(db, _clock, _ids);
  late final categories = DriftCategoryRepository(db, _clock, _ids);
  late final transactions = DriftTransactionRepository(db, _clock, _ids);
  late final tags = DriftTagRepository(db, _clock, _ids);
  late final settings = DriftSettingsRepository(db, _clock);
  late final unitOfWork = DriftUnitOfWork(db);

  Future<Wallet> cash() async => (await wallets.watchAll().first).first.wallet;

  Future<Wallet> addWallet(String slug, {int initial = 0}) => wallets.create(
    WalletInput(
      name: slug,
      slug: slug,
      kind: WalletKind.bank,
      initialBalance: Rupiah(initial),
      color: 0xFF3B74E0,
      icon: 'wallet',
    ),
  );

  Future<Category> category(String slug, CategoryKind kind) async =>
      (await categories.watchAll(kind: kind).first).firstWhere(
        (c) => c.slug == slug,
      );

  Future<Map<String, int>> balances() async => {
    for (final b in await wallets.watchAll(includeArchived: true).first)
      b.wallet.id: b.balance.value,
  };

  Future<List<QueryRow>> sql(String query) => db.customSelect(query).get();
}

TransactionInput txn(
  TxnType type,
  int amount,
  String walletId, {
  String? to,
  String? category,
  String description = '',
  LocalDate on = today,
}) => TransactionInput(
  type: type,
  amount: Rupiah(amount),
  walletId: walletId,
  toWalletId: to,
  categoryId: category,
  description: description,
  occurredAt: DateTime.utc(on.year, on.month, on.day, 5),
  occurredOn: on,
);
