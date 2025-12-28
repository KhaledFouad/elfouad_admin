import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> deleteExtra(String id) =>
    FirebaseFirestore.instance.collection('extras').doc(id).delete();
