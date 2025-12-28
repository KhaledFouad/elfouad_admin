import 'package:awesome_drawer_bar/awesome_drawer_bar.dart';
import 'package:elfouad_admin/core/app_strings.dart';
import 'package:elfouad_admin/presentation/inventory/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'widgets/inventory_tile.dart';

class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});
  static const route = '/inventory';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<InventoryCubit>().state;
    final max = state.maxStock;
    final list = state.listForTab;
    final tab = state.tab;

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

              automaticallyImplyLeading: false,
              leading: IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => AwesomeDrawerBar.of(context)?.toggle(),
              ),
              title: const Text(
                AppStrings.tabInventory,
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
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 8,
                      children: [
                        _chip(
                          context,
                          AppStrings.inventoryAll,
                          InventoryTab.all,
                          tab,
                        ),
                        _chip(
                          context,
                          AppStrings.inventorySingles,
                          InventoryTab.singles,
                          tab,
                        ),
                        _chip(
                          context,
                          AppStrings.inventoryBlends,
                          InventoryTab.blends,
                          tab,
                        ),
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
                          child: Text(AppStrings.drinksNoStockNote),
                        ),
                      )
                    else if (list.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: Text(AppStrings.noItems)),
                      )
                    else
                      const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
            if (list.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final r = list[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InventoryTile.coffee(
                        key: ValueKey(r.id),
                        row: r,
                        maxStockForBar: max,
                      ),
                    );
                  }, childCount: list.length),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    String label,
    InventoryTab me,
    InventoryTab cur,
  ) {
    final selected = me == cur;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => context.read<InventoryCubit>().setTab(me),
      labelStyle: TextStyle(
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
      ),
    );
  }
}
