import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_admin/services/archive/archive_service.dart';

import '../../domain/entities/product.dart';
import '../mappers/product_mapper.dart';

/// Canonical Firestore datasource for products collections.
class FirestoreProductsDs {
  final FirebaseFirestore _db;

  FirestoreProductsDs([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  Stream<List<Product>> watchAll() {
    final ctrl = StreamController<List<Product>>.broadcast();
    List<Product> singles = [];
    List<Product> blends = [];
    List<Product> drinks = [];

    void emit() {
      final list = <Product>[...singles, ...blends, ...drinks];
      list.sort((a, b) => a.name.compareTo(b.name));
      ctrl.add(list);
    }

    final subSingles = _db
        .collection('singles')
        .orderBy('name')
        .snapshots()
        .listen((snap) {
          singles = snap.docs
              .map((d) => ProductMapper.fromMap(d.id, d.data(), 'singles'))
              .toList();
          emit();
        });

    final subBlends = _db
        .collection('blends')
        .orderBy('name')
        .snapshots()
        .listen((snap) {
          blends = snap.docs
              .map((d) => ProductMapper.fromMap(d.id, d.data(), 'blends'))
              .toList();
          emit();
        });

    final subDrinks = _db
        .collection('drinks')
        .orderBy('name')
        .snapshots()
        .listen((snap) {
          drinks = snap.docs
              .map((d) => ProductMapper.fromMap(d.id, d.data(), 'drinks'))
              .toList();
          emit();
        });

    ctrl.onCancel = () async {
      await subSingles.cancel();
      await subBlends.cancel();
      await subDrinks.cancel();
    };

    return ctrl.stream;
  }

  String _colForType(String type) => type == 'single'
      ? 'singles'
      : type == 'ready_blend'
      ? 'blends'
      : 'drinks';

  String _kindForCollection(String col) {
    switch (col) {
      case 'singles':
        return 'product_single';
      case 'blends':
        return 'blend';
      case 'drinks':
      default:
        return 'drink';
    }
  }

  Future<void> upsert(Product p, {String? oldType}) async {
    final colNew = _colForType(p.type);
    if (p.id.isEmpty) {
      await _db.collection(colNew).add(ProductMapper.toMap(p));
      return;
    }

    final colOld = _colForType(oldType ?? p.type);
    if (colOld != colNew) {
      final oldRef = _db.collection(colOld).doc(p.id);
      final oldSnap = await oldRef.get();
      if (oldSnap.exists) {
        await archiveThenDelete(
          srcRef: oldRef,
          kind: _kindForCollection(colOld),
          reason: 'move',
        );
      }
      await _db
          .collection(colNew)
          .doc(p.id)
          .set(ProductMapper.toMap(p), SetOptions(merge: true));
      return;
    }

    await _db
        .collection(colNew)
        .doc(p.id)
        .set(ProductMapper.toMap(p), SetOptions(merge: true));
  }

  Future<void> delete(String id, [String? type]) async {
    final normalizedType = (type ?? '').trim();
    if (normalizedType.isNotEmpty) {
      final col = _colForType(normalizedType);
      await archiveThenDelete(
        srcRef: _db.collection(col).doc(id),
        kind: _kindForCollection(col),
        reason: 'manual_delete',
      );
      return;
    }

    final docSingles = await _db.collection('singles').doc(id).get();
    if (docSingles.exists) {
      await archiveThenDelete(
        srcRef: _db.collection('singles').doc(id),
        kind: 'product_single',
        reason: 'manual_delete',
      );
      return;
    }

    final docBlends = await _db.collection('blends').doc(id).get();
    if (docBlends.exists) {
      await archiveThenDelete(
        srcRef: _db.collection('blends').doc(id),
        kind: 'blend',
        reason: 'manual_delete',
      );
      return;
    }

    final docDrinks = await _db.collection('drinks').doc(id).get();
    if (docDrinks.exists) {
      await archiveThenDelete(
        srcRef: _db.collection('drinks').doc(id),
        kind: 'drink',
        reason: 'manual_delete',
      );
    }
  }
}
