import '../entities/search.dart';

abstract interface class SearchRepository {
  Future<List<SearchHit>> search(SearchQuery query, {int limit = 50});
  Future<void> rebuildIndex(); // after restore
}
