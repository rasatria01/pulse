import 'package:freezed_annotation/freezed_annotation.dart';

part 'category.freezed.dart';

enum CategoryKind { income, outcome }

@freezed
abstract class Category with _$Category {
  const factory Category({
    required String id,
    required String name,
    required String slug,
    @Default(<String>[]) List<String> aliases,
    required CategoryKind kind,
    required int color, // ARGB
    required String icon,
    required bool isSystem,
    required bool isArchived,
    required int sortOrder,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Category;
}

/// Parser snapshot.
@freezed
abstract class CategoryRef with _$CategoryRef {
  const factory CategoryRef({
    required String id,
    required String slug,
    @Default(<String>[]) List<String> aliases,
    required CategoryKind kind,
  }) = _CategoryRef;
}

@freezed
abstract class CategoryInput with _$CategoryInput {
  const factory CategoryInput({
    required String name,
    required String slug,
    @Default(<String>[]) List<String> aliases,
    required CategoryKind kind,
    required int color,
    required String icon,
    @Default(0) int sortOrder,
  }) = _CategoryInput;
}

/// Null field = unchanged.
@freezed
abstract class CategoryPatch with _$CategoryPatch {
  const factory CategoryPatch({
    String? name,
    String? slug,
    List<String>? aliases,
    int? color,
    String? icon,
    int? sortOrder,
  }) = _CategoryPatch;
}
