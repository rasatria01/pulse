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
        if (words.isEmpty && tags.isEmpty) return const [];
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
        // snippet() and bm25() need a MATCH; a tag-only search lists the most
        // recently indexed rows first.
        final sql = match.isEmpty
            ? 'SELECT entity_id, title, substr(body, 1, 100) AS snippet '
                  'FROM search_index WHERE entity_type = ?$tagFilter '
                  'ORDER BY rowid DESC LIMIT ?'
            : 'SELECT entity_id, title, '
                  "snippet(search_index, 3, '', '', '…', 12) AS snippet "
                  'FROM search_index WHERE search_index MATCH ? '
                  'AND entity_type = ?$tagFilter '
                  'ORDER BY bm25(search_index, 0, 0, 10, 1), rowid DESC '
                  'LIMIT ?';

        final hits = <SearchHit>[];
        for (final MapEntry(key: type, value: column) in _entityTypes.entries) {
          if (query.type != null && query.type != type) continue;
          final rows = await _db
              .customSelect(
                sql,
                variables: [
                  if (match.isNotEmpty) Variable<String>(match),
                  Variable<String>(column),
                  for (final slug in tags) Variable<String>(slug),
                  Variable<int>(limit),
                ],
              )
              .get();
          hits.addAll([
            for (final row in rows)
              SearchHit(
                type: type,
                entityId: row.read<String>('entity_id'),
                title: row.read<String>('title'),
                snippet: row.read<String>('snippet'),
              ),
          ]);
        }
        return hits;
      });

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
