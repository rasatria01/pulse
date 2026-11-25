import 'package:drift/drift.dart';

import '../../core/clock.dart';
import '../../core/failures.dart';
import '../../core/ids.dart';
import '../../core/local_date.dart';
import '../../domain/entities/recurring_occurrence.dart';
import '../../domain/entities/recurring_rule.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/recurring_repository.dart';
import '../db/app_database.dart';
import '../db/db_errors.dart';
import '../mappers/recurring_mapper.dart';
import '../mappers/transaction_mapper.dart';
import 'input_checks.dart';

final class DriftRecurringRepository implements RecurringRepository {
  DriftRecurringRepository(this._db, this._clock, this._ids);

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _ids;

  int get _now => _clock.nowUtc().millisecondsSinceEpoch;

  @override
  Stream<List<RecurringRule>> watchRules() =>
      (_db.select(_db.recurringRules)
            ..where((r) => r.isDeleted.equals(0))
            ..orderBy([
              (r) => OrderingTerm(expression: r.nextDueDate),
              (r) => OrderingTerm(expression: r.name),
              (r) => OrderingTerm(expression: r.id),
            ]))
          .watch()
          .map((rows) => [for (final row in rows) row.toEntity()])
          .guarded();

  /// Oldest first. Occurrences of a deleted rule are not offered.
  @override
  Stream<List<PendingOccurrence>> watchPending() {
    final occurrences = _db.recurringOccurrences;
    final rules = _db.recurringRules;
    final query =
        _db.select(occurrences).join([
            innerJoin(rules, rules.id.equalsExp(occurrences.ruleId)),
          ])
          ..where(
            occurrences.status.equals(OccurrenceStatus.pending.name) &
                occurrences.isDeleted.equals(0) &
                rules.isDeleted.equals(0),
          )
          ..orderBy([
            OrderingTerm(expression: occurrences.occurrenceDate),
            OrderingTerm(expression: rules.name),
            OrderingTerm(expression: occurrences.id),
          ]);
    return query
        .watch()
        .map(
          (rows) => [
            for (final row in rows)
              PendingOccurrence(
                occurrence: row.readTable(occurrences).toEntity(),
                rule: row.readTable(rules).toEntity(),
              ),
          ],
        )
        .guarded();
  }

  /// Active rules with something to catch up on (PRD 9.3).
  @override
  Future<List<RecurringRule>> dueOnOrBefore(LocalDate day) => guard(() async {
    final rows =
        await (_db.select(_db.recurringRules)
              ..where(
                (r) =>
                    r.isDeleted.equals(0) &
                    r.isPaused.equals(0) &
                    r.nextDueDate.isSmallerOrEqualValue(day.toIso()) &
                    (r.endDate.isNull() |
                        r.nextDueDate.isSmallerOrEqual(r.endDate)),
              )
              ..orderBy([
                (r) => OrderingTerm(expression: r.nextDueDate),
                (r) => OrderingTerm(expression: r.id),
              ]))
            .get();
    return [for (final row in rows) row.toEntity()];
  });

  @override
  Future<RecurringRule?> find(String id) => guard(() async {
    final row = await (_db.select(
      _db.recurringRules,
    )..where((r) => r.id.equals(id) & r.isDeleted.equals(0))).getSingleOrNull();
    return row?.toEntity();
  });

  @override
  Future<RecurringRule> create(RecurringRuleInput input) => guard(
    () => _db.transaction(() async {
      final id = _ids.newId();
      final now = _clock.nowUtc();
      final draft = RecurringRule(
        id: id,
        name: input.name,
        type: input.type,
        amount: input.amount,
        walletId: input.walletId,
        toWalletId: input.toWalletId,
        categoryId: input.categoryId,
        description: input.description,
        freq: input.freq,
        interval: input.interval,
        byWeekday: input.byWeekday,
        byMonthDay: input.byMonthDay,
        startDate: input.startDate,
        endDate: input.endDate,
        nextDueDate: input.nextDueDate,
        autoPost: input.autoPost,
        notifId: input.notifId,
        createdAt: now,
        updatedAt: now,
      );
      final values = await _values(draft);
      await _db
          .into(_db.recurringRules)
          .insert(
            values.copyWith(
              id: Value(id),
              createdAt: Value(now.millisecondsSinceEpoch),
              updatedAt: Value(now.millisecondsSinceEpoch),
            ),
          );
      return (await find(id))!;
    }),
  );

  @override
  Future<RecurringRule> update(String id, RecurringRulePatch patch) => guard(
    () => _db.transaction(() async {
      final old = await find(id);
      if (old == null) throw NotFoundFailure('recurring rule $id');
      T pick<T>(({T value})? field, T kept) =>
          field == null ? kept : field.value;
      final merged = old.copyWith(
        name: patch.name ?? old.name,
        type: patch.type ?? old.type,
        amount: patch.amount ?? old.amount,
        walletId: patch.walletId ?? old.walletId,
        toWalletId: pick(patch.toWalletId, old.toWalletId),
        categoryId: pick(patch.categoryId, old.categoryId),
        description: patch.description ?? old.description,
        freq: patch.freq ?? old.freq,
        interval: patch.interval ?? old.interval,
        byWeekday: pick(patch.byWeekday, old.byWeekday),
        byMonthDay: pick(patch.byMonthDay, old.byMonthDay),
        startDate: patch.startDate ?? old.startDate,
        endDate: pick(patch.endDate, old.endDate),
        nextDueDate: patch.nextDueDate ?? old.nextDueDate,
        autoPost: patch.autoPost ?? old.autoPost,
        isPaused: patch.isPaused ?? old.isPaused,
        notifId: patch.notifId ?? old.notifId,
      );
      final values = await _values(merged, old: old);
      await _write(id, values.copyWith(updatedAt: Value(_now)));
      return (await find(id))!;
    }),
  );

