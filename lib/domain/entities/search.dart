import 'package:freezed_annotation/freezed_annotation.dart';

import 'tag.dart';

part 'search.freezed.dart';

@freezed
abstract class SearchQuery with _$SearchQuery {
  const factory SearchQuery({
    @Default('') String text, // words, prefix-matched
    @Default(<String>[]) List<String> tagSlugs, // exact filters
    EntityType? type,
  }) = _SearchQuery;
}

@freezed
abstract class SearchHit with _$SearchHit {
  const factory SearchHit({
    required EntityType type,
    required String entityId,
    required String title,
    @Default('') String snippet,
  }) = _SearchHit;
}
