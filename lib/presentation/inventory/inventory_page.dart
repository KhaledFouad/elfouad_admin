import 'package:awesome_drawer_bar/awesome_drawer_bar.dart';
import 'package:elfouad_admin/presentation/inventory/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'widgets/inventory_tile.dart';

class InventoryPage extends ConsumerWidget {
  const InventoryPage({super.key});
  static const route = '/inventory';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final max = ref.watch(inventoryMaxStockProvider);
    final list = ref.watch(inventoryListForTabProvider);
    final tab = ref.watch(inventoryTabProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(24),
            ),
            child: AppBar(
              automaticallyImplyLeading: false,
              leading: IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => AwesomeDrawerBar.of(context)?.toggle(),
              ),
              title: const Text(
                "المخزون",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 35,
                  color: Colors.white,
                ),
              ),
              centerTitle: true,
              elevation: 8,
              backgroundColor: Colors.transparent,

              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF5D4037), Color(0xFF795548)],
                  ),
                ),
              ),
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          children: [
            // Chips
            Wrap(
              spacing: 8,
              children: [
                _chip(ref, 'الكل', InventoryTab.all, tab),
                // _chip(ref, 'المشروبات', InventoryTab.drinks, tab),
                _chip(ref, 'الأصناف المنفردة', InventoryTab.singles, tab),
                _chip(ref, 'التوليفات', InventoryTab.blends, tab),
              ],
            ),
            const SizedBox(height: 8),

            if (tab == InventoryTab.drinks)
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('المشروبات لا تُدار كمخزون جرامات هنا.'),
                ),
              )
            else if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('لا توجد عناصر')),
              )
            else
              Column(
                children: list
                    .map(
                      (r) => InventoryTile(
                        row: r,
                        maxStockForBar: max,
                        // onEdit: () => _openEdit(context, r),
                        // onDelete: () => _confirmDelete(context, r),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chip(WidgetRef ref, String label, InventoryTab me, InventoryTab cur) {
    final selected = me == cur;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => ref.read(inventoryTabProvider.notifier).state = me,
      labelStyle: TextStyle(
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
      ),
    );
  }

  // PreferredSizeWidget _bar(BuildContext context) {
  //   return PreferredSize(
  //     preferredSize: const Size.fromHeight(72),
  //     child: ClipRRect(
  //       borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
  //       child: BrandedAppBar(title: 'المخزون'),
  //     ),
  //   );
  // }

  // void _openEdit(BuildContext context, InventoryRow r) {
  //   showModalBottomSheet(
  //     context: context,
  //     useSafeArea: true,
  //     isScrollControlled: true,
  //     shape: const RoundedRectangleBorder(
  //       borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
  //     ),
  //     builder: (_) => EditInventorySheet(row: r),
  //   );
  // }

  // Future<void> _confirmDelete(BuildContext context, InventoryRow r) async {
  //   final ok = await showDialog<bool>(
  //     context: context,
  //     builder: (_) => AlertDialog(
  //       title: const Text('حذف العنصر'),
  //       content: Text(
  //         'هل تريد حذف "${r.name}${r.variant.isEmpty ? '' : ' — ${r.variant}'}"؟',
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context, false),
  //           child: const Text('إلغاء'),
  //         ),
  //         FilledButton(
  //           onPressed: () => Navigator.pop(context, true),
  //           child: const Text('حذف'),
  //         ),
  //       ],
  //     ),
  //   );
  //   if (ok == true) {
  //     await deleteInventoryRow(r);
  //     if (context.mounted) {
  //       ScaffoldMessenger.of(
  //         context,
  //       ).showSnackBar(const SnackBar(content: Text('تم الحذف')));
  //     }
  //   }
  // }
}
