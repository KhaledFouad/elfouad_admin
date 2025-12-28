import 'package:awesome_drawer_bar/awesome_drawer_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore;
import 'package:elfouad_admin/core/app_strings.dart';
import 'package:elfouad_admin/presentation/inventory/bloc/inventory_cubit.dart';
import 'package:elfouad_admin/presentation/inventory/models/inventory_row.dart';
import 'package:elfouad_admin/presentation/inventory/utils/inventory_crud.dart';
import 'package:elfouad_admin/presentation/manage/widgets/product_edit_sheet.dart'
    show ProductEditSheet;
import 'package:elfouad_admin/presentation/manage/bloc/drinks_cubit.dart';
import 'package:elfouad_admin/presentation/manage/bloc/extras_cubit.dart';
import 'package:elfouad_admin/presentation/manage/bloc/manage_tab_cubit.dart';
import 'package:elfouad_admin/presentation/manage/models/extra_row.dart';
import 'package:elfouad_admin/presentation/manage/models/manage_tab.dart';
import 'package:elfouad_admin/presentation/manage/utils/drinks_crud.dart';
import 'package:elfouad_admin/presentation/manage/utils/extras_crud.dart';
import 'package:elfouad_admin/presentation/manage/widgets/extra_edit_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:responsive_framework/responsive_framework.dart';
import '../widgets/add_item_sheet.dart';

class ManagePage extends StatelessWidget {
  const ManagePage({super.key});
  static const route = '/manage';
  static const kDarkBrown = Color(0xFF543824);

