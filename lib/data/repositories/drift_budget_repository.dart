import 'package:drift/drift.dart';

import '../../core/clock.dart';
import '../../core/failures.dart';
import '../../core/ids.dart';
import '../../core/local_date.dart';
import '../../core/rupiah.dart';
import '../../domain/entities/budget.dart';
import '../../domain/repositories/budget_repository.dart';
import '../../domain/repositories/settings_repository.dart';
import '../db/app_database.dart';
import '../db/db_errors.dart';
import 'budget_period.dart';

/// Categories joined to the cap in force in month `?`: the latest
/// effective_from not after it.
const _capsInForce =
    'FROM categories c JOIN budgets b ON b.id = ('
    'SELECT id FROM budgets WHERE category_id = c.id AND effective_from <= ? '
    'AND is_deleted = 0 ORDER BY effective_from DESC LIMIT 1)';

// A cap of 0 ends a budget.
const _budgeted =
    "c.kind = 'outcome' AND c.is_deleted = 0 AND c.is_archived = 0 "
    'AND b.amount > 0';

final class DriftBudgetRepository implements BudgetRepository {
  DriftBudgetRepository(this._db, this._clock, this._ids);

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _ids;

  int get _now => _clock.nowUtc().millisecondsSinceEpoch;

  // As in watchOutcomeByCategory: the start day is read in the same query so
  // that changing it re-emits, and the widest period is cut down in Dart.
  @override
  Stream<List<BudgetStatus>> watchMonth(LocalMonth month) => _db
      .customSelect(
        'SELECT c.id AS category_id, b.amount AS cap, t.occurred_on, '
        'COALESCE(SUM(t.amount), 0) AS spent, '
        '(SELECT value FROM app_settings WHERE key = ?) AS start_day '
        '$_capsInForce '
        'LEFT JOIN transactions t ON t.category_id = c.id '
        "AND t.type = 'OUTCOME' AND t.is_deleted = 0 "
        'AND t.occurred_on BETWEEN ? AND ? '
        'WHERE $_budgeted '
        'GROUP BY c.id, t.occurred_on ORDER BY c.sort_order, c.name, c.id',
        variables: [
          const Variable(SettingKeys.budgetMonthStartDay),
          Variable(month.toIso()),
          Variable(month.firstDay.toIso()),
          Variable(month.addMonths(1).lastDay.toIso()),
        ],
        readsFrom: {
          _db.budgets,
          _db.categories,
          _db.transactions,
          _db.appSettings,
        },
      )
      .watch()
      .map((rows) {
        final statuses = <String, BudgetStatus>{};
        for (final row in rows) {
          final category = row.read<String>('category_id');
          final status = statuses[category] ??= BudgetStatus(
            categoryId: category,
            month: month,
            cap: Rupiah(row.read<int>('cap')),
            spent: Rupiah.zero,
          );
          final on = row.readNullable<String>('occurred_on');
          if (on == null) continue;
          final (from, to) = budgetPeriod(
            month,
            row.readNullable<String>('start_day'),
          );
          final date = LocalDate.parse(on);
          if (date.isBefore(from) || date.isAfter(to)) continue;
          statuses[category] = status.copyWith(
            spent: status.spent + Rupiah(row.read<int>('spent')),
          );
        }
        return statuses.values.toList();
      })
      .guarded();

  @override
  Future<Rupiah> totalCaps(LocalMonth month) => guard(() async {
    final row = await _db
        .customSelect(
          'SELECT COALESCE(SUM(b.amount), 0) AS total $_capsInForce '
          'WHERE $_budgeted',
          variables: [Variable(month.toIso())],
        )
        .getSingle();
    return Rupiah(row.read<int>('total'));
  });

  /// Writes only the row for [from], so earlier months keep their cap.
  @override
  Future<void> setCap(String categoryId, Rupiah cap, LocalMonth from) => guard(
    () => _db.transaction(() async {
      if (cap.value < 0) {
        throw const ValidationFailure('cap is below 0', field: 'amount');
      }
      final category =
          await (_db.select(_db.categories)
                ..where((c) => c.id.equals(categoryId) & c.isDeleted.equals(0)))
              .getSingleOrNull();
      if (category == null) throw NotFoundFailure('category $categoryId');
      if (category.kind != 'outcome') {
        throw const ValidationFailure(
          'only outcome categories have budgets',
          field: 'categoryId',
        );
      }

      final now = _now;
      final changed =
          await (_db.update(_db.budgets)..where(
                (b) =>
                    b.categoryId.equals(categoryId) &
                    b.effectiveFrom.equals(from.toIso()) &
                    b.isDeleted.equals(0),
              ))
              .write(
                BudgetsCompanion(
                  amount: Value(cap.value),
                  updatedAt: Value(now),
                ),
              );
      if (changed > 0) return;
      await _db
          .into(_db.budgets)
          .insert(
            BudgetsCompanion.insert(
              id: _ids.newId(),
              categoryId: categoryId,
              amount: cap.value,
              effectiveFrom: from.toIso(),
              createdAt: now,
              updatedAt: now,
            ),
          );
    }),
  );
}
