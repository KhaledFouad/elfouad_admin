import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_admin/services/archive/archive_service.dart';

Future<void> deleteExtra(String id) => archiveThenDelete(
  srcRef: FirebaseFirestore.instance.collection('extras').doc(id),
  kind: 'extra',
  reason: 'manual_delete',
);

Future<void> deleteTahwiga(String id) => archiveThenDelete(
  srcRef: FirebaseFirestore.instance.collection('tahwiga_options').doc(id),
  kind: 'extra',
  reason: 'manual_delete',
);
