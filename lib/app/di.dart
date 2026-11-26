// Composition root: interface -> implementation providers. Features import only
// this file; each thread adds its providers to the file it owns, exported below.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/clock.dart';
import '../core/ids.dart';
import '../core/local_date.dart';
import '../data/db/app_database.dart';
import '../data/platform/uuid_id_generator.dart';
import '../data/repositories/drift_action_item_repository.dart';
import '../data/repositories/drift_budget_repository.dart';
import '../data/repositories/drift_category_repository.dart';
import '../data/repositories/drift_note_repository.dart';
import '../data/repositories/drift_recurring_repository.dart';
import '../data/repositories/drift_search_repository.dart';
import '../data/repositories/drift_settings_repository.dart';
import '../data/repositories/drift_tag_repository.dart';
import '../data/repositories/drift_transaction_repository.dart';
import '../data/repositories/drift_unit_of_work.dart';
import '../data/repositories/drift_wallet_repository.dart';
import '../domain/repositories/action_item_repository.dart';
import '../domain/repositories/budget_repository.dart';
import '../domain/repositories/category_repository.dart';
import '../domain/repositories/note_repository.dart';
import '../domain/repositories/recurring_repository.dart';
import '../domain/repositories/search_repository.dart';
import '../domain/repositories/settings_repository.dart';
import '../domain/repositories/tag_repository.dart';
import '../domain/repositories/transaction_repository.dart';
import '../domain/repositories/wallet_repository.dart';
import '../domain/services/unit_of_work.dart';

export 'di_capture.dart';
export 'di_notes.dart';
export 'di_planner.dart';
export 'di_system.dart';

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

final actionItemRepositoryProvider = Provider<ActionItemRepository>(
  (ref) => DriftActionItemRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(clockProvider),
    ref.watch(idGeneratorProvider),
  ),
);

final noteRepositoryProvider = Provider<NoteRepository>(
  (ref) => DriftNoteRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(clockProvider),
    ref.watch(idGeneratorProvider),
  ),
);

final budgetRepositoryProvider = Provider<BudgetRepository>(
  (ref) => DriftBudgetRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(clockProvider),
    ref.watch(idGeneratorProvider),
  ),
);

final recurringRepositoryProvider = Provider<RecurringRepository>(
  (ref) => DriftRecurringRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(clockProvider),
    ref.watch(idGeneratorProvider),
  ),
);

final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) => DriftSearchRepository(ref.watch(appDatabaseProvider)),
);

/// The local calendar day. Day-scoped providers watch this, so an open screen
/// rolls over at midnight.
final todayProvider = NotifierProvider<TodayNotifier, LocalDate>(
  TodayNotifier.new,
);

class TodayNotifier extends Notifier<LocalDate> {
  Timer? _timer;

  @override
  LocalDate build() {
    final clock = ref.watch(clockProvider);
    // A timer does not run reliably while the app is in the background.
    final lifecycle = AppLifecycleListener(onResume: refresh);
    ref.onDispose(() {
      _timer?.cancel();
      lifecycle.dispose();
    });
    _arm(clock);
    return clock.today();
  }

  void refresh() {
    final clock = ref.read(clockProvider);
    state = clock.today();
    _arm(clock);
  }

  void _arm(Clock clock) {
    _timer?.cancel();
    final now = clock.nowLocal();
    final wait = DateTime(now.year, now.month, now.day + 1).difference(now);
    // A timer that fires a moment early must not spin.
    const least = Duration(seconds: 1);
    _timer = Timer(wait < least ? least : wait, refresh);
  }
}
