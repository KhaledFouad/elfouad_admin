import 'package:cloud_firestore/cloud_firestore.dart';

/// شغّل الكاش المحلي وزوّد حجمه.
/// اشتغل على موبايل (Android/iOS) وكمان بيعدّي على المنصات التانية بدون أخطاء.
Future<void> configureFirestore() async {
  final db = FirebaseFirestore.instance;

  // FlutterFire 5.x: مفيش enablePersistence() — بنستخدم Settings.
  db.settings = const Settings(
    persistenceEnabled: true, // كاش أوفلاين
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED, // سيب الكاش يكبر برحتُه
  );
}
