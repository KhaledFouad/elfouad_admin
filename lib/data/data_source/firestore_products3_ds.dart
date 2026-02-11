import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/product.dart';
import 'firestore_products_ds.dart';

/// Deprecated shim kept for backward compatibility.
@Deprecated('Use FirestoreProductsDs from firestore_products_ds.dart')
class FirestoreProducts3Ds {
  FirestoreProducts3Ds([FirebaseFirestore? db])
    : _delegate = FirestoreProductsDs(db);

  final FirestoreProductsDs _delegate;

  Stream<List<Product>> watchAll() => _delegate.watchAll();

  Future<void> upsert(Product p, {String? oldType}) {
    return _delegate.upsert(p, oldType: oldType);
  }

  Future<void> delete(String id, String type) {
    return _delegate.delete(id, type);
  }
}
