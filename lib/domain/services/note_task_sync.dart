import '../entities/action_item.dart';

abstract interface class NoteTaskSync {
  /// On every note save. Returns the body with block ids on new checklist lines.
  Future<String> onNoteSaved(String noteId, String body);

  /// After an item with a source note changes outside the editor.
  Future<void> onItemChanged(ActionItem item);
}
