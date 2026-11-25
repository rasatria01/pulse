import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/local_date.dart';
import '../../core/rupiah.dart';
import '../entities/recurring_rule.dart';

part 'recurring_engine.freezed.dart';

@freezed
abstract class CatchUpReport with _$CatchUpReport {
  const factory CatchUpReport({
    @Default(0) int posted,
    @Default(0) int pending,
  }) = _CatchUpReport;
}

abstract interface class RecurringEngine {
  Future<CatchUpReport> catchUp(LocalDate today); // idempotent
  LocalDate advance(RecurringRule rule, LocalDate from); // pure

  /// Posts a pending occurrence atomically, with the amount edited in the sheet.
  Future<void> postPending(String occurrenceId, {Rupiah? amount});
  Future<void> skipPending(String occurrenceId);
}
