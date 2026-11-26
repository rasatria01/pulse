import 'package:drift/drift.dart';

import '../../core/clock.dart';
import '../../core/failures.dart';
import '../../core/ids.dart';
import '../../core/rupiah.dart';
import '../../domain/entities/wallet.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../db/app_database.dart';
import '../db/db_errors.dart';
import '../mappers/wallet_mapper.dart';
import 'input_checks.dart';

/// Balance per wallet, always derived (D10). The transactions are summed in one
/// pass by (from, to) pair, then split into the two sides. NOT INDEXED because
/// every row is read, and going through an index costs more than the table.
String _balances(String filter) =>
    '''
WITH p AS MATERIALIZED (
  SELECT wallet_id, to_wallet_id,
         SUM(CASE type WHEN 'INCOME' THEN amount ELSE -amount END) AS own,
         SUM(amount) AS moved
    FROM transactions NOT INDEXED WHERE is_deleted = 0
   GROUP BY wallet_id, to_wallet_id
)
SELECT w.*, w.initial_balance + COALESCE(m.delta, 0) AS balance
FROM wallets w
LEFT JOIN (
  SELECT wallet_id, SUM(delta) AS delta FROM (
    SELECT wallet_id, own AS delta FROM p
    UNION ALL
    SELECT to_wallet_id, moved FROM p WHERE to_wallet_id IS NOT NULL
  ) GROUP BY wallet_id
) m ON m.wallet_id = w.id
WHERE w.is_deleted = 0 $filter
ORDER BY w.sort_order, w.name, w.id''';

final class DriftWalletRepository implements WalletRepository {
  DriftWalletRepository(this._db, this._clock, this._ids);

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _ids;

  int get _now => _clock.nowUtc().millisecondsSinceEpoch;

  @override
  Stream<List<WalletBalance>> watchAll({bool includeArchived = false}) => _db
      .customSelect(
        _balances(includeArchived ? '' : 'AND w.is_archived = 0'),
        readsFrom: {_db.wallets, _db.transactions},
      )
      .watch()
      .map(
        (rows) => [
          for (final row in rows)
            WalletBalance(
              wallet: _db.wallets.map(row.data).toEntity(),
              balance: Rupiah(row.read<int>('balance')),
            ),
        ],
      )
      .guarded();

  @override
  Stream<Rupiah> watchLiquidTotal() => _db
      .customSelect(
        'SELECT COALESCE(SUM(balance), 0) AS total FROM '
        '(${_balances('AND w.is_archived = 0 AND w.include_in_total = 1')})',
        readsFrom: {_db.wallets, _db.transactions},
      )
      .watchSingle()
      .map((row) => Rupiah(row.read<int>('total')))
      .guarded();

  @override
  Future<List<WalletRef>> refs() => guard(() async {
    final rows =
        await (_db.select(_db.wallets)
              ..where((w) => w.isDeleted.equals(0))
              ..orderBy([
                (w) => OrderingTerm(expression: w.sortOrder),
                (w) => OrderingTerm(expression: w.name),
              ]))
            .get();
    return [for (final row in rows) row.toRef()];
  });

  @override
  Future<Wallet> create(WalletInput input) => guard(
    () => _db.transaction(() async {
      final id = _ids.newId();
      final now = _now;
      if (input.isDefault) await _clearDefault(now);
      await _db
          .into(_db.wallets)
          .insert(
            WalletsCompanion.insert(
              id: id,
              name: requireName(input.name),
              slug: requireSlug(input.slug),
              aliases: Value(joinAliases(input.aliases)),
              kind: input.kind.name,
              initialBalance: Value(input.initialBalance.value),
              color: input.color,
              icon: input.icon,
              includeInTotal: Value(input.includeInTotal ? 1 : 0),
              isDefault: Value(input.isDefault ? 1 : 0),
              sortOrder: Value(input.sortOrder),
              createdAt: now,
              updatedAt: now,
            ),
          );
      return (await _require(id)).toEntity();
    }),
  );

  @override
  Future<Wallet> update(String id, WalletPatch patch) => guard(
    () => _db.transaction(() async {
      await _require(id);
      final name = patch.name;
      final slug = patch.slug;
      final aliases = patch.aliases;
      final includeInTotal = patch.includeInTotal;
      await _write(
        id,
        WalletsCompanion(
          name: Value.absentIfNull(name == null ? null : requireName(name)),
          slug: Value.absentIfNull(slug == null ? null : requireSlug(slug)),
          aliases: Value.absentIfNull(
            aliases == null ? null : joinAliases(aliases),
          ),
          kind: Value.absentIfNull(patch.kind?.name),
          initialBalance: Value.absentIfNull(patch.initialBalance?.value),
          color: Value.absentIfNull(patch.color),
          icon: Value.absentIfNull(patch.icon),
          includeInTotal: Value.absentIfNull(
            includeInTotal == null ? null : (includeInTotal ? 1 : 0),
          ),
          sortOrder: Value.absentIfNull(patch.sortOrder),
          updatedAt: Value(_now),
        ),
      );
      return (await _require(id)).toEntity();
    }),
  );

  @override
  Future<void> setDefault(String id) => guard(
    () => _db.transaction(() async {
      if ((await _require(id)).isArchived == 1) {
        throw const ValidationFailure('an archived wallet cannot be default');
      }
      final now = _now;
      await _clearDefault(now);
      await _write(
        id,
        WalletsCompanion(isDefault: const Value(1), updatedAt: Value(now)),
      );
    }),
  );

  @override
  Future<void> archive(String id) => guard(
    () => _db.transaction(() async {
      if ((await _require(id)).isDefault == 1) {
        throw const ValidationFailure('set another default wallet first');
      }
      await _write(
        id,
        WalletsCompanion(isArchived: const Value(1), updatedAt: Value(_now)),
      );
    }),
  );

  Future<WalletRow> _require(String id) async {
    final row = await (_db.select(
      _db.wallets,
    )..where((w) => w.id.equals(id) & w.isDeleted.equals(0))).getSingleOrNull();
    if (row == null) throw NotFoundFailure('wallet $id');
    return row;
  }

  Future<void> _write(String id, WalletsCompanion values) =>
      (_db.update(_db.wallets)..where((w) => w.id.equals(id))).write(values);

  Future<void> _clearDefault(int now) =>
      (_db.update(
        _db.wallets,
      )..where((w) => w.isDefault.equals(1) & w.isDeleted.equals(0))).write(
        WalletsCompanion(isDefault: const Value(0), updatedAt: Value(now)),
      );
}
