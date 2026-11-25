import '../../domain/entities/tag.dart';
import '../db/app_database.dart';
import 'column_values.dart';

extension TagRowMapper on TagRow {
  Tag toEntity() => Tag(
    id: id,
    name: name,
    slug: slug,
    color: color,
    createdAt: instant(createdAt),
    updatedAt: instant(updatedAt),
  );
}
