// Providers owned by the capture + finance thread (E): CaptureService,
// wallet/category streams and todayPulseProvider. Exported by di.dart.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/rupiah.dart';
import '../domain/entities/category.dart';
import '../domain/entities/wallet.dart';
import '../domain/services/capture_service.dart';
import '../domain/services/default_capture_service.dart';
import '../domain/services/today_pulse.dart';
import 'di.dart';

final captureServiceProvider = Provider<CaptureService>(
  (ref) => DefaultCaptureService(
    unitOfWork: ref.watch(unitOfWorkProvider),
    transactions: ref.watch(transactionRepositoryProvider),
    actionItems: ref.watch(actionItemRepositoryProvider),
    notes: ref.watch(noteRepositoryProvider),
    tags: ref.watch(tagRepositoryProvider),
    search: ref.watch(searchRepositoryProvider),
    settings: ref.watch(settingsRepositoryProvider),
    reminders: ref.watch(reminderSchedulerProvider),
  ),
);

/// Every wallet with its balance, archived ones included.
final walletBalancesProvider = StreamProvider<List<WalletBalance>>(
  (ref) => ref.watch(walletRepositoryProvider).watchAll(includeArchived: true),
);

/// Every category, archived ones included so that old rows keep their name.
final categoriesProvider = StreamProvider<List<Category>>(
  (ref) =>
      ref.watch(categoryRepositoryProvider).watchAll(includeArchived: true),
);

final _liquidProvider = StreamProvider<Rupiah>(
  (ref) => ref.watch(walletRepositoryProvider).watchLiquidTotal(),
);

final _todaySpendProvider = StreamProvider<Rupiah>((ref) {
  final today = ref.watch(todayProvider);
  return ref
      .watch(transactionRepositoryProvider)
      .watchOutcomeTotal(today, today);
});

final todayPulseProvider = Provider<AsyncValue<TodayPulse>>((ref) {
  final wallets = ref.watch(walletBalancesProvider);
  final liquid = ref.watch(_liquidProvider);
  final spend = ref.watch(_todaySpendProvider);
  for (final part in <AsyncValue<Object?>>[wallets, liquid, spend]) {
    if (part.hasError) return AsyncError(part.error!, part.stackTrace!);
    if (!part.hasValue) return const AsyncLoading();
  }
  return AsyncData(
    TodayPulse(
      liquid: liquid.requireValue,
      todaySpend: spend.requireValue,
      wallets: [
        for (final w in wallets.requireValue)
          if (!w.wallet.isArchived) w,
      ],
    ),
  );
});