  @override
  Future<void> softDelete(String id) => guard(() async {
    final changed = await _write(
      id,
      RecurringRulesCompanion(
        isDeleted: const Value(1),
        updatedAt: Value(_now),
      ),
    );
    if (changed == 0) throw NotFoundFailure('recurring rule $id');
  });

  /// The unique (rule, date) index turns a second insert into a
  /// ConflictFailure: this is the exactly-once guarantee of catch-up.
  @override
  Future<String> insertOccurrence(
    String ruleId,
    LocalDate date, {
    String? transactionId,
  }) => guard(() async {
    final id = _ids.newId();
    final now = _now;
    final status = transactionId == null
        ? OccurrenceStatus.pending
        : OccurrenceStatus.posted;
    await _db
        .into(_db.recurringOccurrences)
        .insert(
          RecurringOccurrencesCompanion.insert(
            id: id,
            ruleId: ruleId,
            occurrenceDate: date.toIso(),
            status: Value(status.name),
            transactionId: Value(transactionId),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  });

  /// Only a pending occurrence can be posted or skipped, so a second confirm
  /// cannot post twice. Run it in the same UnitOfWork as the transaction.
  @override
  Future<void> resolveOccurrence(
    String occurrenceId,
    OccurrenceStatus status, {
    String? transactionId,
  }) => guard(
    () => _db.transaction(() async {
      final row =
          await (_db.select(_db.recurringOccurrences)..where(
                (o) => o.id.equals(occurrenceId) & o.isDeleted.equals(0),
              ))
              .getSingleOrNull();
      if (row == null) throw NotFoundFailure('occurrence $occurrenceId');
      if (status != OccurrenceStatus.pending &&
          row.status != OccurrenceStatus.pending.name) {
        throw ConflictFailure('occurrence is already ${row.status}');
      }
      await (_db.update(
        _db.recurringOccurrences,
      )..where((o) => o.id.equals(occurrenceId))).write(
        RecurringOccurrencesCompanion(
          status: Value(status.name),
          transactionId: Value(transactionId),
          updatedAt: Value(_now),
        ),
      );
    }),
  );

  @override
  Future<void> setNextDue(String ruleId, LocalDate next) => guard(() async {
    final changed = await _write(
      ruleId,
      RecurringRulesCompanion(
        nextDueDate: Value(next.toIso()),
        updatedAt: Value(_now),
      ),
    );
    if (changed == 0) throw NotFoundFailure('recurring rule $ruleId');
  });

  Future<int> _write(String id, RecurringRulesCompanion values) => (_db.update(
    _db.recurringRules,
  )..where((r) => r.id.equals(id) & r.isDeleted.equals(0))).write(values);

  /// Validated column values; the schema CHECKs cover amount, interval and the
  /// transfer shape. [old] keeps an already used archived wallet allowed.
  Future<RecurringRulesCompanion> _values(
    RecurringRule rule, {
    RecurringRule? old,
  }) async {
    final kept = {old?.walletId, old?.toWalletId};
    for (final walletId in [rule.walletId, ?rule.toWalletId]) {
      final wallet =
          await (_db.select(_db.wallets)
                ..where((w) => w.id.equals(walletId) & w.isDeleted.equals(0)))
              .getSingleOrNull();
      if (wallet == null) throw NotFoundFailure('wallet $walletId');
      if (wallet.isArchived == 1 && !kept.contains(walletId)) {
        throw const ValidationFailure(
          'an archived wallet takes no new transactions',
          field: 'walletId',
        );
      }
    }

    return RecurringRulesCompanion(
      name: Value(requireName(rule.name)),
      type: Value(txnTypeColumn(rule.type)),
      amount: Value(rule.amount.value),
      walletId: Value(rule.walletId),
      toWalletId: Value(rule.toWalletId),
      categoryId: Value(await _categoryId(rule)),
      description: Value(rule.description.trim()),
      freq: Value(rule.freq.name),
      intervalN: Value(rule.interval),
      byWeekday: Value(rule.byWeekday),
      byMonthDay: Value(rule.byMonthDay),
      startDate: Value(rule.startDate.toIso()),
      endDate: Value(rule.endDate?.toIso()),
      nextDueDate: Value(rule.nextDueDate.toIso()),
      autoPost: Value(rule.autoPost ? 1 : 0),
      isPaused: Value(rule.isPaused ? 1 : 0),
      notifId: Value(rule.notifId),
    );
  }

  /// As for transactions: the matching category, else Uncategorized (D9). A
  /// category on a transfer is left for the schema to refuse.
  Future<String?> _categoryId(RecurringRule rule) async {
    final id = rule.categoryId;
    if (rule.type == TxnType.transfer) return id;
    final kind = rule.type.name;
    final row =
        await (_db.select(_db.categories)..where(
              (c) =>
                  c.isDeleted.equals(0) &
                  (id == null
                      ? c.isSystem.equals(1) & c.kind.equals(kind)
                      : c.id.equals(id)),
            ))
            .getSingleOrNull();
    if (row == null) throw NotFoundFailure('category ${id ?? kind}');
    if (row.kind != kind) {
      throw ValidationFailure(
        'category is not an $kind category',
        field: 'categoryId',
      );
    }
    return row.id;
  }
}
