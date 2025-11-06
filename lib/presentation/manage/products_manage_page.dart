import 'package:awesome_drawer_bar/awesome_drawer_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore;
import 'package:elfouad_admin/presentation/inventory/providers.dart';
import 'package:elfouad_admin/presentation/manage/product_edit_sheet.dart'
    show ProductEditSheet;
import 'package:elfouad_admin/presentation/manage/widgets/extra_edit_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'state/drinks_provider.dart';
// NOTE: لم نعد نستخدم الشيتات القديمة هنا
// import 'widgets/drink_edit_sheet.dart';
// import '../inventory/widgets/edit_inventory_sheet.dart';
import 'widgets/add_item_sheet.dart';
import 'state/extras_provider.dart';

enum ManageTab { all, drinks, singles, blends, extras }

final manageTabProvider = StateProvider<ManageTab>((_) => ManageTab.all);

class ManagePage extends ConsumerWidget {
  const ManagePage({super.key});
  static const route = '/manage';
  static const kDarkBrown = Color(0xFF543824);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(manageTabProvider);
    final drinks = ref.watch(drinksStreamProvider);
    final singles = ref.watch(singlesStreamProvider);
    final blends = ref.watch(blendsStreamProvider);
    final extras = ref.watch(extrasStreamProvider);

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
                        onPressed: () => _openProductEditor(
                          context,
                          collection: 'drinks',
                          id: d.id, // عندك d.id مستخدم أصلًا في الحذف
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

    // خليه يعرف الـ collection علشان يفتح الـ ProductEditSheet
    Widget invList(String collection, List<InventoryRow> rows) => Column(
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
                      onPressed: () => _openProductEditor(
                        context,
                        collection: collection,
                        // InventoryRow عندك غالبًا فيه ref/id.
                        // استخدم اللي موجود:
                        id: r.id,
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
      data: (rows) => invList('singles', rows),
    );

    Widget blends0() => blends.when(
      loading: _loading,
      error: _err('التوليفات'),
      data: (rows) => invList('blends', rows),
    );
    Widget extras0() => extras.when(
      loading: _loading,
      error: _err('الإضافات'),
      data: (rows) => Column(
        children: rows
            .map(
              (e) => Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  title: Text(
                    e.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      if (e.category.isNotEmpty)
                        _pill(Icons.category, 'التصنيف', e.category),
                      _pill(
                        Icons.inventory_2,
                        'المخزون',
                        '${_fmtNum(e.stockUnits)}${e.unit.isEmpty ? '' : ' ${e.unit}'}',
                      ),
                      _pill(
                        Icons.attach_money,
                        'سعر البيع',
                        _fmtNum(e.priceSell),
                      ),
                      _pill(Icons.money_off, 'التكلفة', _fmtNum(e.costUnit)),
                      if (!e.active)
                        _pill(Icons.pause_circle_filled, 'الحالة', 'غير مفعّل'),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        tooltip: 'تعديل',
                        onPressed: () => _openExtraEditor(context, e.id),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'حذف',
                        onPressed: () => _confirmDeleteExtra(context, e),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );

    Widget content() {
      switch (tab) {
        case ManageTab.drinks:
          return drinks0();
        case ManageTab.singles:
          return singles0();
        case ManageTab.blends:
          return blends0();
        case ManageTab.extras:
          return extras0();
        case ManageTab.all:
          return Column(
            children: [
              _Section('سناكس'),
              extras0(),
              const SizedBox(height: 8),
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
                _mChip(ref, 'سناكس', ManageTab.extras, tab),
              ],
            ),
            const SizedBox(height: 8),
            content(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: tab == ManageTab.extras
              ? null
              : () => showModalBottomSheet(
                  context: context,
                  useSafeArea: true,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                  ),
                  builder: (_) =>
                      AddItemSheet(initialType: _newTypeForTab(tab)),
                ),
          icon: const Icon(Icons.add),
          label: const Text('إضافة'),
          tooltip: 'إضافة عنصر جديد',

          backgroundColor: kDarkBrown,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

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

  static String _fmtNum(double value) {
    if (value.isNaN || value.isInfinite) return '0';
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
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

  Future<void> _confirmDeleteExtra(BuildContext context, ExtraRow e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف الإضافة'),
        content: Text('هل تريد حذف "${e.name}"؟'),
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
      await deleteExtra(e.id);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم الحذف')));
      }
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

// يفتح المحرّر العام بعد ما يجيب الـ Doc
Future<void> _openProductEditor(
  BuildContext context, {
  required String collection, // 'drinks' | 'singles' | 'blends'
  required String id,
}) async {
  final snap = await FirebaseFirestore.instance
      .collection(collection)
      .doc(id)
      .get();

  if (!context.mounted) return;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => ProductEditSheet(collection: collection, snap: snap),
  );
}

Future<void> _openExtraEditor(BuildContext context, String id) async {
  final snap = await FirebaseFirestore.instance
      .collection('extras')
      .doc(id)
      .get();

  if (!context.mounted) return;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => ExtraEditSheet(snap: snap),
  );
}

NewItemType _newTypeForTab(ManageTab tab) {
  switch (tab) {
    case ManageTab.drinks:
      return NewItemType.drink;
    case ManageTab.singles:
      return NewItemType.single;
    case ManageTab.blends:
      return NewItemType.blend;
    case ManageTab.extras:
      return NewItemType.extra;
    case ManageTab.all:
      return NewItemType.blend;
  }
}
