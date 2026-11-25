import 'package:freezed_annotation/freezed_annotation.dart';

part 'tag.freezed.dart';

enum EntityType { transaction, actionItem, note }

@freezed
abstract class Tag with _$Tag {
  const factory Tag({
    required String id,
    required String name,
    required String slug,
    int? color,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Tag;
}
