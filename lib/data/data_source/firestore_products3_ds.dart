import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/product.dart';
import '../mappers/product_mapper.dart';

class FirestoreProducts3Ds {
  final FirebaseFirestore _db;
  FirestoreProducts3Ds([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  Stream<List<Product>> watchAll() {
    final ctrl = StreamController<List<Product>>.broadcast();
    List<Product> singles = [], blends = [], drinks = [];
    void emit() {
      final list = <Product>[...singles, ...blends, ...drinks];
      list.sort((a, b) => a.name.compareTo(b.name));
      ctrl.add(list);
    }

    final sub1 = _db.collection('singles').orderBy('name').snapshots().listen((
      snap,
    ) {
      singles = snap.docs
          .map((d) => ProductMapper.fromMap(d.id, d.data(), 'singles'))
          .toList();
      emit();
    });
    final sub2 = _db.collection('blends').orderBy('name').snapshots().listen((
      snap,
    ) {
      blends = snap.docs
          .map((d) => ProductMapper.fromMap(d.id, d.data(), 'blends'))
          .toList();
      emit();
    });
    final sub3 = _db.collection('drinks').orderBy('name').snapshots().listen((
      snap,
    ) {
      drinks = snap.docs
          .map((d) => ProductMapper.fromMap(d.id, d.data(), 'drinks'))
          .toList();
      emit();
    });

    ctrl.onCancel = () async {
      await sub1.cancel();
      await sub2.cancel();
      await sub3.cancel();
    };
    return ctrl.stream;
  }

  String _colForType(String type) => type == 'single'
      ? 'singles'
      : type == 'ready_blend'
      ? 'blends'
      : 'drinks';

  Future<void> upsert(Product p, {String? oldType}) async {
    final colNew = _colForType(p.type);
    if (p.id.isEmpty) {
      await _db.collection(colNew).add(ProductMapper.toMap(p));
    } else {
      final colOld = _colForType(oldType ?? p.type);
      if (colOld != colNew) {
        final oldRef = _db.collection(colOld).doc(p.id);
        final oldSnap = await oldRef.get();
        if (oldSnap.exists) await oldRef.delete();
        await _db
            .collection(colNew)
            .doc(p.id)
            .set(ProductMapper.toMap(p), SetOptions(merge: true));
      } else {
        await _db
            .collection(colNew)
            .doc(p.id)
            .set(ProductMapper.toMap(p), SetOptions(merge: true));
      }
    }
  }

  Future<void> delete(String id, String type) async {
    final col = _colForType(type);
    await _db.collection(col).doc(id).delete();
  }
}
