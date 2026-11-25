import 'package:drift/drift.dart';

/// Select column `tag_ids`: the live tags of the row aliased [alias].
String tagIdsColumn(String entityType, String alias) =>
    '(SELECT group_concat(g.tag_id) FROM taggings g '
    'JOIN tags tg ON tg.id = g.tag_id AND tg.is_deleted = 0 '
    "WHERE g.entity_type = '$entityType' AND g.entity_id = $alias.id "
    'AND g.is_deleted = 0) AS tag_ids';

List<String> readTagIds(QueryRow row) =>
    (row.readNullable<String>('tag_ids')?.split(',') ?? [])..sort();
