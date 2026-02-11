import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DeltaCache {
  static const _kPrefix = 'delta_cache__';

  static String _key(String collection) => '$_kPrefix$collection';
  static String _keySync(String collection) => '$_kPrefix${collection}__last';

  static Future<List<Map<String, dynamic>>> read(String collection) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key(collection));
    if (raw == null) return [];
    final List list = jsonDecode(raw);
    return list.cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  static Future<void> write(
    String collection,
    List<Map<String, dynamic>> docs,
  ) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key(collection), jsonEncode(docs));
  }

  static Future<DateTime?> readLastSync(String collection) async {
    final sp = await SharedPreferences.getInstance();
    final s = sp.getString(_keySync(collection));
    if (s == null) return null;
    return DateTime.tryParse(s)?.toUtc();
  }

  static Future<void> writeLastSync(String collection, DateTime t) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_keySync(collection), t.toUtc().toIso8601String());
  }
}
