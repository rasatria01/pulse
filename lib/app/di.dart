// Composition root: interface -> implementation providers.
// Later threads append their own providers here.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/clock.dart';
import '../core/ids.dart';
import '../data/db/app_database.dart';
import '../data/platform/uuid_id_generator.dart';
import '../data/repositories/drift_category_repository.dart';
import '../data/repositories/drift_settings_repository.dart';
import '../data/repositories/drift_tag_repository.dart';
import '../data/repositories/drift_transaction_repository.dart';
import '../data/repositories/drift_unit_of_work.dart';
import '../data/repositories/drift_wallet_repository.dart';
import '../domain/repositories/category_repository.dart';
import '../domain/repositories/settings_repository.dart';
import '../domain/repositories/tag_repository.dart';
import '../domain/repositories/transaction_repository.dart';
import '../domain/repositories/wallet_repository.dart';
import '../domain/services/unit_of_work.dart';

final clockProvider = Provider<Clock>((ref) => const SystemClock());

final idGeneratorProvider = Provider<IdGenerator>(
  (ref) => const UuidIdGenerator(),
);

/// Opened in main() and overridden there.
final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('override appDatabaseProvider'),
);

final unitOfWorkProvider = Provider<UnitOfWork>(
  (ref) => DriftUnitOfWork(ref.watch(appDatabaseProvider)),
);

final walletRepositoryProvider = Provider<WalletRepository>(
  (ref) => DriftWalletRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(clockProvider),
    ref.watch(idGeneratorProvider),
  ),
);

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => DriftCategoryRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(clockProvider),
    ref.watch(idGeneratorProvider),
  ),
);

final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => DriftTransactionRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(clockProvider),
    ref.watch(idGeneratorProvider),
  ),
);

final tagRepositoryProvider = Provider<TagRepository>(
  (ref) => DriftTagRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(clockProvider),
    ref.watch(idGeneratorProvider),
  ),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => DriftSettingsRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(clockProvider),
  ),
);
