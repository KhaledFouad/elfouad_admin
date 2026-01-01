import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elfouad_admin/core/utils/app_strings.dart';
import 'package:elfouad_admin/presentation/home/nav_state.dart';
import 'package:elfouad_admin/presentation/inventory/bloc/inventory_cubit.dart';
import 'package:elfouad_admin/presentation/inventory/bloc/inventory_state.dart';
import 'package:elfouad_admin/presentation/stocktake/bloc/stocktake_cubit.dart';
import 'package:elfouad_admin/presentation/stocktake/models/stocktake_models.dart';
import 'package:elfouad_admin/presentation/stocktake/utils/stocktake_utils.dart';
import 'package:elfouad_admin/presentation/stocktake/widgets/stocktake_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' as intl;
import 'package:responsive_framework/responsive_framework.dart';

class StocktakePage extends StatelessWidget {
  const StocktakePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => StocktakeCubit(),
      child: const _StocktakeView(),
    );
  }
}

class _StocktakeView extends StatefulWidget {
  const _StocktakeView();

  @override
  State<_StocktakeView> createState() => _StocktakeViewState();
}

class _StocktakeViewState extends State<_StocktakeView> {
  static const _kgUnit = 'كجم';
  static const _gUnit = 'جم';
  static const _fallbackUnit = 'وحدة';
  static const _batchLimit = 450;

  final TextEditingController _searchCtrl = TextEditingController();
  final Map<String, TextEditingController> _countedCtrls = {};

