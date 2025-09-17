String arabicDrinkType(String t) {
  final s = t.toLowerCase();
  if (s.contains('turk') || s.contains('تركي')) return 'تركي';
  if (s.contains('french') || s.contains('فرن')) return 'فرنساوي';
  if (s.contains('espresso') || s.contains('اسبريسو')) return 'إسبريسو';
  if (s.contains('latte') || s.contains('لاتيه')) return 'لاتيه';
  if (s.contains('capp') || s.contains('كابتش')) return 'كابتشينو';
  if (s.contains('mocha') || s.contains('موكا')) return 'موكا';
  // ... زوّد حسب قائمتك
  return t.isEmpty ? 'غير مُصنّف' : t; // ما نرميش في Others
}

String arabicBeanFamily(String f) {
  final s = f.toLowerCase();
  if (s.contains('classic') || s.contains('كلاسي')) return 'كلاسيك';
  if (s.contains('special') || s.contains('سبيش')) return 'سبيشيال';
  if (s.contains('custom') || s.contains('مخصوص')) return 'مخصوص';
  // Single origins (لو محفوظ country)
  if (s.contains('brazil') || s.contains('برازي')) return 'برازيلي';
  if (s.contains('ethiop') || s.contains('حبش')) return 'حبشي';
  if (s.contains('colomb') || s.contains('كولوم')) return 'كولومبيا';
  // ...
  return f.isEmpty ? 'غير مُصنّف' : f;
}
