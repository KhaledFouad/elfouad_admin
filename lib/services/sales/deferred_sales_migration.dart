import 'package:cloud_firestore/cloud_firestore.dart';

Future<int> migrateDeferredSalesIfNeeded({
  FirebaseFirestore? firestore,
}) async {
  final db = firestore ?? FirebaseFirestore.instance;
  final metaRef = db.collection('meta').doc('deferred_sales_migration');

  try {
    final metaSnap = await metaRef.get();
    final done = metaSnap.data()?['done'] == true;
    if (done) return 0;
  } catch (_) {}

  final combined =
      <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

  try {
    final deferredSnap = await db
        .collection('sales')
        .where('is_deferred', isEqualTo: true)
        .get();
    for (final doc in deferredSnap.docs) {
      combined[doc.id] = doc;
    }
  } catch (_) {}

  try {
    final creditSnap = await db
        .collection('sales')
        .where('is_credit', isEqualTo: true)
        .get();
    for (final doc in creditSnap.docs) {
      combined.putIfAbsent(doc.id, () => doc);
    }
  } catch (_) {}

  if (combined.isEmpty) {
    await metaRef.set({
      'done': true,
      'moved': 0,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return 0;
  }

  WriteBatch batch = db.batch();
  int ops = 0;
  int moved = 0;

  for (final doc in combined.values) {
    final data = doc.data();
    data['is_deferred'] = true;

    final dest = db.collection('deferred_sales').doc(doc.id);
    batch.set(dest, data, SetOptions(merge: true));
    batch.delete(doc.reference);
    moved += 1;
    ops += 2;

    if (ops >= 400) {
      await batch.commit();
      batch = db.batch();
      ops = 0;
    }
  }

  if (ops > 0) {
    await batch.commit();
  }

  await metaRef.set({
    'done': true,
    'moved': moved,
    'updated_at': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  return moved;
}
