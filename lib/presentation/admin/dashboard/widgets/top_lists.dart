import 'package:elfouad_admin/domain/entities/aggregates.dart';
import 'package:flutter/material.dart';

class TopLists extends StatelessWidget {
  final List<DrinkAgg> drinks;
  final List<BeansAgg> beans;
  const TopLists({super.key, required this.drinks, required this.beans});

  @override
  Widget build(BuildContext context) {
    List<DrinkAgg> topDrinksByCups = [...drinks]
      ..sort((a, b) => b.cups.compareTo(a.cups));
    List<DrinkAgg> topDrinksByProfit = [...drinks]
      ..sort((a, b) => b.profit.compareTo(a.profit));
    List<BeansAgg> topBeansByGrams = [...beans]
      ..sort((a, b) => b.grams.compareTo(a.grams));
    List<BeansAgg> topBeansByProfit = [...beans]
      ..sort((a, b) => b.profit.compareTo(a.profit));

    topDrinksByCups = topDrinksByCups.take(5).toList();
    topDrinksByProfit = topDrinksByProfit.take(5).toList();
    topBeansByGrams = topBeansByGrams.take(5).toList();
    topBeansByProfit = topBeansByProfit.take(5).toList();

    Widget tile(String title, String label, String value) => ListTile(
      dense: true,
      title: Text(title, overflow: TextOverflow.ellipsis),
      trailing: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(label),
    );

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Top 5 Drinks — أكواب',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      ...topDrinksByCups.map(
                        (e) => tile(e.type, 'أكواب', e.cups.toString()),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Top 5 Drinks — ربح',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      ...topDrinksByProfit.map(
                        (e) =>
                            tile(e.type, 'الربح', e.profit.toStringAsFixed(2)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Top 5 Beans — جرامات',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      ...topBeansByGrams.map(
                        (e) =>
                            tile(e.family, 'جرام', e.grams.toStringAsFixed(0)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Top 5 Beans — ربح',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      ...topBeansByProfit.map(
                        (e) => tile(
                          e.family,
                          'الربح',
                          e.profit.toStringAsFixed(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
