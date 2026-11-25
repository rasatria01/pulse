import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/rupiah.dart';

part 'safe_to_spend.freezed.dart';

@freezed
abstract class SafeToSpend with _$SafeToSpend {
  const factory SafeToSpend({
    required Rupiah perDay, // S, never below 0
    required Rupiah spentToday,
    required Rupiah remaining, // S - spentToday, may be negative
  }) = _SafeToSpend;
}

/// Pure. Returns null when no budgets are set (PRD 9.4).
abstract interface class SafeToSpendCalculator {
  SafeToSpend? compute({
    required Rupiah monthCaps,
    required Rupiah spentBeforeToday,
    required Rupiah committed,
    required int daysLeft,
    required Rupiah spentToday,
  });
}
