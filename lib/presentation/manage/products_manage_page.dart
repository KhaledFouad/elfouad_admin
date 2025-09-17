import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/product.dart';
import 'providers.dart';
import 'product_edit_sheet.dart';
import '../../core/widgets/branded_appbar.dart';

class ProductsManagePage extends ConsumerStatefulWidget {
  const ProductsManagePage({super.key});
  @override
  ConsumerState<ProductsManagePage> createState() => _ProductsManagePageState();
}

class _ProductsManagePageState extends ConsumerState<ProductsManagePage> {
  String _filter = 'all';
  String _query = '';

  void _openAdd() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const ProductEditSheet(),
    );
  }

  void _openEdit(Product p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ProductEditSheet(initial: p),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(productsStreamProvider);
    final repo = ref.read(productsRepoProvider);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: const BrandedAppBar(title: 'المنتجات — تعديل/إضافة'),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openAdd,
          icon: const Icon(Icons.add),
          label: const Text('منتج جديد'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'بحث بالاسم',
                      ),
                      onChanged: (v) => setState(() => _query = v.trim()),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('الكل'),
                    selected: _filter == 'all',
                    onSelected: (_) => setState(() => _filter = 'all'),
                  ),
                  ChoiceChip(
                    label: const Text('منفرد'),
                    selected: _filter == 'single',
                    onSelected: (_) => setState(() => _filter = 'single'),
                  ),
                  ChoiceChip(
                    label: const Text('توليفة جاهزة'),
                    selected: _filter == 'ready_blend',
                    onSelected: (_) => setState(() => _filter = 'ready_blend'),
                  ),
                  ChoiceChip(
                    label: const Text('مشروب'),
                    selected: _filter == 'drink',
                    onSelected: (_) => setState(() => _filter = 'drink'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: s.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('خطأ تحميل المنتجات: $e')),
                data: (list) {
                  List<Product> v = list;
                  if (_filter != 'all') {
                    v = v.where((p) => p.type == _filter).toList();
                  }
                  if (_query.isNotEmpty) {
                    v = v.where((p) => p.name.contains(_query)).toList();
                  }
                  if (v.isEmpty) return const Center(child: Text('لا نتائج'));
                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemBuilder: (_, i) {
                      final p = v[i];
                      return Card(
                        child: ListTile(
                          title: Text(
                            (p.roast == null || p.roast!.isEmpty)
                                ? p.name
                                : '${p.name} — ${p.roast}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            p.type == 'drink'
                                ? 'مشروب'
                                : (p.type == 'single'
                                      ? 'صنف منفرد'
                                      : 'توليفة جاهزة'),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'تعديل',
                                onPressed: () => _openEdit(p),
                                icon: const Icon(Icons.edit),
                              ),
                              IconButton(
                                tooltip: 'حذف',
                                onPressed: () async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text('تأكيد الحذف'),
                                      content: Text('حذف ${p.name}?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('إلغاء'),
                                        ),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('حذف'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (ok == true) {
                                    await repo.delete(p.id, p.type);
                                  }
                                },
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemCount: v.length,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
