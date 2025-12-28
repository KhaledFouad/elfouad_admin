// استبدل الملف كله بهذا:
class RecipeComponent {
  final String coll; // 'singles' | 'blends'
  final String itemId;
  final String name;
  final String variant;
  final double percent;

  const RecipeComponent({
    required this.coll,
    required this.itemId,
    required this.name,
    required this.variant,
    required this.percent,
  });

  RecipeComponent copyWith({
    String? coll,
    String? itemId,
    String? name,
    String? variant,
    double? percent,
  }) {
    return RecipeComponent(
      coll: coll ?? this.coll,
      itemId: itemId ?? this.itemId,
      name: name ?? this.name,
      variant: variant ?? this.variant,
      percent: percent ?? this.percent,
    );
  }

  Map<String, dynamic> toMap() => {
    'coll': coll,
    'item_id': itemId,
    'name': name,
    'variant': variant,
    'percent': percent,
  };

  static double _num(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) {
      final s = v.replaceAll(',', '.').trim();
      return double.tryParse(s) ?? 0.0;
    }
    return 0.0;
  }

  static RecipeComponent fromMap(Map<String, dynamic> m) {
    return RecipeComponent(
      coll: (m['coll'] ?? '').toString(),
      itemId: (m['item_id'] ?? m['id'] ?? '').toString(),
      name: (m['name'] ?? '').toString(),
      variant: (m['variant'] ?? '').toString(),
      percent: _num(m['percent']),
    );
  }
}
