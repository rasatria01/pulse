import '../../domain/entities/category.dart';
import '../db/app_database.dart';
import 'column_values.dart';

extension CategoryRowMapper on CategoryRow {
  Category toEntity() => Category(
    id: id,
    name: name,
    slug: slug,
    aliases: splitAliases(aliases),
    kind: CategoryKind.values.byName(kind),
    color: color,
    icon: icon,
    isSystem: isSystem == 1,
    isArchived: isArchived == 1,
    sortOrder: sortOrder,
    createdAt: instant(createdAt),
    updatedAt: instant(updatedAt),
  );

  CategoryRef toRef() => CategoryRef(
    id: id,
    slug: slug,
    aliases: splitAliases(aliases),
    kind: CategoryKind.values.byName(kind),
  );
}
