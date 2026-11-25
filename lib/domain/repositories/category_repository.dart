import '../entities/category.dart';

abstract interface class CategoryRepository {
  Stream<List<Category>> watchAll({
    CategoryKind? kind,
    bool includeArchived = false,
  });
  Future<List<CategoryRef>> refs(); // parser snapshot, archived excluded
  Future<Category> create(CategoryInput input);
  Future<Category> update(String id, CategoryPatch patch);
  Future<void> archive(String id);
}
