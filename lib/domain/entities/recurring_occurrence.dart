import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/local_date.dart';
import 'recurring_rule.dart';

part 'recurring_occurrence.freezed.dart';

enum OccurrenceStatus { pending, posted, skipped }

@freezed
abstract class RecurringOccurrence with _$RecurringOccurrence {
  const factory RecurringOccurrence({
    required String id,
    required String ruleId,
    required LocalDate occurrenceDate,
    @Default(OccurrenceStatus.pending) OccurrenceStatus status,
    String? transactionId, // set exactly when posted
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _RecurringOccurrence;
}

@freezed
abstract class PendingOccurrence with _$PendingOccurrence {
  const factory PendingOccurrence({
    required RecurringOccurrence occurrence,
    required RecurringRule rule,
  }) = _PendingOccurrence;
}
