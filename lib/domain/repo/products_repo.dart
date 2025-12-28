import '../entities/product.dart';
abstract class ProductsRepo {
  Stream<List<Product>> watchAll();
  Future<void> upsert(Product p, {String? oldType});
  Future<void> delete(String id, String type);
}
