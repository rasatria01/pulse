import 'package:drift/drift.dart';

import '../../core/clock.dart';
import '../../core/failures.dart';
import '../../core/ids.dart';
import '../../core/local_date.dart';
import '../../domain/entities/note.dart';
import '../../domain/repositories/note_repository.dart';
import '../db/app_database.dart';
import '../db/db_errors.dart';
import '../mappers/note_mapper.dart';
import 'tag_ids.dart';

final class DriftNoteRepository implements NoteRepository {
  DriftNoteRepository(this._db, this._clock, this._ids);

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _ids;

  int get _now => _clock.nowUtc().millisecondsSinceEpoch;

  /// Pinned first, then the most recently changed.
  // The list reads only the head of each body, never whole notes.
  @override
  Stream<List<NoteSummary>> watchAll() => _db
      .customSelect(
        "SELECT id, title, '' AS body, kind, daily_date, is_pinned, "
        'created_at, updated_at, is_deleted, substr(body, 1, 600) AS head '
        'FROM notes WHERE is_deleted = 0 '
        'ORDER BY is_pinned DESC, updated_at DESC, id DESC',
        readsFrom: {_db.notes},
      )
      .watch()
      .map(
        (rows) => [
          for (final row in rows)
            noteSummary(
              _db.notes.map(row.data),
              head: row.read<String>('head'),
            ),
        ],
      )
      .guarded();

  @override
  Future<Note?> find(String id) => guard(() async {
    final row = await _query('n.id = ?', id).getSingleOrNull();
    return row == null ? null : _entity(row);
  });

  @override
  Stream<Note?> watch(String id) => _watchOne('n.id = ?', id);

  @override
  Stream<Note?> watchDaily(LocalDate date) =>
      _watchOne('n.daily_date = ?', date.toIso());

  @override
  Future<Note> ensureDaily(LocalDate date) => guard(
    () => _db.transaction(() async {
      final row = await _query(
        'n.daily_date = ?',
        date.toIso(),
      ).getSingleOrNull();
      if (row != null) return _entity(row);
      return _insert(
        const NoteInput(),
        kind: NoteKind.daily,
        dailyDate: date.toIso(),
      );
    }),
  );

  @override
  Future<Note> create(NoteInput input) =>
      guard(() => _db.transaction(() => _insert(input)));

  /// A title the user did not write follows the first line of the body.
  @override
  Future<Note> saveBody(String id, String body) => guard(
    () => _db.transaction(() async {
      final old = await _require(id);
      // An unchanged autosave must not move the note up the list.
      if (old.body == body) return old;
      final automatic =
          old.title.isEmpty || old.title == titleFromBody(old.body);
      await _write(
        id,
        NotesCompanion(
          body: Value(body),
          title: Value.absentIfNull(automatic ? titleFromBody(body) : null),
          updatedAt: Value(_now),
        ),
      );
      return _require(id);
    }),
  );

  @override
  Future<Note> update(String id, NotePatch patch) => guard(
    () => _db.transaction(() async {
      final old = await _require(id);
      final title = patch.title?.trim();
      final pinned = patch.isPinned;
      await _write(
        id,
        NotesCompanion(
          title: Value.absentIfNull(
            title == null || title.isNotEmpty ? title : titleFromBody(old.body),
          ),
          isPinned: Value.absentIfNull(
            pinned == null ? null : (pinned ? 1 : 0),
          ),
          updatedAt: Value(_now),
        ),
      );
      return _require(id);
    }),
  );

  @override
  Future<void> softDelete(String id) => _setDeleted(id, 1);

  @override
  Future<void> undelete(String id) => _setDeleted(id, 0);

  Future<void> _setDeleted(String id, int deleted) => guard(() async {
    final changed = await _write(
      id,
      NotesCompanion(isDeleted: Value(deleted), updatedAt: Value(_now)),
    );
    if (changed == 0) throw NotFoundFailure('note $id');
  });

  Future<Note> _insert(
    NoteInput input, {
    NoteKind kind = NoteKind.note,
    String? dailyDate,
  }) async {
    final id = _ids.newId();
    final now = _now;
    final title = input.title.trim();
    await _db
        .into(_db.notes)
        .insert(
          NotesCompanion.insert(
            id: id,
            title: Value(title.isEmpty ? titleFromBody(input.body) : title),
            body: Value(input.body),
            kind: Value(kind.name),
            dailyDate: Value(dailyDate),
            isPinned: Value(input.isPinned ? 1 : 0),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return _require(id);
  }

  Future<int> _write(String id, NotesCompanion values) =>
      (_db.update(_db.notes)..where((n) => n.id.equals(id))).write(values);

  Future<Note> _require(String id) async {
    final row = await _query('n.id = ?', id).getSingleOrNull();
    if (row == null) throw NotFoundFailure('note $id');
    return _entity(row);
  }

  Stream<Note?> _watchOne(String where, String arg) => _query(where, arg)
      .watchSingleOrNull()
      .map((row) => row == null ? null : _entity(row))
      .guarded();

  Selectable<QueryRow> _query(String where, String arg) => _db.customSelect(
    'SELECT n.*, ${tagIdsColumn('note', 'n')} FROM notes n '
    'WHERE n.is_deleted = 0 AND $where',
    variables: [Variable<String>(arg)],
    readsFrom: {_db.notes, _db.taggings, _db.tags},
  );

  Note _entity(QueryRow row) =>
      _db.notes.map(row.data).toEntity(tagIds: readTagIds(row));
}
