import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/local_date.dart';
import '../../core/rupiah.dart';

part 'budget.freezed.dart';

@freezed
abstract class Budget with _$Budget {
  const factory Budget({
    required String id,
    required String categoryId,
    required Rupiah amount, // 0 = no cap from this month on
    required LocalMonth effectiveFrom,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Budget;
}

@freezed
abstract class BudgetStatus with _$BudgetStatus {
  const BudgetStatus._();

  const factory BudgetStatus({
    required String categoryId,
    required LocalMonth month,
    required Rupiah cap,
    required Rupiah spent,
  }) = _BudgetStatus;

  /// Spent as a whole percentage of the cap, rounded down. 80 warns, 100 is critical.
  int get percentUsed => cap.value == 0 ? 0 : spent.value * 100 ~/ cap.value;
}
