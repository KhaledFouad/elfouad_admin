import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/product.dart';
import '../mappers/product_mapper.dart';

/// نفس الاسم القديم لكن بيدير 3 كوليكشن: drinks / singles / blends
class FirestoreProductsDs {
  final FirebaseFirestore _db;
  FirestoreProductsDs([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  /// يحوّل اسم النوع إلى اسم الكوليكشن
  String _colForType(String type) {
    switch (type) {
      case 'single':
        return 'singles';
      case 'ready_blend':
        return 'blends';
      case 'drink':
      default:
        return 'drinks';
    }
  }

  /// Stream موحّد من التلات كوليكشن
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

  /// upsert ذكي:
  /// - لو id فاضي: يضيف في الكوليكشن المناسب حسب النوع.
  /// - لو id موجود: يحدّثه في مكانه لو لاقاه، ولو لاقاه في كوليكشن تاني بينقله،
  ///   ولو مش لاقيه خالص ينشئه في الكوليكشن المناسب بنفس الـ id.
  Future<void> upsert(Product p) async {
    final targetCol = _colForType(p.type);

    if (p.id.isEmpty) {
      // إنشاء جديد
      await _db.collection(targetCol).add(ProductMapper.toMap(p));
      return;
    }

    // محاولة العثور على الـ doc في أي كوليكشن من التلاتة
    final docSingles = await _db.collection('singles').doc(p.id).get();
    final docBlends = await _db.collection('blends').doc(p.id).get();
    final docDrinks = await _db.collection('drinks').doc(p.id).get();

    final existsInSingles = docSingles.exists;
    final existsInBlends = docBlends.exists;
    final existsInDrinks = docDrinks.exists;

    // لو موجود في الكوليكشن الهدف → نزود/نحدّث
    if ((targetCol == 'singles' && existsInSingles) ||
        (targetCol == 'blends' && existsInBlends) ||
        (targetCol == 'drinks' && existsInDrinks)) {
      await _db
          .collection(targetCol)
          .doc(p.id)
          .set(ProductMapper.toMap(p), SetOptions(merge: true));
      return;
    }

    // لو موجود في كوليكشن تاني → نحذفه من هناك وننشئه/نكتبه في الهدف بنفس الـ id
    if (existsInSingles && targetCol != 'singles') {
      await _db.collection('singles').doc(p.id).delete();
    }
    if (existsInBlends && targetCol != 'blends') {
      await _db.collection('blends').doc(p.id).delete();
    }
    if (existsInDrinks && targetCol != 'drinks') {
      await _db.collection('drinks').doc(p.id).delete();
    }

    await _db
        .collection(targetCol)
        .doc(p.id)
        .set(ProductMapper.toMap(p), SetOptions(merge: true));
  }

  /// يحذف الـ id من أول كوليكشن يلاقيه فيه
  Future<void> delete(String id) async {
    final docSingles = await _db.collection('singles').doc(id).get();
    if (docSingles.exists) {
      await _db.collection('singles').doc(id).delete();
      return;
    }
    final docBlends = await _db.collection('blends').doc(id).get();
    if (docBlends.exists) {
      await _db.collection('blends').doc(id).delete();
      return;
    }
    final docDrinks = await _db.collection('drinks').doc(id).get();
    if (docDrinks.exists) {
      await _db.collection('drinks').doc(id).delete();
      return;
    }
    // لو مش موجود في أي مكان: لا شيء
  }
}
