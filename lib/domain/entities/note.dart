import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/local_date.dart';

part 'note.freezed.dart';

enum NoteKind { note, daily }

@freezed
abstract class Note with _$Note {
  const factory Note({
    required String id,
    @Default('') String title,
    @Default('') String body, // Markdown source
    @Default(NoteKind.note) NoteKind kind,
    LocalDate? dailyDate, // set only for the daily scratchpad
    @Default(false) bool isPinned,
    @Default(<String>[]) List<String> tagIds,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Note;
}

/// List row; carries no full body.
@freezed
abstract class NoteSummary with _$NoteSummary {
  const factory NoteSummary({
    required String id,
    required String title,
    required String preview,
    required NoteKind kind,
    LocalDate? dailyDate,
    required bool isPinned,
    required DateTime updatedAt,
  }) = _NoteSummary;
}

@freezed
abstract class NoteInput with _$NoteInput {
  const factory NoteInput({
    @Default('') String title,
    @Default('') String body,
    @Default(false) bool isPinned,
  }) = _NoteInput;
}

/// Null field = unchanged. The body goes through saveBody.
@freezed
abstract class NotePatch with _$NotePatch {
  const factory NotePatch({String? title, bool? isPinned}) = _NotePatch;
}
