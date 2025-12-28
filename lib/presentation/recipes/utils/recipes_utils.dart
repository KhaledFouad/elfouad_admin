import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/recipe_list_item.dart';
import '../models/recipe_price_cost.dart';

Future<RecipePriceCost> calcRecipePriceCost(RecipeListItem recipe) async {
  final fs = FirebaseFirestore.instance;
  double pricePerKg = 0.0;
  double costPerKg = 0.0;

  for (final c in recipe.components) {
    final snap = await fs.collection(c.coll).doc(c.itemId).get();
    final m = snap.data() ?? {};

    double numOf(List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v is num) return v.toDouble();
      }
      return 0.0;
    }

    final sell = numOf(['sellPricePerKg', 'sellPerKg', 'sell_price_per_kg']);
    final cost = numOf(['costPricePerKg', 'costPerKg', 'cost_price_per_kg']);

    pricePerKg += sell * (c.percent / 100.0);
    costPerKg += cost * (c.percent / 100.0);
  }

  return RecipePriceCost(pricePerKg: pricePerKg, costPerKg: costPerKg);
}
