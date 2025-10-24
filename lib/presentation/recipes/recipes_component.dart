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

  static RecipeComponent fromMap(Map<String, dynamic> m) {
    double _n(v) =>
        (v is num) ? v.toDouble() : double.tryParse('${v ?? 0}') ?? 0.0;
    return RecipeComponent(
      coll: (m['coll'] ?? '').toString(),
      itemId: (m['item_id'] ?? m['id'] ?? '').toString(),
      name: (m['name'] ?? '').toString(),
      variant: (m['variant'] ?? '').toString(),
      percent: _n(m['percent']),
    );
  }
}
