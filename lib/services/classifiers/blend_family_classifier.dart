class BlendFamilyClassifier {
  static String classify(String name) {
    final n = name.toLowerCase();
    if (n.contains('كلاسيك') || n.contains('classic')) return 'Classic';
    if (n.contains('مخصوص') || n.contains('custom')) return 'Custom';
    if (n.contains('سبيش') || n.contains('special')) return 'Special';
    if (n.contains('برازي') || n.contains('brazil')) return 'Brazil';
    if (n.contains('حبش') || n.contains('ethiop')) return 'Ethiopia';
    if (n.contains('هندي') || n.contains('india')) return 'India';
    if (n.contains('كولوم') || n.contains('colomb')) return 'Colombia';
    return 'Other';
  }
}
