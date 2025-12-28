import 'package:cloud_firestore/cloud_firestore.dart';

import 'recipe_component.dart';

class RecipeListItem {
  final String id;
  final String name;
  final String variant;
  final List<RecipeComponent> components;

  const RecipeListItem({
    required this.id,
    required this.name,
    required this.variant,
    required this.components,
  });

  factory RecipeListItem.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final m = doc.data();
    final comps = (m['components'] as List? ?? const [])
        .map(
          (e) => (e is Map) ? e.cast<String, dynamic>() : <String, dynamic>{},
        )
        .map(RecipeComponent.fromMap)
        .toList();
    return RecipeListItem(
      id: doc.id,
      name: (m['name'] ?? '').toString(),
      variant: (m['variant'] ?? '').toString(),
      components: comps,
    );
  }

  String get title => variant.isEmpty ? name : '$name - $variant';

  int get sumPercent => components.fold<int>(
        0,
        (s, c) => s + (c.percent.isNaN ? 0 : c.percent.round()),
      );

  bool get isComplete => sumPercent == 100;
}
