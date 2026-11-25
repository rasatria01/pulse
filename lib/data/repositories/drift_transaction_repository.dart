import 'package:drift/drift.dart';

import '../../core/clock.dart';
import '../../core/failures.dart';
import '../../core/ids.dart';
import '../../core/local_date.dart';
import '../../core/rupiah.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../db/app_database.dart';
import '../db/db_errors.dart';
import '../mappers/transaction_mapper.dart';
import 'budget_period.dart';

final class DriftTransactionRepository implements TransactionRepository {
  DriftTransactionRepository(this._db, this._clock, this._ids);

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _ids;

  int get _now => _clock.nowUtc().millisecondsSinceEpoch;

  @override
  Stream<List<Transaction>> watchDay(LocalDate day) => watchRange(day, day);

  @override
  Stream<List<Transaction>> watchRange(
    LocalDate from,
    LocalDate to, {
    String? walletId,
    String? categoryId,
  }) => _query(
    [
      't.occurred_on BETWEEN ? AND ?',
      if (walletId != null) '(t.wallet_id = ? OR t.to_wallet_id = ?)',
      if (categoryId != null) 't.category_id = ?',
    ].join(' AND '),
    [from.toIso(), to.toIso(), ?walletId, ?walletId, ?categoryId],
  ).watch().map((rows) => rows.map(_entity).toList()).guarded();

  @override
  Stream<Rupiah> watchOutcomeTotal(LocalDate from, LocalDate to) => _db
      .customSelect(
        'SELECT COALESCE(SUM(amount), 0) AS total FROM transactions '
        "WHERE type = 'OUTCOME' AND is_deleted = 0 "
        'AND occurred_on BETWEEN ? AND ?',
        variables: [Variable(from.toIso()), Variable(to.toIso())],
        readsFrom: {_db.transactions},
      )
      .watchSingle()
      .map((row) => Rupiah(row.read<int>('total')))
      .guarded();

  // The start day is read in the same query so that changing it re-emits:
  // fetch the widest possible period, then cut it to the real one.
  @override
  Stream<Map<String, Rupiah>> watchOutcomeByCategory(LocalMonth month) => _db
      .customSelect(
        'SELECT category_id, occurred_on, SUM(amount) AS total, '
        '(SELECT value FROM app_settings WHERE key = ?) AS start_day '
        "FROM transactions WHERE type = 'OUTCOME' AND is_deleted = 0 "
        'AND occurred_on BETWEEN ? AND ? '
        'GROUP BY category_id, occurred_on',
        variables: [
          const Variable(SettingKeys.budgetMonthStartDay),
          Variable(month.firstDay.toIso()),
          Variable(month.addMonths(1).lastDay.toIso()),
        ],
        readsFrom: {_db.transactions, _db.appSettings},
      )
      .watch()
      .map((rows) {
        final totals = <String, Rupiah>{};
        for (final row in rows) {
          final (from, to) = budgetPeriod(
            month,
            row.readNullable<String>('start_day'),
          );
          final on = LocalDate.parse(row.read<String>('occurred_on'));
          if (on.isBefore(from) || on.isAfter(to)) continue;
          final category = row.read<String>('category_id');
          totals[category] =
              (totals[category] ?? Rupiah.zero) +
              Rupiah(row.read<int>('total'));
        }
        return totals;
      })
      .guarded();

  @override
  Future<Transaction?> find(String id) => guard(() async {
    final row = await _query('t.id = ?', [id]).getSingleOrNull();
    return row == null ? null : _entity(row);
  });

  @override
  Future<Transaction?> findBySourceActionItem(String actionItemId) =>
      guard(() async {
        final rows = await _query('t.source_action_item_id = ?', [
          actionItemId,
        ]).get();
        return rows.isEmpty ? null : _entity(rows.first);
      });

