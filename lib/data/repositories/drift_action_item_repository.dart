import 'package:drift/drift.dart';

import '../../core/clock.dart';
import '../../core/failures.dart';
import '../../core/ids.dart';
import '../../core/local_date.dart';
import '../../domain/entities/action_item.dart';
import '../../domain/repositories/action_item_repository.dart';
import '../db/app_database.dart';
import '../db/db_errors.dart';
import '../mappers/action_item_mapper.dart';
import 'tag_ids.dart';

final class DriftActionItemRepository implements ActionItemRepository {
  DriftActionItemRepository(this._db, this._clock, this._ids);

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _ids;

  int get _now => _clock.nowUtc().millisecondsSinceEpoch;

  /// PRD F2: overdue first, then high priority, then due today.
  @override
  Stream<List<ActionItem>> watchInbox(LocalDate today) {
    final day = today.toIso();
    return _watch(
      "a.status = 'open' AND a.scheduled_start IS NULL "
      'AND (a.due_date <= ? OR a.priority = ?)',
      [day, Priority.high.index, day, Priority.high.index],
      orderBy:
          'CASE WHEN a.due_date < ? THEN 0 WHEN a.priority = ? THEN 1 '
          'ELSE 2 END, a.due_date NULLS LAST, a.priority DESC, a.created_at, '
          'a.id',
    );
  }

  /// Open and done items starting in [fromUtc, toUtc), earliest first.
  @override
  Stream<List<ActionItem>> watchScheduled(DateTime fromUtc, DateTime toUtc) =>
      _watch(
        "a.status <> 'cancelled' AND a.scheduled_start >= ? "
        'AND a.scheduled_start < ?',
        [fromUtc.millisecondsSinceEpoch, toUtc.millisecondsSinceEpoch],
        orderBy: 'a.scheduled_start, a.id',
      );

  /// Open and done items due on [day], scheduled or not.
  @override
  Stream<List<ActionItem>> watchDueOn(LocalDate day) => _watch(
    "a.status <> 'cancelled' AND a.due_date = ?",
    [day.toIso()],
    orderBy: 'a.priority DESC, a.created_at, a.id',
  );

  /// Unscheduled items only: scheduled ones live in the Calendar (PRD F4).
  @override
  Stream<List<ActionItem>> watchTasks(TaskFilter filter) {
    final priority = filter.priority;
    final tagId = filter.tagId;
    return _watch(
      [
        'a.scheduled_start IS NULL',
        'a.status IN (${List.filled(filter.statuses.length, '?').join(', ')})',
        if (priority != null) 'a.priority = ?',
        if (tagId != null)
          'EXISTS (SELECT 1 FROM taggings f JOIN tags ft ON ft.id = f.tag_id '
              "AND ft.is_deleted = 0 WHERE f.entity_type = 'action_item' "
              'AND f.entity_id = a.id AND f.is_deleted = 0 AND f.tag_id = ?)',
      ].join(' AND '),
      [for (final s in filter.statuses) s.name, ?priority?.index, ?tagId],
      orderBy: 'a.priority DESC, a.due_date NULLS LAST, a.created_at DESC, a.id DESC',
    );
  }

  @override
  Stream<List<ActionItem>> watchPendingBills() => _watch(
    "a.bill_status = 'pending'",
    const [],
    orderBy: 'a.completed_at, a.created_at, a.id',
  );

  // No lower bound on the due date: an overdue bill is still owed. A past start
  // makes one overdue only without a due date. A payment made before [from] is
  // already in what was spent, so a reopened bill that kept it is not owed again.
  @override
  Stream<List<ActionItem>> watchCommitted(
    LocalDate from,
    LocalDate to, {
    required DateTime doneSince,
  }) => _watch(
    'a.linked_amount IS NOT NULL '
    "AND (a.status = 'open' OR (a.status = 'done' AND a.completed_at >= ?)) "
    'AND (a.due_date <= ? OR (a.scheduled_start < ? '
    'AND (a.due_date IS NULL OR a.scheduled_start >= ?))) '
    'AND NOT EXISTS (SELECT 1 FROM transactions p '
    'WHERE p.source_action_item_id = a.id AND p.is_deleted = 0 '
    'AND p.occurred_on < ?)',
    [
      doneSince.millisecondsSinceEpoch,
      to.toIso(),
      to.addDays(1).startUtc().millisecondsSinceEpoch,
      from.startUtc().millisecondsSinceEpoch,
      from.toIso(),
    ],
    orderBy: 'a.created_at, a.id',
    alsoReads: {_db.transactions},
  );

  @override
  Future<ActionItem?> find(String id) => guard(() async {
    final row = await _query('a.id = ?', [id]).getSingleOrNull();
    return row == null ? null : _entity(row);
  });

  @override
  Future<List<ActionItem>> findBySourceNote(
    String noteId, {
    bool includeDeleted = false,
  }) => guard(() async {
    final rows = await _query('a.source_note_id = ?', [
      noteId,
    ], includeDeleted: includeDeleted).get();
    return rows.map(_entity).toList();
  });

