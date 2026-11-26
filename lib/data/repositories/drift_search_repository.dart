import 'package:drift/drift.dart';

import '../../domain/entities/search.dart';
import '../../domain/entities/tag.dart';
import '../../domain/repositories/search_repository.dart';
import '../db/app_database.dart';
import '../db/db_errors.dart';

// What unicode61 keeps. Everything else, FTS5 syntax included, separates words.
final _word = RegExp(r'[\p{L}\p{M}\p{N}]+', unicode: true);
final _space = RegExp(r'\s+');

const _entityTypes = {
  EntityType.transaction: 'transaction',
  EntityType.actionItem: 'action_item',
  EntityType.note: 'note',
};

const _score = 'bm25(search_index, 0, 0, 10, 1)';

final class DriftSearchRepository implements SearchRepository {
  DriftSearchRepository(this._db);

  final AppDatabase _db;

  /// Hits grouped by type, best bm25 first within a group; [limit] applies to
  /// each group. `#slug` words in the text are exact tag filters.
  @override
  Future<List<SearchHit>> search(SearchQuery query, {int limit = 50}) =>
      guard(() async {
        final words = <String>[];
        final tags = {for (final slug in query.tagSlugs) slug.toLowerCase()};
        for (final part in query.text.split(_space)) {
          if (part.startsWith('#')) {
            if (part.length > 1) tags.add(part.substring(1).toLowerCase());
          } else {
            words.addAll(_word.allMatches(part).map((m) => m[0]!));
          }
        }
        final types = [
          for (final type in _entityTypes.keys)
            if (query.type == null || query.type == type) type,
        ];
        if (words.isEmpty) {
          if (tags.isEmpty) return const [];
          return [
            for (final type in types)
              ...await _tagged(type, tags.toList(), limit),
          ];
        }
        // Quoted, so AND, OR, NOT and NEAR are plain words.
        final match = words.map((w) => '"$w"*').join(' ');

        final tagFilter = List.filled(
          tags.length,
          ' AND EXISTS (SELECT 1 FROM taggings g '
          'JOIN tags t ON t.id = g.tag_id AND t.is_deleted = 0 '
          'WHERE g.entity_type = search_index.entity_type '
          'AND g.entity_id = search_index.entity_id '
          'AND g.is_deleted = 0 AND t.slug = ?)',
        ).join();
        final only = types.length == 1
            ? " AND entity_type = '${_entityTypes[types.single]}'"
            : '';
        // One pass over the matches picks the best rows of every type, so a
        // broad word is not matched and ranked once per type.
        final best = [
          for (final type in types)
            'SELECT * FROM (SELECT r FROM m '
                "WHERE type = '${_entityTypes[type]}' "
                'ORDER BY score, r DESC LIMIT ?)',
        ].join(' UNION ALL ');
        // snippet() is worked out for the kept rows only. The + stops FTS5
        // from running the whole match again for each of them.
        final rows = await _db
            .customSelect(
              'WITH m AS MATERIALIZED (SELECT rowid AS r, entity_type AS type, '
              '$_score AS score FROM search_index '
              'WHERE search_index MATCH ?$only$tagFilter) '
              'SELECT entity_type, entity_id, title, '
              "snippet(search_index, 3, '', '', '…', 12) AS snippet "
              'FROM search_index WHERE search_index MATCH ? '
              'AND +rowid IN ($best) ORDER BY $_score, rowid DESC',
              variables: [
                Variable<String>(match),
                for (final slug in tags) Variable<String>(slug),
                Variable<String>(match),
                for (final _ in types) Variable<int>(limit),
              ],
            )
            .get();
        return [
          for (final type in types)
            for (final row in rows)
              if (row.read<String>('entity_type') == _entityTypes[type])
                _hit(type, row),
        ];
      });

  /// A search by tags alone, most recently changed first. It starts from the
  /// taggings: scanning the index for a rare tag reads all of it.
  Future<List<SearchHit>> _tagged(
    EntityType type,
    List<String> slugs,
    int limit,
  ) async {
    // The columns the schema triggers copy into the index.
    final (table, title, body) = switch (type) {
      EntityType.transaction => ('transactions', 'e.description', "''"),
      EntityType.actionItem => ('action_items', 'e.title', 'e.body'),
      EntityType.note => ('notes', 'e.title', 'e.body'),
    };
    final others = List.filled(
      slugs.length - 1,
      ' AND EXISTS (SELECT 1 FROM taggings o '
      'JOIN tags ot ON ot.id = o.tag_id AND ot.is_deleted = 0 '
      'WHERE o.entity_type = g.entity_type AND o.entity_id = g.entity_id '
      'AND o.is_deleted = 0 AND ot.slug = ?)',
    ).join();
    final rows = await _db
        .customSelect(
          'SELECT e.id AS entity_id, $title AS title, '
          'substr($body, 1, 100) AS snippet '
          'FROM tags t JOIN taggings g ON g.tag_id = t.id '
          'JOIN $table e ON e.id = g.entity_id AND e.is_deleted = 0 '
          'WHERE t.slug = ? AND t.is_deleted = 0 AND g.entity_type = ? '
          'AND g.is_deleted = 0$others '
          'ORDER BY e.updated_at DESC, e.id DESC LIMIT ?',
          variables: [
            Variable<String>(slugs.first),
            Variable<String>(_entityTypes[type]!),
            for (final slug in slugs.skip(1)) Variable<String>(slug),
            Variable<int>(limit),
          ],
        )
        .get();
    return [for (final row in rows) _hit(type, row)];
  }

  SearchHit _hit(EntityType type, QueryRow row) => SearchHit(
    type: type,
    entityId: row.read<String>('entity_id'),
    title: row.read<String>('title'),
    snippet: row.read<String>('snippet'),
  );

  @override
  Future<void> rebuildIndex() => guard(
    () => _db.transaction(() async {
      await _db.customStatement('DELETE FROM search_index');
      // The same columns the schema triggers copy.
      for (final (type, table, title, body) in const [
        ('transaction', 'transactions', 'description', "''"),
        ('action_item', 'action_items', 'title', 'body'),
        ('note', 'notes', 'title', 'body'),
      ]) {
        await _db.customStatement(
          'INSERT INTO search_index (entity_type, entity_id, title, body) '
          "SELECT '$type', id, $title, $body FROM $table WHERE is_deleted = 0",
        );
      }
    }),
  );
}
