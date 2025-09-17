import '../../domain/entities/product.dart';
import '../../domain/repo/products_repo.dart';
import '../data_source/firestore_products3_ds.dart';

class ProductsRepoImpl implements ProductsRepo {
  final FirestoreProducts3Ds ds;
  ProductsRepoImpl(this.ds);
  @override
  Stream<List<Product>> watchAll() => ds.watchAll();
  @override
  Future<void> upsert(Product p, {String? oldType}) => ds.upsert(p, oldType: oldType);
  @override
  Future<void> delete(String id, String type) => ds.delete(id, type);
}
