import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/local_date.dart';
import '../../core/rupiah.dart';
import 'transaction.dart';

part 'recurring_rule.freezed.dart';

enum RecurFreq { daily, weekly, monthly, yearly }

@freezed
abstract class RecurringRule with _$RecurringRule {
  const factory RecurringRule({
    required String id,
    required String name,
    required TxnType type,
    required Rupiah amount,
    required String walletId,
    String? toWalletId,
    String? categoryId,
    @Default('') String description,
    required RecurFreq freq,
    @Default(1) int interval,
    int? byWeekday, // ISO, 1 = Monday; weekly only
    int? byMonthDay, // null = day of startDate; clamps
    required LocalDate startDate,
    LocalDate? endDate,
    required LocalDate nextDueDate,
    @Default(false) bool autoPost,
    @Default(false) bool isPaused,
    int? notifId,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _RecurringRule;
}

@freezed
abstract class RecurringRuleInput with _$RecurringRuleInput {
  const factory RecurringRuleInput({
    required String name,
    required TxnType type,
    required Rupiah amount,
    required String walletId,
    String? toWalletId,
    String? categoryId,
    @Default('') String description,
    required RecurFreq freq,
    @Default(1) int interval,
    int? byWeekday,
    int? byMonthDay,
    required LocalDate startDate,
    LocalDate? endDate,
    required LocalDate nextDueDate,
    @Default(false) bool autoPost,
    int? notifId,
  }) = _RecurringRuleInput;
}

/// Null field = unchanged. For a clearable column, `(value: null)` clears it.
@freezed
abstract class RecurringRulePatch with _$RecurringRulePatch {
  const factory RecurringRulePatch({
    String? name,
    TxnType? type,
    Rupiah? amount,
    String? walletId,
    ({String? value})? toWalletId,
    ({String? value})? categoryId,
    String? description,
    RecurFreq? freq,
    int? interval,
    ({int? value})? byWeekday,
    ({int? value})? byMonthDay,
    LocalDate? startDate,
    ({LocalDate? value})? endDate,
    LocalDate? nextDueDate,
    bool? autoPost,
    bool? isPaused,
    int? notifId,
  }) = _RecurringRulePatch;
}
