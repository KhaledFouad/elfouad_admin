import 'package:awesome_drawer_bar/awesome_drawer_bar.dart';
import 'package:elfouad_admin/core/app_strings.dart';
import 'package:elfouad_admin/presentation/grind/state/grind_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'widgets/grind_confirm_sheet.dart';

class GrindPage extends StatelessWidget {
  const GrindPage({super.key});
  static const route = '/grind';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GrindCubit>().state;
    final filtered = state.filtered;

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
                AppStrings.expensesTitle,
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
        body: Column(
          children: [
            // ???? ????: ????? ??
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF7EFE8),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(18),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: TextField(
                decoration: InputDecoration(
                  hintText: AppStrings.grindSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (t) => context.read<GrindCubit>().setQuery(t),
                controller: TextEditingController(text: state.query)
                  ..selection =
                      TextSelection.collapsed(offset: state.query.length),
              ),
            ),

            Expanded(
              child: state.loading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? const Center(child: Text(AppStrings.noItems))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (_, i) => _ItemCard(row: filtered[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final InventoryRow row;
  const _ItemCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final title = row.variant.trim().isEmpty
        ? row.name
        : '${row.name} - ${row.variant}';

    // ????? ???? ?????? ???? ????? ???? ?????
    double maxBar(double x) {
      if (x <= 500) return 500;
      if (x <= 2000) return 2000;
      if (x <= 5000) return 5000;
      return 20000;
    }

    final pct = row.stockG <= 0 ? 0.0 : (row.stockG / maxBar(row.stockG));

    return InkWell(
      onTap: () {
        final root = context;

        FocusScope.of(root).unfocus(); // ?? ???? ?? ?????? ?????

        showModalBottomSheet(
          context: context,
          useSafeArea: true,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          builder: (_) => GrindConfirmSheet(row: row),
        ).whenComplete(() {
          if (!root.mounted) return;
          FocusScope.of(root).unfocus();
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF3ED),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.brown.shade100, width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: row.coll == 'blends'
                    ? Colors.brown.shade700
                    : Colors.brown.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                row.coll == 'blends'
                    ? AppStrings.blendLabel
                    : AppStrings.singleLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: pct.clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: Colors.brown.shade100,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppStrings.availableGrams(row.stockG),
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
