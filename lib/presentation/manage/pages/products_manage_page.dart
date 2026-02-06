import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_admin/core/utils/app_strings.dart';
import 'package:elfouad_admin/presentation/home/nav_state.dart';
import 'package:elfouad_admin/presentation/inventory/bloc/inventory_cubit.dart';
import 'package:elfouad_admin/presentation/inventory/models/inventory_row.dart';
import 'package:elfouad_admin/presentation/inventory/utils/inventory_crud.dart';
import 'package:elfouad_admin/presentation/inventory/utils/inventory_helpers.dart';
import 'package:elfouad_admin/presentation/inventory/pages/inventory_log_page.dart';
import 'package:elfouad_admin/presentation/manage/widgets/product_edit_sheet.dart'
    show ProductEditSheet;
import 'package:elfouad_admin/presentation/manage/bloc/extras_cubit.dart';
import 'package:elfouad_admin/presentation/manage/bloc/manage_tab_cubit.dart';
import 'package:elfouad_admin/presentation/manage/bloc/manage_tab_state.dart';
import 'package:elfouad_admin/presentation/manage/models/drink_row.dart';
import 'package:elfouad_admin/presentation/manage/models/extra_row.dart';
import 'package:elfouad_admin/presentation/manage/models/manage_tab.dart';
import 'package:elfouad_admin/presentation/manage/utils/drinks_crud.dart';
import 'package:elfouad_admin/presentation/manage/utils/drinks_helpers.dart';
import 'package:elfouad_admin/presentation/manage/utils/extras_crud.dart';
import 'package:elfouad_admin/presentation/manage/utils/extras_helpers.dart';
import 'package:elfouad_admin/presentation/manage/widgets/extra_edit_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:responsive_framework/responsive_framework.dart';
import '../widgets/add_item_sheet.dart';

class ManagePage extends StatefulWidget {
  const ManagePage({super.key});
  static const route = '/manage';
  static const kDarkBrown = Color(0xFF543824);

  @override
  State<ManagePage> createState() => _ManagePageState();
}

class _ManagePageState extends State<ManagePage> {
  static const _pageSize = 40;
  late final _PagedQuery<DrinkRow> _drinks;
  late final _PagedQuery<ExtraRow> _extras;
  late final _PagedQuery<InventoryRow> _singles;
  late final _PagedQuery<InventoryRow> _blends;
  final Set<ManageTab> _pendingRealtimeRefresh = <ManageTab>{};
  Timer? _realtimeDebounce;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _drinksSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _extrasSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _singlesSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _blendsSub;

