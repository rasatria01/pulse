import 'package:drift/drift.dart';

import '../../core/clock.dart';
import '../../core/failures.dart';
import '../../core/ids.dart';
import '../../domain/entities/category.dart';
import '../../domain/repositories/category_repository.dart';
import '../db/app_database.dart';
import '../db/db_errors.dart';
import '../mappers/category_mapper.dart';
import 'input_checks.dart';

final class DriftCategoryRepository implements CategoryRepository {
  DriftCategoryRepository(this._db, this._clock, this._ids);

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _ids;

  int get _now => _clock.nowUtc().millisecondsSinceEpoch;

  @override
  Stream<List<Category>> watchAll({
    CategoryKind? kind,
    bool includeArchived = false,
  }) => _select(
    kind: kind,
    includeArchived: includeArchived,
  ).watch().map((rows) => [for (final row in rows) row.toEntity()]).guarded();

  @override
  Future<List<CategoryRef>> refs() => guard(() async {
    final rows = await _select(includeArchived: false).get();
    return [for (final row in rows) row.toRef()];
  });

  @override
  Future<Category> create(CategoryInput input) => guard(() async {
    final id = _ids.newId();
    final now = _now;
    await _db
        .into(_db.categories)
        .insert(
          CategoriesCompanion.insert(
            id: id,
            name: requireName(input.name),
            slug: requireSlug(input.slug),
            aliases: Value(joinAliases(input.aliases)),
            kind: input.kind.name,
            color: input.color,
            icon: input.icon,
            sortOrder: Value(input.sortOrder),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return (await _require(id)).toEntity();
  });

  @override
  Future<Category> update(String id, CategoryPatch patch) => guard(
    () => _db.transaction(() async {
      await _require(id);
      final name = patch.name;
      final slug = patch.slug;
      final aliases = patch.aliases;
      await _write(
        id,
        CategoriesCompanion(
          name: Value.absentIfNull(name == null ? null : requireName(name)),
          slug: Value.absentIfNull(slug == null ? null : requireSlug(slug)),
          aliases: Value.absentIfNull(
            aliases == null ? null : joinAliases(aliases),
          ),
          color: Value.absentIfNull(patch.color),
          icon: Value.absentIfNull(patch.icon),
          sortOrder: Value.absentIfNull(patch.sortOrder),
          updatedAt: Value(_now),
        ),
      );
      return (await _require(id)).toEntity();
    }),
  );

  @override
  Future<void> archive(String id) => guard(
    () => _db.transaction(() async {
      if ((await _require(id)).isSystem == 1) {
        throw const ValidationFailure('system categories cannot be archived');
      }
      await _write(
        id,
        CategoriesCompanion(isArchived: const Value(1), updatedAt: Value(_now)),
      );
    }),
  );

  SimpleSelectStatement<Categories, CategoryRow> _select({
    CategoryKind? kind,
    required bool includeArchived,
  }) => _db.select(_db.categories)
    ..where(
      (c) => Expression.and([
        c.isDeleted.equals(0),
        if (!includeArchived) c.isArchived.equals(0),
        if (kind != null) c.kind.equals(kind.name),
      ]),
    )
    ..orderBy([
      (c) => OrderingTerm(expression: c.sortOrder),
      (c) => OrderingTerm(expression: c.name),
    ]);

  Future<CategoryRow> _require(String id) async {
    final row = await (_db.select(
      _db.categories,
    )..where((c) => c.id.equals(id) & c.isDeleted.equals(0))).getSingleOrNull();
    if (row == null) throw NotFoundFailure('category $id');
    return row;
  }

  Future<void> _write(String id, CategoriesCompanion values) =>
      (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(values);
}
