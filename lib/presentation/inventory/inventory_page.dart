import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/product.dart';
import 'providers.dart';
import '../../core/widgets/branded_appbar.dart';

class InventoryPage extends ConsumerWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(productsStreamProvider);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: const BrandedAppBar(title: 'المخزون'),
        body: s.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('خطأ تحميل المخزون: $e')),
          data: (list) {
            final singles = list.where((p) => p.type == 'single').toList();
            final blends = list.where((p) => p.type == 'ready_blend').toList();
            if (singles.isEmpty && blends.isEmpty) {
              return const Center(child: Text('لا توجد منتجات قابلة للعرض'));
            }
            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (singles.isNotEmpty)
                  _group(context, 'أصناف منفردة', singles),
                if (blends.isNotEmpty) _group(context, 'توليفات جاهزة', blends),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _group(BuildContext context, String title, List<Product> items) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...items.map((p) => _stockTile(context, p)),
          ],
        ),
      ),
    );
  }

  Widget _stockTile(BuildContext context, Product p) {
    final grams = p.stockGrams;
    final warn = grams <= 2500;
    final barColor = warn ? Colors.redAccent : const Color(0xFF543824);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (p.roast == null || p.roast!.isEmpty)
                      ? p.name
                      : '${p.name} — ${p.roast}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: warn
                      ? Colors.red.withOpacity(0.08)
                      : Colors.brown.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: warn ? Colors.redAccent : Colors.brown.shade100,
                  ),
                ),
                child: Text(
                  '${grams.toStringAsFixed(0)} جم',
                  style: TextStyle(
                    color: warn ? Colors.red : Colors.brown.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 12,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerRight,
              widthFactor: (grams / 10000).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
