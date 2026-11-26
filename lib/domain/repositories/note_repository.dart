import '../../core/local_date.dart';
import '../entities/note.dart';

abstract interface class NoteRepository {
  Stream<List<NoteSummary>> watchAll();
  Future<Note?> find(String id); // null once deleted
  Stream<Note?> watch(String id);
  Stream<Note?> watchDaily(LocalDate date); // null until the first keystroke
  Future<Note> ensureDaily(LocalDate date);
  Future<Note> create(NoteInput input);
  Future<Note> saveBody(String id, String body); // empty title = first line
  Future<Note> update(String id, NotePatch patch);
  Future<void> softDelete(String id);
  Future<void> undelete(String id);
}
