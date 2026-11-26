import '../entities/action_item.dart';

/// PRD 9.2: a checklist line and its action item are one object.
abstract interface class NoteTaskSync {
  /// On every note save. Writes the body and its items in one transaction and
  /// returns the stored body, with block ids on new checklist lines. The line
  /// [skipLine] (zero-based, still being typed) is left for a later save.
  Future<String> onNoteSaved(String noteId, String body, {int? skipLine});

  /// After an item with a source note changes outside the editor. Call it in
  /// the same UnitOfWork as the change. A deleted item has [ActionItem.isDeleted].
  Future<void> onItemChanged(ActionItem item);

  /// Saves what an open editor of [noteId] has not written yet. Call it before
  /// that transaction, never inside it.
  Future<void> flushEditor(String noteId);

  /// Registers an open editor; the returned call detaches it.
  void Function() attachEditor(String noteId, Future<void> Function() flush);
}