  @override
  void initState() {
    super.initState();
    _searchCtrl.text = context.read<StocktakeCubit>().state.searchQuery;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    for (final ctrl in _countedCtrls.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inventoryState = context.watch<InventoryCubit>().state;
    final stocktakeState = context.watch<StocktakeCubit>().state;
    final breakpoints = ResponsiveBreakpoints.of(context);
    final isPhone = breakpoints.smallerThan(TABLET);
    final contentMaxWidth = breakpoints.largerThan(TABLET)
        ? 1100.0
        : double.infinity;
    final horizontalPadding = isPhone ? 12.0 : 16.0;

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
              centerTitle: true,
              actions: [
                IconButton(
                  icon: Icon(
                    stocktakeState.mode == StocktakeMode.log
                        ? Icons.fact_check_outlined
                        : Icons.history,
                  ),
                  tooltip: stocktakeState.mode == StocktakeMode.log
                      ? AppStrings.stocktakeTitle
                      : AppStrings.stocktakeLog,
                  onPressed: () => context.read<StocktakeCubit>().toggleMode(),
                ),
              ],
              automaticallyImplyLeading: false,
              leading: IconButton(
                icon: const Icon(Icons.home_rounded, color: Colors.white),
                onPressed: () => context.read<NavCubit>().setTab(AppTab.home),
                tooltip: AppStrings.tabHome,
              ),
              title: const Text(
                AppStrings.stocktakeTitle,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 35,
                  color: Colors.white,
                ),
              ),
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
        bottomNavigationBar: stocktakeState.mode == StocktakeMode.record
            ? SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    8,
                    horizontalPadding,
                    12,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: stocktakeState.saving
                          ? null
                          : () => _submitStocktake(inventoryState),
                      icon: stocktakeState.saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: const Text(AppStrings.stocktakeRecord),
                    ),
                  ),
                ),
              )
            : null,
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxWidth),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    12,
                    horizontalPadding,
                    8,
                  ),
                  child: _buildModeToggle(stocktakeState.mode),
                ),
                Expanded(
                  child: stocktakeState.mode == StocktakeMode.record
                      ? _buildRecordContent(
                          inventoryState,
                          horizontalPadding,
                          filter: stocktakeState.filter,
                          overwrite: stocktakeState.overwrite,
                          query: stocktakeState.searchQuery,
                        )
                      : _buildLogContent(horizontalPadding),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeToggle(StocktakeMode mode) {
    return SegmentedButton<StocktakeMode>(
      segments: const [
        ButtonSegment(
          value: StocktakeMode.record,
          label: Text(AppStrings.stocktakeTitle),
        ),
        ButtonSegment(
          value: StocktakeMode.log,
          label: Text(AppStrings.stocktakeLog),
        ),
      ],
      selected: {mode},
      onSelectionChanged: (selection) =>
          context.read<StocktakeCubit>().setMode(selection.first),
    );
  }

  Widget _buildRecordContent(
    InventoryState state,
    double horizontalPadding, {
    required StocktakeFilter filter,
    required bool overwrite,
    required String query,
  }) {
    final items = _filteredItems(state, filter, query);
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            0,
            horizontalPadding,
            6,
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _filterChip(
                AppStrings.inventoryAll,
                StocktakeFilter.all,
                filter,
              ),
              _filterChip(
                AppStrings.inventorySingles,
                StocktakeFilter.singles,
                filter,
              ),
              _filterChip(
                AppStrings.inventoryBlends,
                StocktakeFilter.blends,
                filter,
              ),
              _filterChip(
                AppStrings.extrasLabel,
                StocktakeFilter.extras,
                filter,
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            0,
            horizontalPadding,
            8,
          ),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (value) =>
                context.read<StocktakeCubit>().setSearchQuery(value),
            decoration: InputDecoration(
              hintText: AppStrings.stocktakeSearchHint,
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              isDense: true,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            0,
            horizontalPadding,
            6,
          ),
          child: SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: overwrite,
            onChanged: (v) => context.read<StocktakeCubit>().setOverwrite(v),
            title: const Text(AppStrings.stocktakeOverwrite),
          ),
        ),
        Expanded(child: _buildRecordList(state, items, horizontalPadding)),
      ],
    );
  }

  Widget _buildRecordList(
    InventoryState state,
    List<StocktakeItem> items,
    double horizontalPadding,
  ) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return Center(
        child: Text(AppStrings.loadFailedSimple(state.error ?? 'unknown')),
      );
    }
    if (items.isEmpty) {
      return const Center(child: Text(AppStrings.noItems));
    }
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 4, horizontalPadding, 96),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildItemCard(items[index]),
    );
  }

  Widget _buildItemCard(StocktakeItem item) {
    final ctrl = _controllerFor(item.key);
    final counted = parseStocktakeDecimal(ctrl.text);
    final diff = stocktakeDiffFor(
      isExtra: item.isExtra,
      current: item.current,
      countedInput: counted,
    );
    final resolvedUnit = stocktakeUnitFor(item.unit, _fallbackUnit);
    final diffText = diff == null
        ? '--'
        : stocktakeFormatDiff(
            isExtra: item.isExtra,
            diff: diff,
            unit: resolvedUnit,
            kgUnit: _kgUnit,
          );
    final diffColor = diff == null
        ? Colors.black54
        : diff > 0
        ? Colors.green.shade700
        : diff < 0
        ? Colors.red.shade700
        : Colors.black54;
    final currentText = item.isExtra
        ? '${AppStrings.stockLabel}: ${stocktakeFormatNumber(item.current)} $resolvedUnit'
        : '${AppStrings.stockLabel}: ${stocktakeFormatNumber(item.current / 1000)} $_kgUnit (${item.current.toStringAsFixed(0)} $_gUnit)';

    return StocktakeRecordCard(
      key: ValueKey(item.key),
      item: item,
      controller: ctrl,
      currentText: currentText,
      diffText: diffText,
      diffColor: diffColor,
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildLogContent(double horizontalPadding) {
    final stream = FirebaseFirestore.instance
        .collection('stocktakes')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              AppStrings.loadFailedSimple(snapshot.error ?? 'unknown'),
            ),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text(AppStrings.noItems));
        }
        return ListView.separated(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            4,
            horizontalPadding,
            24,
          ),
          itemCount: docs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) => _buildSessionCard(docs[index]),
        );
      },
    );
  }

  Widget _buildSessionCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final totals = data['totals'] as Map<String, dynamic>? ?? const {};
    final totalLines = stocktakeIntValue(totals['totalLines']);
    final overwrite = data['overwrite'] == true;
    final dateLabel = createdAt == null
        ? '--'
        : intl.DateFormat('yyyy/MM/dd - HH:mm').format(createdAt);

    return StocktakeSessionCard(
      dateLabel: dateLabel,
      totalLines: totalLines,
      overwrite: overwrite,
      onOpen: () => _openSessionDetails(doc),
    );
  }

  void _openSessionDetails(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final sessionRef = doc.reference;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.78,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (context, controller) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  const Text(
                    AppStrings.stocktakeLog,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: sessionRef
                          .collection('lines')
                          .orderBy('name')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              AppStrings.loadFailedSimple(
                                snapshot.error ?? 'unknown',
                              ),
                            ),
                          );
                        }
                        final lines = snapshot.data?.docs ?? [];
                        if (lines.isEmpty) {
                          return const Center(child: Text(AppStrings.noItems));
                        }
                        return ListView.separated(
                          controller: controller,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: lines.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) =>
                              _buildLineCard(lines[index]),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLineCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final kind = '${data['kind'] ?? ''}';
    final name = '${data['name'] ?? ''}';
    final variant = '${data['variant'] ?? ''}';
    final category = '${data['category'] ?? ''}';
    final unit = '${data['unit'] ?? ''}'.trim();
    final before = stocktakeDoubleValue(data['before']);
    final counted = stocktakeDoubleValue(data['counted']);
    final diff = stocktakeDoubleValue(data['diff']);
    final isExtra = kind == 'extra';
    final title = composeStocktakeTitle(name, variant, category);
    final resolvedUnit = stocktakeUnitFor(unit, _fallbackUnit);
    final beforeText = isExtra
        ? '${stocktakeFormatNumber(before)} $resolvedUnit'
        : '${stocktakeFormatNumber(before / 1000)} $_kgUnit';
    final countedText = isExtra
        ? '${stocktakeFormatNumber(counted)} $resolvedUnit'
        : '${stocktakeFormatNumber(counted / 1000)} $_kgUnit';
    final diffText = stocktakeFormatDiff(
      isExtra: isExtra,
      diff: diff,
      unit: resolvedUnit,
      kgUnit: _kgUnit,
    );
    final diffColor = diff > 0
        ? Colors.green.shade700
        : diff < 0
        ? Colors.red.shade700
        : Colors.black54;
    final countedLabel = isExtra
        ? AppStrings.stocktakeCountedLabelUnits
        : AppStrings.stocktakeCountedLabelKg;

    return StocktakeLineCard(
      title: title,
      beforeText: beforeText,
      countedText: countedText,
      countedLabel: countedLabel,
      diffText: diffText,
      diffColor: diffColor,
    );
  }

  ChoiceChip _filterChip(
    String label,
    StocktakeFilter filter,
    StocktakeFilter current,
  ) {
    final selected = current == filter;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => context.read<StocktakeCubit>().setFilter(filter),
      labelStyle: TextStyle(
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
      ),
    );
  }

  TextEditingController _controllerFor(String key) {
    return _countedCtrls.putIfAbsent(key, () => TextEditingController());
  }

  List<StocktakeItem> _filteredItems(
    InventoryState state,
    StocktakeFilter filter,
    String query,
  ) {
    final items = _itemsForFilter(state, filter);
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return items;
    return items
        .where(
          (item) =>
              item.name.toLowerCase().contains(normalized) ||
              item.variant.toLowerCase().contains(normalized) ||
              item.category.toLowerCase().contains(normalized),
        )
        .toList();
  }

  List<StocktakeItem> _itemsForFilter(
    InventoryState state,
    StocktakeFilter filter,
  ) {
    switch (filter) {
      case StocktakeFilter.singles:
        return state.singles
            .map((row) => StocktakeItem.fromInventory(row, unit: _gUnit))
            .toList();
      case StocktakeFilter.blends:
        return state.blends
            .map((row) => StocktakeItem.fromInventory(row, unit: _gUnit))
            .toList();
      case StocktakeFilter.extras:
        return state.extras.map(StocktakeItem.fromExtra).toList();
      case StocktakeFilter.all:
        return [
          ...state.singles.map(
            (row) => StocktakeItem.fromInventory(row, unit: _gUnit),
          ),
          ...state.blends.map(
            (row) => StocktakeItem.fromInventory(row, unit: _gUnit),
          ),
          ...state.extras.map(StocktakeItem.fromExtra),
        ];
    }
  }

  List<StocktakeItem> _allItems(InventoryState state) {
    return [
      ...state.singles.map(
        (row) => StocktakeItem.fromInventory(row, unit: _gUnit),
      ),
      ...state.blends.map(
        (row) => StocktakeItem.fromInventory(row, unit: _gUnit),
      ),
      ...state.extras.map(StocktakeItem.fromExtra),
    ];
  }

  Future<void> _submitStocktake(InventoryState state) async {
    final cubit = context.read<StocktakeCubit>();
    if (cubit.state.saving) return;
    final overwrite = cubit.state.overwrite;
    final changes = <StocktakeChange>[];
    var hasInput = false;

    for (final item in _allItems(state)) {
      final ctrl = _countedCtrls[item.key];
      if (ctrl == null) continue;
      final raw = ctrl.text.trim();
      if (raw.isEmpty) continue;
      hasInput = true;
      final counted = parseStocktakeDecimal(raw);
      if (counted == null) continue;
      if (item.isExtra) {
        final diff = counted - item.current;
        if (!stocktakeIsZero(diff)) {
          changes.add(
            StocktakeChange(item: item, counted: counted, diff: diff),
          );
        }
      } else {
        final countedG = counted * 1000;
        final diff = countedG - item.current;
        if (!stocktakeIsZero(diff)) {
          changes.add(
            StocktakeChange(item: item, counted: countedG, diff: diff),
          );
        }
      }
    }

    if (!hasInput) {
      _showSnack(AppStrings.stocktakeNoInput);
      return;
    }
    if (changes.isEmpty) {
      _showSnack(AppStrings.stocktakeNoDiff);
      return;
    }

    final confirmed = await _confirmSubmit();
    if (!confirmed || !mounted) return;

    cubit.setSaving(true);
    try {
      await _commitStocktake(changes, overwrite: overwrite);
      if (!mounted) return;
      _clearInputs();
      _showSnack(AppStrings.stocktakeSaved);
    } catch (e) {
      if (!mounted) return;
      _showSnack('${AppStrings.stocktakeSaveFailed}: $e');
    } finally {
      if (mounted) cubit.setSaving(false);
    }
  }

  Future<bool> _confirmSubmit() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.stocktakeConfirmTitle),
        content: const Text(AppStrings.stocktakeConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppStrings.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(AppStrings.actionConfirm),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _commitStocktake(
    List<StocktakeChange> changes, {
    required bool overwrite,
  }) async {
    if (changes.isEmpty) return;
    final firestore = FirebaseFirestore.instance;
    final sessionRef = firestore.collection('stocktakes').doc();
    final coffeeLines = changes.where((c) => !c.item.isExtra).length;
    final extrasLines = changes.where((c) => c.item.isExtra).length;
    final totals = {
      'totalLines': changes.length,
      'coffeeLines': coffeeLines,
      'extrasLines': extrasLines,
    };

    final ops = <void Function(WriteBatch)>[];
    ops.add(
      (batch) => batch.set(sessionRef, {
        'createdAt': FieldValue.serverTimestamp(),
        'overwrite': overwrite,
        'totals': totals,
      }),
    );

    for (final change in changes) {
      final lineRef = sessionRef.collection('lines').doc();
      final item = change.item;
      final data = <String, dynamic>{
        'kind': item.kindName,
        'itemId': item.id,
        'name': item.name,
        'unit': stocktakeUnitFor(item.unit, _fallbackUnit),
        'before': item.current,
        'counted': change.counted,
        'diff': change.diff,
        'refPath': item.ref.path,
      };
      if (item.variant.isNotEmpty) {
        data['variant'] = item.variant;
      }
      if (item.category.isNotEmpty) {
        data['category'] = item.category;
      }
      ops.add((batch) => batch.set(lineRef, data));
      if (overwrite) {
        if (item.isExtra) {
          ops.add(
            (batch) => batch.update(item.ref, {'stock_units': change.counted}),
          );
        } else {
          ops.add((batch) => batch.update(item.ref, {'stock': change.counted}));
        }
      }
    }

    var index = 0;
    while (index < ops.length) {
      final batch = firestore.batch();
      final end = (index + _batchLimit) > ops.length
          ? ops.length
          : (index + _batchLimit);
      for (var i = index; i < end; i++) {
        ops[i](batch);
      }
      await batch.commit();
      index = end;
    }
  }

  void _clearInputs() {
    for (final ctrl in _countedCtrls.values) {
      ctrl.clear();
    }
    setState(() {});
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
