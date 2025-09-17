import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repo/products_repo_impl.dart';
import '../../data/data_source/firestore_products3_ds.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/product.dart';

final _dsProvider = Provider<FirestoreProducts3Ds>((ref)=> FirestoreProducts3Ds(FirebaseFirestore.instance));
final productsRepoProvider = Provider<ProductsRepoImpl>((ref)=> ProductsRepoImpl(ref.read(_dsProvider)));

final productsStreamProvider = StreamProvider<List<Product>>((ref)=> ref.read(productsRepoProvider).watchAll());