  @override
  Future<Transaction> create(TransactionInput input) => guard(
    () => _db.transaction(() async {
      final id = _ids.newId();
      final now = _now;
      final values = await _values(input);
      await _db
          .into(_db.transactions)
          .insert(
            values.copyWith(
              id: Value(id),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      return (await find(id))!;
    }),
  );

  @override
  Future<Transaction> update(String id, TransactionInput input) => guard(
    () => _db.transaction(() async {
      final old = await find(id);
      if (old == null) throw NotFoundFailure('transaction $id');
      final values = await _values(input, old: old);
      await (_db.update(_db.transactions)..where((t) => t.id.equals(id))).write(
        values.copyWith(updatedAt: Value(_now)),
      );
      return (await find(id))!;
    }),
  );

  @override
  Future<void> softDelete(String id) => _setDeleted(id, 1);

  @override
  Future<void> undelete(String id) => _setDeleted(id, 0);

  Future<void> _setDeleted(String id, int deleted) => guard(() async {
    final changed =
        await (_db.update(
          _db.transactions,
        )..where((t) => t.id.equals(id))).write(
          TransactionsCompanion(
            isDeleted: Value(deleted),
            updatedAt: Value(_now),
          ),
        );
    if (changed == 0) throw NotFoundFailure('transaction $id');
  });

  /// Live transactions with their live tag ids, newest first.
  Selectable<QueryRow> _query(String where, List<String> args) =>
      _db.customSelect(
        'SELECT t.*, (SELECT group_concat(g.tag_id) FROM taggings g '
        'JOIN tags tg ON tg.id = g.tag_id AND tg.is_deleted = 0 '
        "WHERE g.entity_type = 'transaction' AND g.entity_id = t.id "
        'AND g.is_deleted = 0) AS tag_ids '
        'FROM transactions t WHERE t.is_deleted = 0 AND $where '
        'ORDER BY t.occurred_at DESC, t.id DESC',
        variables: [for (final arg in args) Variable<String>(arg)],
        readsFrom: {_db.transactions, _db.taggings, _db.tags},
      );

  Transaction _entity(QueryRow row) => _db.transactions
      .map(row.data)
      .toEntity(
        tagIds: (row.readNullable<String>('tag_ids')?.split(',') ?? [])..sort(),
      );

  /// Validated column values. [old] is set on update: an archived wallet it
  /// already uses stays allowed.
  Future<TransactionsCompanion> _values(
    TransactionInput input, {
    Transaction? old,
  }) async {
    if (!input.amount.isPositive) {
      throw const ValidationFailure('amount must be above 0', field: 'amount');
    }
    final isTransfer = input.type == TxnType.transfer;
    final toWalletId = input.toWalletId;
    if (isTransfer) {
      if (toWalletId == null || toWalletId == input.walletId) {
        throw const ValidationFailure(
          'a transfer needs two different wallets',
          field: 'toWalletId',
        );
      }
      if (input.categoryId != null) {
        throw const ValidationFailure(
          'a transfer has no category',
          field: 'categoryId',
        );
      }
    } else if (toWalletId != null) {
      throw const ValidationFailure(
        'only a transfer has a destination wallet',
        field: 'toWalletId',
      );
    }

    final kept = {old?.walletId, old?.toWalletId};
    for (final walletId in [input.walletId, ?toWalletId]) {
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

    return TransactionsCompanion(
      type: Value(txnTypeColumn(input.type)),
      amount: Value(input.amount.value),
      walletId: Value(input.walletId),
      toWalletId: Value(toWalletId),
      categoryId: Value(isTransfer ? null : await _categoryId(input)),
      description: Value(input.description.trim()),
      occurredAt: Value(input.occurredAt.millisecondsSinceEpoch),
      occurredOn: Value(input.occurredOn.toIso()),
      parentTransactionId: Value(input.parentTransactionId),
      sourceActionItemId: Value(input.sourceActionItemId),
      // The entity carries no raw input, so an edit must not erase it.
      rawInput: Value.absentIfNull(input.rawInput),
    );
  }

  /// The given category if it fits the type, else Uncategorized (D9).
  Future<String> _categoryId(TransactionInput input) async {
    final kind = input.type.name;
    final id = input.categoryId;
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
