import 'package:freezed_annotation/freezed_annotation.dart';

import '../entities/tag.dart';
import '../parser/parse_result.dart';

part 'capture_service.freezed.dart';

/// What was saved; enough for Undo to remove it and any tag it created.
@freezed
abstract class CaptureOutcome with _$CaptureOutcome {
  const factory CaptureOutcome({
    required EntityType type,
    required String entityId,
    @Default(<String>[]) List<String> createdTagIds,
  }) = _CaptureOutcome;
}

abstract interface class CaptureService {
  /// Persists a parsed draft (tags, reminders included).
  /// Throws ValidationFailure if !draft.canSave.
  Future<CaptureOutcome> commit(ParseResult draft);
}