  @override
  Widget build(BuildContext context) {
    final tab = context.watch<ManageTabCubit>().state.tab;
    final drinksState = context.watch<DrinksCubit>().state;
    final inventoryState = context.watch<InventoryCubit>().state;
    final extrasState = context.watch<ExtrasCubit>().state;
    final breakpoints = ResponsiveBreakpoints.of(context);
    final isPhone = breakpoints.smallerThan(TABLET);
    final isWide = breakpoints.largerThan(TABLET);
    final contentMaxWidth = isWide ? 1100.0 : double.infinity;
    final horizontalPadding = isPhone ? 10.0 : 16.0;

    Widget drinks0() {
      if (drinksState.loading) return _loading();
      if (drinksState.error != null) {
        return _err(AppStrings.drinksLabelDefinite)(
          drinksState.error!,
          StackTrace.empty,
        );
      }
      final rows = drinksState.items;
      return Column(
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
                        AppStrings.priceLabel,
                        d.sellPrice.toStringAsFixed(2),
                      ),
                      _pill(
                        Icons.handyman,
                        AppStrings.costLabel,
                        d.costPrice.toStringAsFixed(2),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        tooltip: AppStrings.actionEdit,
                        onPressed: () => _openProductEditor(
                          context,
                          collection: 'drinks',
                          id: d.id,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: AppStrings.actionDelete,
                        onPressed: () => _confirmDeleteDrink(context, d.id),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      );
    }

    // ???? ???? ??? collection ????? ???? ??? ProductEditSheet
    Widget invList(String collection, List<InventoryRow> rows) =>
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rows.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, index) {
            final r = rows[index];
            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                key: ValueKey('${collection}_${r.id}'),
                title: Text(
                  r.variant.isEmpty ? r.name : '${r.name} - ${r.variant}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Wrap(
                  spacing: 10,
                  children: [
                    _pill(
                      Icons.scale,
                      AppStrings.stockLabel,
                      AppStrings.gramsAmount(r.stockG),
                    ),
                    _pill(
                      Icons.sell,
                      AppStrings.pricePerKgLabel,
                      r.sellPerKg.toStringAsFixed(2),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: AppStrings.actionEdit,
                      onPressed: () => _openProductEditor(
                        context,
                        collection: collection,
                        id: r.id,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: AppStrings.actionDelete,
                      onPressed: () => _confirmDeleteInventory(context, r),
                    ),
                  ],
                ),
              ),
            );
          },
        );

    Widget singles0() {
      if (inventoryState.loadingSingles) return _loading();
      if (inventoryState.error != null) {
        return _err(AppStrings.inventorySingles)(
          inventoryState.error!,
          StackTrace.empty,
        );
      }
      return invList('singles', inventoryState.singles);
    }

    Widget blends0() {
      if (inventoryState.loadingBlends) return _loading();
      if (inventoryState.error != null) {
        return _err(AppStrings.inventoryBlends)(
          inventoryState.error!,
          StackTrace.empty,
        );
      }
      return invList('blends', inventoryState.blends);
    }

    Widget extras0() {
      if (extrasState.loading) return _loading();
      if (extrasState.error != null) {
        return _err(AppStrings.extrasLabel)(
          extrasState.error!,
          StackTrace.empty,
        );
      }
      final rows = extrasState.items;
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: rows.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, index) {
          final e = rows[index];
          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: ListTile(
              key: ValueKey('extra_${e.id}'),
              title: Text(
                e.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Wrap(
                spacing: 10,
                runSpacing: 6,
                children: [
                  if (e.category.isNotEmpty)
                    _pill(Icons.category, AppStrings.categoryLabel, e.category),
                  _pill(
                    Icons.inventory_2,
                    AppStrings.stockLabel,
                    '${_fmtNum(e.stockUnits)}${e.unit.isEmpty ? '' : ' ${e.unit}'}',
                  ),
                  _pill(
                    Icons.attach_money,
                    AppStrings.sellPriceLabel,
                    _fmtNum(e.priceSell),
                  ),
                  _pill(
                    Icons.money_off,
                    AppStrings.costLabelDefinite,
                    _fmtNum(e.costUnit),
                  ),
                  if (!e.active)
                    _pill(
                      Icons.pause_circle_filled,
                      AppStrings.statusLabel,
                      AppStrings.inactiveLabel,
                    ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: AppStrings.actionEdit,
                    onPressed: () => _openExtraEditor(context, e.id),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: AppStrings.actionDelete,
                    onPressed: () => _confirmDeleteExtra(context, e),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

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
              _Section(AppStrings.snacksLabel),
              extras0(),
              const SizedBox(height: 8),
              _Section(AppStrings.inventoryBlends),
              blends0(),
              const SizedBox(height: 8),
              _Section(AppStrings.inventorySingles),
              singles0(),
              const SizedBox(height: 8),
              _Section(AppStrings.drinksLabelDefinite),
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
                AppStrings.tabEdits,
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
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxWidth),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                8,
                horizontalPadding,
                96,
              ),
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    _mChip(
                      context,
                      AppStrings.inventoryAll,
                      ManageTab.all,
                      tab,
                    ),
                    _mChip(
                      context,
                      AppStrings.drinksLabelDefinite,
                      ManageTab.drinks,
                      tab,
                    ),
                    _mChip(
                      context,
                      AppStrings.inventorySingles,
                      ManageTab.singles,
                      tab,
                    ),
                    _mChip(
                      context,
                      AppStrings.inventoryBlends,
                      ManageTab.blends,
                      tab,
                    ),
                    _mChip(
                      context,
                      AppStrings.snacksLabel,
                      ManageTab.extras,
                      tab,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                content(),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'manage_fab',
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
          label: const Text(AppStrings.actionAdd),
          tooltip: AppStrings.addNewItemTooltip,
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
        child: Text(AppStrings.loadFailed(where, e)),
      );

  Widget _mChip(
    BuildContext context,
    String label,
    ManageTab me,
    ManageTab cur,
  ) {
    final selected = me == cur;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => context.read<ManageTabCubit>().setTab(me),
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
        title: const Text(AppStrings.deleteDrinkTitle),
        content: const Text(AppStrings.deleteDrinkConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppStrings.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(AppStrings.actionDelete),
          ),
        ],
      ),
    );
    if (ok == true) {
      await deleteDrink(id);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(AppStrings.deleteSuccess)));
      }
    }
  }

  Future<void> _confirmDeleteExtra(BuildContext context, ExtraRow e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(AppStrings.deleteExtraTitle),
        content: Text(AppStrings.deleteExtraConfirm(e.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppStrings.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(AppStrings.actionDelete),
          ),
        ],
      ),
    );
    if (ok == true) {
      await deleteExtra(e.id);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(AppStrings.deleteSuccess)));
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
      title: const Text(AppStrings.deleteItemTitle),
      content: Text(
        AppStrings.deleteItemConfirm(
          '${r.name}${r.variant.isEmpty ? '' : ' - ${r.variant}'}',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text(AppStrings.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text(AppStrings.actionDelete),
        ),
      ],
    ),
  );
  if (ok == true) {
    await deleteInventoryRow(r);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppStrings.deleteSuccess)));
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

// ???? ??????? ????? ??? ?? ???? ??? Doc
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
