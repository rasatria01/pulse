import 'package:drift/drift.dart';

import '../../core/clock.dart';
import '../../core/failures.dart';
import '../../core/ids.dart';
import '../../domain/entities/tag.dart';
import '../../domain/repositories/tag_repository.dart';
import '../db/app_database.dart';
import '../db/db_errors.dart';
import '../mappers/tag_mapper.dart';
import 'input_checks.dart';

final class DriftTagRepository implements TagRepository {
  DriftTagRepository(this._db, this._clock, this._ids);

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _ids;

  int get _now => _clock.nowUtc().millisecondsSinceEpoch;

  @override
  Stream<List<Tag>> watchAll() =>
      (_db.select(_db.tags)
            ..where((t) => t.isDeleted.equals(0))
            ..orderBy([(t) => OrderingTerm(expression: t.slug)]))
          .watch()
          .map((rows) => [for (final row in rows) row.toEntity()])
          .guarded();

  @override
  Future<List<Tag>> ensure(List<String> slugs) => guard(
    () => _db.transaction(() async {
      // Keyed by slug; the first spelling becomes the display name.
      final wanted = <String, String>{};
      for (final name in slugs) {
        wanted.putIfAbsent(requireSlug(name), name.trim);
      }

      final result = <Tag>[];
      for (final MapEntry(key: slug, value: name) in wanted.entries) {
        var row =
            await (_db.select(_db.tags)
                  ..where((t) => t.slug.equals(slug) & t.isDeleted.equals(0)))
                .getSingleOrNull();
        final now = _now;
        row ??= await _db
            .into(_db.tags)
            .insertReturning(
              TagsCompanion.insert(
                id: _ids.newId(),
                name: name,
                slug: slug,
                createdAt: now,
                updatedAt: now,
              ),
            );
        result.add(row.toEntity());
      }
      return result;
    }),
  );

  @override
  Future<void> softDelete(String id) => guard(
    () => _db.transaction(() async {
      final now = _now;
      final changed =
          await (_db.update(_db.tags)..where((t) => t.id.equals(id))).write(
            TagsCompanion(isDeleted: const Value(1), updatedAt: Value(now)),
          );
      if (changed == 0) throw NotFoundFailure('tag $id');
      await (_db.update(
        _db.taggings,
      )..where((g) => g.tagId.equals(id) & g.isDeleted.equals(0))).write(
        TaggingsCompanion(isDeleted: const Value(1), updatedAt: Value(now)),
      );
    }),
  );

  @override
  Future<void> setTags(EntityType type, String entityId, List<String> tagIds) =>
      guard(
        () => _db.transaction(() async {
          final (entityType, table) = switch (type) {
            EntityType.transaction => ('transaction', 'transactions'),
            EntityType.actionItem => ('action_item', 'action_items'),
            EntityType.note => ('note', 'notes'),
          };

          // taggings has no foreign key to the entity, so check it here. A
          // soft-deleted entity counts: Undo clears the tags after deleting.
          final entity = await _db
              .customSelect(
                'SELECT 1 FROM $table WHERE id = ?',
                variables: [Variable(entityId)],
              )
              .get();
          if (entity.isEmpty) throw NotFoundFailure('$entityType $entityId');

          final wanted = tagIds.toSet();
          final live = await (_db.select(
            _db.tags,
          )..where((t) => t.id.isIn(wanted) & t.isDeleted.equals(0))).get();
          if (live.length != wanted.length) throw const NotFoundFailure('tag');

          final now = _now;
          await (_db.update(_db.taggings)..where(
                (g) =>
                    g.entityType.equals(entityType) &
                    g.entityId.equals(entityId) &
                    g.isDeleted.equals(0) &
                    g.tagId.isNotIn(wanted),
              ))
              .write(
                TaggingsCompanion(
                  isDeleted: const Value(1),
                  updatedAt: Value(now),
                ),
              );
          for (final tagId in wanted) {
            await _db
                .into(_db.taggings)
                .insert(
                  TaggingsCompanion.insert(
                    tagId: tagId,
                    entityType: entityType,
                    entityId: entityId,
                    createdAt: now,
                    updatedAt: now,
                  ),
                  onConflict: DoUpdate(
                    (_) => TaggingsCompanion(
                      isDeleted: const Value(0),
                      updatedAt: Value(now),
                    ),
                  ),
                );
          }
        }),
      );
}
