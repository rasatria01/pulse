import '../entities/tag.dart';

abstract interface class TagRepository {
  Stream<List<Tag>> watchAll();
  Future<List<Tag>> ensure(List<String> slugs); // creates missing tags
  Future<void> softDelete(String id);
  Future<void> setTags(EntityType type, String entityId, List<String> tagIds);
}