  @override
  void initState() {
    super.initState();
    _drinks = _PagedQuery<DrinkRow>(
      query: FirebaseFirestore.instance.collection('drinks').orderBy('name'),
      mapDoc: drinkRowFromDoc,
      pageSize: _pageSize,
      onUpdate: _safeSetState,
    );
    _extras = _PagedQuery<ExtraRow>(
      query: FirebaseFirestore.instance.collection('extras').orderBy('name'),
      mapDoc: extraRowFromDoc,
      pageSize: _pageSize,
      onUpdate: _safeSetState,
    );
    _singles = _PagedQuery<InventoryRow>(
      query: FirebaseFirestore.instance.collection('singles').orderBy('name'),
      mapDoc: inventoryRowFromDoc,
      pageSize: _pageSize,
      sort: sortByNameVariant,
      onUpdate: _safeSetState,
    );
    _blends = _PagedQuery<InventoryRow>(
      query: FirebaseFirestore.instance.collection('blends').orderBy('name'),
      mapDoc: inventoryRowFromDoc,
      pageSize: _pageSize,
      sort: sortByNameVariant,
      onUpdate: _safeSetState,
    );
    _startRealtime();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureTabLoaded(context.read<ManageTabCubit>().state.tab);
    });
  }

  @override
  void dispose() {
    _realtimeDebounce?.cancel();
    _drinksSub?.cancel();
    _extrasSub?.cancel();
    _singlesSub?.cancel();
    _blendsSub?.cancel();
    super.dispose();
  }

  void _safeSetState() {
    if (mounted) setState(() {});
  }

  void _startRealtime() {
    final db = FirebaseFirestore.instance;
    _drinksSub = db
        .collection('drinks')
        .orderBy('name')
        .snapshots()
        .skip(1)
        .listen((_) => _scheduleRealtimeRefresh(ManageTab.drinks));
    _extrasSub = db
        .collection('extras')
        .orderBy('name')
        .snapshots()
        .skip(1)
        .listen((_) => _scheduleRealtimeRefresh(ManageTab.extras));
    _singlesSub = db
        .collection('singles')
        .orderBy('name')
        .snapshots()
        .skip(1)
        .listen((_) => _scheduleRealtimeRefresh(ManageTab.singles));
    _blendsSub = db
        .collection('blends')
        .orderBy('name')
        .snapshots()
        .skip(1)
        .listen((_) => _scheduleRealtimeRefresh(ManageTab.blends));
  }

  void _scheduleRealtimeRefresh(ManageTab tab) {
    _pendingRealtimeRefresh.add(tab);
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      final tabs = List<ManageTab>.from(_pendingRealtimeRefresh);
      _pendingRealtimeRefresh.clear();
      for (final pending in tabs) {
        await _refreshForTab(pending);
      }
    });
  }

  void _ensureTabLoaded(ManageTab tab) {
    switch (tab) {
      case ManageTab.drinks:
        _drinks.loadInitial();
        break;
      case ManageTab.singles:
        _singles.loadInitial();
        break;
      case ManageTab.blends:
        _blends.loadInitial();
        break;
      case ManageTab.extras:
        _extras.loadInitial();
        break;
      case ManageTab.all:
        _extras.loadInitial();
        _blends.loadInitial();
        _singles.loadInitial();
        _drinks.loadInitial();
        break;
    }
  }

  Future<void> _refreshForTab(ManageTab tab) async {
    switch (tab) {
      case ManageTab.drinks:
        await _drinks.refresh();
        break;
      case ManageTab.singles:
        await _singles.refresh();
        break;
      case ManageTab.blends:
        await _blends.refresh();
        break;
      case ManageTab.extras:
        await _extras.refresh();
        break;
      case ManageTab.all:
        await Future.wait([
          _extras.refresh(),
          _blends.refresh(),
          _singles.refresh(),
          _drinks.refresh(),
        ]);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tab = context.watch<ManageTabCubit>().state.tab;
    final breakpoints = ResponsiveBreakpoints.of(context);
    final isPhone = breakpoints.smallerThan(TABLET);
    final isWide = breakpoints.largerThan(TABLET);
    final contentMaxWidth = isWide ? 1100.0 : double.infinity;
    final horizontalPadding = isPhone ? 10.0 : 16.0;
    final maxStockForBar = context.watch<InventoryCubit>().state.maxStock;
    final maxExtraUnits = _maxExtraUnits(_extras.items);
    const pageTitle = AppStrings.tabInventory;

    Widget emptyState() => const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(child: Text(AppStrings.noItems)),
    );

    Widget loadMore<T>(_PagedQuery<T> page) {
      if (page.loadingMore) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (!page.hasMore) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: OutlinedButton.icon(
          onPressed: () => page.loadMore(),
          icon: const Icon(Icons.expand_more),
          label: const Text(AppStrings.actionLoadMore),
        ),
      );
    }

    Widget drinks0() {
      if (_drinks.loading && _drinks.items.isEmpty) return _loading();
      if (_drinks.error != null) {
        return _err(AppStrings.drinksLabelDefinite)(
          _drinks.error!,
          StackTrace.empty,
        );
      }
      final rows = _drinks.items;
      if (rows.isEmpty) return emptyState();
      return Column(
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, index) {
              final d = rows[index];
              return Card(
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
              );
            },
          ),
          loadMore(_drinks),
        ],
      );
    }

    // ???? ???? ??? collection ????? ???? ??? ProductEditSheet
    Widget invList(
      String collection,
      String label,
      _PagedQuery<InventoryRow> page,
    ) {
      if (page.loading && page.items.isEmpty) return _loading();
      if (page.error != null) {
        return _err(label)(page.error!, StackTrace.empty);
      }
      final rows = page.items;
      if (rows.isEmpty) return emptyState();
      return Column(
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, index) {
              final r = rows[index];
              final showBar = r.stockG > 0;
              final percent = _barPercent(r.stockG, maxStockForBar);
              final barColor = _stockBarColorForGrams(r);
              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    ListTile(
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
                    if (showBar)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: percent,
                            minHeight: 8,
                            backgroundColor: Colors.brown.shade50,
                            valueColor: AlwaysStoppedAnimation(barColor),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          loadMore(page),
        ],
      );
    }

    Widget singles0() =>
        invList('singles', AppStrings.inventorySingles, _singles);

    Widget blends0() => invList('blends', AppStrings.inventoryBlends, _blends);

    Widget extras0() {
      if (_extras.loading && _extras.items.isEmpty) return _loading();
      if (_extras.error != null) {
        return _err(AppStrings.extrasLabel)(_extras.error!, StackTrace.empty);
      }
      final rows = _extras.items;
      if (rows.isEmpty) return emptyState();
      return Column(
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, index) {
              final e = rows[index];
              final showBar = e.stockUnits > 0;
              final percent = _barPercent(e.stockUnits, maxExtraUnits);
              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    ListTile(
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
                            _pill(
                              Icons.category,
                              AppStrings.categoryLabel,
                              e.category,
                            ),
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
                    if (showBar)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: percent,
                            minHeight: 8,
                            backgroundColor: Colors.brown.shade50,
                            valueColor: const AlwaysStoppedAnimation(
                              Color(0xFF6F4E37),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          loadMore(_extras),
        ],
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

    return BlocListener<ManageTabCubit, ManageTabState>(
      listener: (context, state) => _ensureTabLoaded(state.tab),
      child: Directionality(
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
                  icon: const Icon(Icons.home_rounded, color: Colors.white),
                  onPressed: () => context.read<NavCubit>().setTab(AppTab.home),
                  tooltip: AppStrings.tabHome,
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.history),
                    tooltip: AppStrings.inventoryLogTitle,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const InventoryLogPage(),
                        ),
                      );
                    },
                  ),
                ],
                title: Text(
                  pageTitle,
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
              child: RefreshIndicator(
                onRefresh: () => _refreshForTab(tab),
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
          ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'manage_fab',
            onPressed: () => showModalBottomSheet(
              context: context,
              useSafeArea: true,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
              ),
              builder: (_) => MultiBlocProvider(
                providers: [
                  BlocProvider.value(
                    value: context.read<InventoryCubit>(),
                  ),
                  BlocProvider.value(value: context.read<ExtrasCubit>()),
                ],
                child: AddItemSheet(initialType: _newTypeForTab(tab)),
              ),
            ),
            icon: const Icon(Icons.add),
            label: const Text(AppStrings.actionAdd),
            tooltip: AppStrings.addNewItemTooltip,
            backgroundColor: ManagePage.kDarkBrown,
            foregroundColor: Colors.white,
          ),
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

  static double _barPercent(double value, double max) {
    if (value <= 0 || max <= 0) return 0;
    final ratio = value / max;
    return ratio.clamp(0.0, 1.0);
  }

  static double _maxExtraUnits(List<ExtraRow> items) {
    double max = 0;
    for (final e in items) {
      if (e.stockUnits > max) max = e.stockUnits;
    }
    return max <= 0 ? 1 : max;
  }

  static Color _stockBarColorForGrams(InventoryRow row) {
    if (row.stockG <= row.minLevelG && row.minLevelG > 0) {
      return Colors.red.shade400;
    }
    if (row.stockG <= 2500) {
      return Colors.orange.shade500;
    }
    return const Color(0xFF6F4E37);
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
    builder: (_) => BlocProvider.value(
      value: context.read<InventoryCubit>(),
      child: ProductEditSheet(collection: collection, snap: snap),
    ),
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

class _PagedQuery<T> {
  _PagedQuery({
    required this.query,
    required this.mapDoc,
    required this.onUpdate,
    this.sort,
    this.pageSize = 40,
  });

  final Query<Map<String, dynamic>> query;
  final T Function(QueryDocumentSnapshot<Map<String, dynamic>> doc) mapDoc;
  final List<T> Function(List<T> items)? sort;
  final VoidCallback onUpdate;
  final int pageSize;

  final List<T> items = [];
  Object? error;
  bool loading = false;
  bool loadingMore = false;
  bool hasMore = true;
  QueryDocumentSnapshot<Map<String, dynamic>>? _lastDoc;

  Future<void> loadInitial() async {
    if (loading || items.isNotEmpty) return;
    loading = true;
    error = null;
    onUpdate();
    try {
      final snap = await query.limit(pageSize).get();
      _lastDoc = snap.docs.isEmpty ? null : snap.docs.last;
      hasMore = snap.docs.length == pageSize;
      _appendDocs(snap.docs);
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      onUpdate();
    }
  }

  Future<void> loadMore() async {
    if (loading || loadingMore || !hasMore) return;
    loadingMore = true;
    error = null;
    onUpdate();
    try {
      var q = query.limit(pageSize);
      if (_lastDoc != null) {
        q = q.startAfterDocument(_lastDoc!);
      }
      final snap = await q.get();
      if (snap.docs.isNotEmpty) {
        _lastDoc = snap.docs.last;
      }
      hasMore = snap.docs.length == pageSize;
      _appendDocs(snap.docs);
    } catch (e) {
      error = e;
    } finally {
      loadingMore = false;
      onUpdate();
    }
  }

  void reset() {
    items.clear();
    error = null;
    loading = false;
    loadingMore = false;
    hasMore = true;
    _lastDoc = null;
    onUpdate();
  }

  Future<void> refresh() async {
    if (loading) return;
    loading = true;
    error = null;
    onUpdate();
    try {
      final snap = await query.limit(pageSize).get();
      _lastDoc = snap.docs.isEmpty ? null : snap.docs.last;
      hasMore = snap.docs.length == pageSize;
      final nextItems = snap.docs.map(mapDoc).toList();
      items
        ..clear()
        ..addAll(sort == null ? nextItems : sort!(nextItems));
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      onUpdate();
    }
  }

  void _appendDocs(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (docs.isEmpty) return;
    items.addAll(docs.map(mapDoc));
    if (sort != null) {
      final sorted = sort!(items);
      items
        ..clear()
        ..addAll(sorted);
    }
  }
}
