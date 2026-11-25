import '../entities/category.dart';

abstract interface class CategoryRepository {
  Stream<List<Category>> watchAll({CategoryKind? kind});
  Future<List<CategoryRef>> refs();
  Future<Category> create(CategoryInput input);
  Future<Category> update(String id, CategoryPatch patch);
  Future<void> archive(String id);
}
