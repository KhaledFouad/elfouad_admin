import 'package:awesome_drawer_bar/awesome_drawer_bar.dart';
import 'package:elfouad_admin/presentation/inventory/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'state/drinks_provider.dart';
import 'widgets/drink_edit_sheet.dart';
import '../inventory/widgets/edit_inventory_sheet.dart';
import 'widgets/add_item_sheet.dart';

enum ManageTab { all, drinks, singles, blends }

final manageTabProvider = StateProvider<ManageTab>((_) => ManageTab.all);

class ManagePage extends ConsumerWidget {
  const ManagePage({super.key});
  static const route = '/manage';
  static const kDarkBrown = Color(0xFF543824);
  static const kBeige = Color(0xFFC49A6C);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(manageTabProvider);
    final drinks = ref.watch(drinksStreamProvider);
    final singles = ref.watch(singlesStreamProvider);
    final blends = ref.watch(blendsStreamProvider);

    Widget drinks0() => drinks.when(
      loading: _loading,
      error: _err('المشروبات'),
      data: (rows) => Column(
        children: rows
            .map(
              (d) => Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  title: Text(
                    d.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Wrap(
                    spacing: 10,
                    children: [
                      _pill(
                        Icons.attach_money,
                        'سعر',
                        d.sellPrice.toStringAsFixed(2),
                      ),
                      _pill(
                        Icons.handyman,
                        'تكلفة',
                        d.costPrice.toStringAsFixed(2),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        tooltip: 'تعديل',
                        onPressed: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(18),
                            ),
                          ),
                          builder: (_) => DrinkEditSheet(drink: d),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'حذف',
                        onPressed: () => _confirmDeleteDrink(context, d.id),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );

    Widget invList(List<InventoryRow> rows) => Column(
      children: rows
          .map(
            (r) => Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                title: Text(
                  r.variant.isEmpty ? r.name : '${r.name} — ${r.variant}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Wrap(
                  spacing: 10,
                  children: [
                    _pill(
                      Icons.scale,
                      'مخزون',
                      '${r.stockG.toStringAsFixed(0)} جم',
                    ),
                    _pill(
                      Icons.sell,
                      'سعر/كجم',
                      r.sellPerKg.toStringAsFixed(2),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: 'تعديل',
                      onPressed: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(18),
                          ),
                        ),
                        builder: (_) => EditInventorySheet(row: r),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'حذف',
                      onPressed: () => _confirmDeleteInventory(context, r),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );

    Widget singles0() => singles.when(
      loading: _loading,
      error: _err('الأصناف المنفردة'),
      data: invList,
    );

    Widget blends0() =>
        blends.when(loading: _loading, error: _err('التوليفات'), data: invList);

    Widget content() {
      switch (tab) {
        case ManageTab.drinks:
          return drinks0();
        case ManageTab.singles:
          return singles0();
        case ManageTab.blends:
          return blends0();
        case ManageTab.all:
          return Column(
            children: [
              _Section('التوليفات'),
              blends0(),
              const SizedBox(height: 8),
              _Section('الأصناف المنفردة'),
              singles0(),
              const SizedBox(height: 8),
              _Section('المشروبات'),
              drinks0(),
            ],
          );
      }
    }

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
                "التعديلات",
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
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
          children: [
            Wrap(
              spacing: 8,
              children: [
                _mChip(ref, 'الكل', ManageTab.all, tab),
                _mChip(ref, 'المشروبات', ManageTab.drinks, tab),
                _mChip(ref, 'الأصناف المنفردة', ManageTab.singles, tab),
                _mChip(ref, 'التوليفات', ManageTab.blends, tab),
              ],
            ),
            const SizedBox(height: 8),
            content(),
          ],
        ),
        // floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => showModalBottomSheet(
            context: context,
            useSafeArea: true,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            builder: (_) => const AddItemSheet(),
          ),
          icon: const Icon(Icons.add),
          label: const Text('إضافة'),
          backgroundColor: kDarkBrown,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  // PreferredSizeWidget _bar(BuildContext context) {
  //   return PreferredSize(
  //     preferredSize: const Size.fromHeight(72),
  //     child: ClipRRect(
  //       borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
  //       child: AppBar(
  //         leading: Builder(
  //           builder: (ctx) => IconButton(
  //             icon: const Icon(Icons.menu, color: Colors.white),
  //             onPressed: () => Scaffold.of(ctx).openDrawer(),
  //             tooltip: 'القائمة',
  //           ),
  //         ),
  //         title: const Text(
  //           'التعديلات',
  //           style: TextStyle(
  //             fontWeight: FontWeight.w800,
  //             fontSize: 22,
  //             color: Colors.white,
  //           ),
  //         ),
  //         centerTitle: true,
  //         backgroundColor: Colors.transparent,
  //         elevation: 4,
  //         iconTheme: const IconThemeData(color: Colors.white),
  //         flexibleSpace: const DecoratedBox(
  //           decoration: BoxDecoration(
  //             gradient: LinearGradient(
  //               begin: Alignment.topLeft,
  //               end: Alignment.bottomRight,
  //               colors: [Color(0xFF543824), Color(0xFFC49A6C)],
  //             ),
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }

  Widget _loading() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 16),
    child: Center(child: CircularProgressIndicator()),
  );

  Widget Function(Object, StackTrace) _err(String where) =>
      (e, _) => Padding(
        padding: const EdgeInsets.all(12),
        child: Text('تعذر تحميل $where: $e'),
      );

  Widget _mChip(WidgetRef ref, String label, ManageTab me, ManageTab cur) {
    final selected = me == cur;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => ref.read(manageTabProvider.notifier).state = me,
      labelStyle: TextStyle(
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
      ),
    );
  }

  static Widget _pill(IconData i, String k, String v) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.brown.shade50,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.brown.shade100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(i, size: 16),
          const SizedBox(width: 6),
          Text(
            '$k: ',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteDrink(BuildContext context, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف المشروب'),
        content: const Text('هل تريد حذف هذا المشروب؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await deleteDrink(id);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم الحذف')));
      }
    }
  }

  Future<void> _confirmDeleteInventory(
    BuildContext context,
    InventoryRow r,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف العنصر'),
        content: Text(
          'هل تريد حذف "${r.name}${r.variant.isEmpty ? '' : ' — ${r.variant}'}"؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await deleteInventoryRow(r);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم الحذف')));
      }
    }
  }
}

class _Section extends StatelessWidget {
  final String t;
  const _Section(this.t);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(6, 6, 6, 2),
      child: Text(
        t,
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
      ),
    );
  }
}
