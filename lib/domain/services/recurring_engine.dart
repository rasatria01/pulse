import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/local_date.dart';
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
}