  /// Open items whose alarm may still be ahead of [fromUtc]. A due-date-only
  /// item is returned for the whole of its day: the scheduler knows the time.
  @override
  Future<List<ActionItem>> withFutureReminders(DateTime fromUtc) =>
      guard(() async {
        final rows = await _query(
          "a.status = 'open' AND ("
          'a.scheduled_start - COALESCE(a.reminder_offset_min, 0) * 60000 > ? '
          'OR (a.scheduled_start IS NULL AND a.due_date >= ?))',
          [
            fromUtc.millisecondsSinceEpoch,
            LocalDate.fromDateTime(fromUtc.toLocal()).toIso(),
          ],
        ).get();
        return rows.map(_entity).toList();
      });

  @override
  Future<ActionItem> create(ActionItemInput input) => guard(
    () => _db.transaction(() async {
      final id = _ids.newId();
      final now = _now;
      await _db
          .into(_db.actionItems)
          .insert(
            ActionItemsCompanion.insert(
              id: id,
              title: input.title.trim(),
              body: Value(input.body),
              priority: Value(input.priority.index),
              dueDate: Value(input.dueDate?.toIso()),
              scheduledStart: Value(
                input.scheduledStart?.millisecondsSinceEpoch,
              ),
              scheduledEnd: Value(input.scheduledEnd?.millisecondsSinceEpoch),
              reminderOffsetMin: Value(input.reminderOffsetMin),
              notifId: Value(input.notifId),
              linkedAmount: Value(input.linkedAmount?.value),
              linkedWalletId: Value(input.linkedWalletId),
              linkedCategoryId: Value(input.linkedCategoryId),
              sourceNoteId: Value(input.sourceNoteId),
              sourceBlockId: Value(input.sourceBlockId),
              rawInput: Value(input.rawInput),
              createdAt: now,
              updatedAt: now,
            ),
          );
      return (await find(id))!;
    }),
  );

  @override
  Future<ActionItem> update(String id, ActionItemPatch patch) => guard(
    () => _db.transaction(() async {
      if (await find(id) == null) throw NotFoundFailure('action item $id');
      // A null record leaves the column alone; (value: null) clears it.
      Value<T> set<S, T>(({S value})? field, T Function(S) column) =>
          field == null ? const Value.absent() : Value(column(field.value));
      await _write(
        id,
        ActionItemsCompanion(
          title: Value.absentIfNull(patch.title?.trim()),
          body: Value.absentIfNull(patch.body),
          status: Value.absentIfNull(patch.status?.name),
          priority: Value.absentIfNull(patch.priority?.index),
          dueDate: set(patch.dueDate, (v) => v?.toIso()),
          scheduledStart: set(
            patch.scheduledStart,
            (v) => v?.millisecondsSinceEpoch,
          ),
          scheduledEnd: set(
            patch.scheduledEnd,
            (v) => v?.millisecondsSinceEpoch,
          ),
          reminderOffsetMin: set(patch.reminderOffsetMin, (v) => v),
          notifId: Value.absentIfNull(patch.notifId),
          linkedAmount: set(patch.linkedAmount, (v) => v?.value),
          linkedWalletId: set(patch.linkedWalletId, (v) => v),
          linkedCategoryId: set(patch.linkedCategoryId, (v) => v),
          billStatus: set(patch.billStatus, (v) => v?.name),
          completedAt: set(patch.completedAt, (v) => v?.millisecondsSinceEpoch),
          updatedAt: Value(_now),
        ),
      );
      return (await find(id))!;
    }),
  );

  @override
  Future<void> softDelete(String id) => _setDeleted(id, 1);

  @override
  Future<void> undelete(String id) => _setDeleted(id, 0);

  Future<void> _setDeleted(String id, int deleted) => guard(() async {
    final changed = await _write(
      id,
      ActionItemsCompanion(isDeleted: Value(deleted), updatedAt: Value(_now)),
    );
    if (changed == 0) throw NotFoundFailure('action item $id');
  });

  Future<int> _write(String id, ActionItemsCompanion values) => (_db.update(
    _db.actionItems,
  )..where((a) => a.id.equals(id))).write(values);

  Stream<List<ActionItem>> _watch(
    String where,
    List<Object> args, {
    required String orderBy,
    Set<ResultSetImplementation<dynamic, dynamic>> alsoReads = const {},
  }) => _query(
    where,
    args,
    orderBy: orderBy,
    alsoReads: alsoReads,
  ).watch().map((rows) => rows.map(_entity).toList()).guarded();

  /// [args] fill the placeholders of [where], then those of [orderBy].
  Selectable<QueryRow> _query(
    String where,
    List<Object> args, {
    String orderBy = 'a.created_at, a.id',
    bool includeDeleted = false,
    Set<ResultSetImplementation<dynamic, dynamic>> alsoReads = const {},
  }) => _db.customSelect(
    'SELECT a.*, ${tagIdsColumn('action_item', 'a')} FROM action_items a '
    'WHERE ${includeDeleted ? '' : 'a.is_deleted = 0 AND '}$where '
    'ORDER BY $orderBy',
    variables: [for (final arg in args) Variable<Object>(arg)],
    readsFrom: {_db.actionItems, _db.taggings, _db.tags, ...alsoReads},
  );

  ActionItem _entity(QueryRow row) =>
      _db.actionItems.map(row.data).toEntity(tagIds: readTagIds(row));
}
