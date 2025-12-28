class DrinkClassifier {
  static String classify(String name) {
    final n = name.toLowerCase();
    if (n.contains('تركي') || n.contains('turk')) return 'Turkish';
    if (n.contains('فرن') || n.contains('فرنسي') || n.contains('french')) return 'French';
    if (n.contains('اسبر') || n.contains('espresso')) return 'Espresso';
    if (n.contains('كابتش') || n.contains('cappuccino')) return 'Cappuccino';
    if (n.contains('لاتيه') || n.contains('latte')) return 'Latte';
    if (n.contains('موكا') || n.contains('mocha')) return 'Mocha';
    return 'Other';
  }
}
