import 'package:elfouad_admin/core/utils/app_strings.dart';
import 'package:elfouad_admin/presentation/history/utils/sale_utils.dart';
import 'package:elfouad_admin/presentation/archive/bloc/archive_trash_state.dart';
import 'package:elfouad_admin/presentation/archive/models/archive_entry.dart';

List<ArchiveEntry> filterEntries(
  List<ArchiveEntry> entries,
  ArchiveFilter filter,
) {
  switch (filter) {
    case ArchiveFilter.all:
      return entries;
    case ArchiveFilter.sales:
      return entries.where((e) => e.kind == 'sale').toList();
    case ArchiveFilter.products:
      return entries
          .where((e) => e.kind == 'product_single' || e.kind == 'blend')
          .toList();
    case ArchiveFilter.expenses:
      return entries.where((e) => e.kind == 'expense').toList();
    case ArchiveFilter.inventory:
      return entries.where((e) => e.kind == 'inventory_row').toList();
    case ArchiveFilter.recipes:
      return entries.where((e) => e.kind == 'recipe').toList();
    case ArchiveFilter.extras:
      return entries.where((e) => e.kind == 'extra').toList();
    case ArchiveFilter.drinks:
      return entries.where((e) => e.kind == 'drink').toList();
  }
}

String filterLabel(ArchiveFilter filter) {
  switch (filter) {
    case ArchiveFilter.all:
      return AppStrings.archiveFilterAll;
    case ArchiveFilter.sales:
      return AppStrings.archiveFilterSales;
    case ArchiveFilter.products:
      return AppStrings.archiveFilterProducts;
    case ArchiveFilter.expenses:
      return AppStrings.archiveFilterExpenses;
    case ArchiveFilter.inventory:
      return AppStrings.archiveFilterInventory;
    case ArchiveFilter.recipes:
      return AppStrings.archiveFilterRecipes;
    case ArchiveFilter.extras:
      return AppStrings.archiveFilterExtras;
    case ArchiveFilter.drinks:
      return AppStrings.archiveFilterDrinks;
  }
}

String kindLabel(String kind) {
  switch (kind) {
    case 'sale':
      return AppStrings.archiveFilterSales;
    case 'expense':
      return AppStrings.archiveFilterExpenses;
    case 'inventory_row':
      return AppStrings.archiveFilterInventory;
    case 'recipe':
      return AppStrings.archiveFilterRecipes;
    case 'extra':
      return AppStrings.archiveFilterExtras;
    case 'drink':
      return AppStrings.archiveFilterDrinks;
    case 'blend':
    case 'product_single':
      return AppStrings.archiveFilterProducts;
    default:
      return kind;
  }
}

String entryTitle(ArchiveEntry entry) {
  if (entry.displayName != null && entry.displayName!.isNotEmpty) {
    return entry.displayName!;
  }

  final data = entry.data;
  switch (entry.kind) {
    case 'sale':
      final type = detectSaleType(data);
      return buildTitleLine(data, type);
    case 'expense':
      return (data['title'] ?? AppStrings.noNameLabel).toString();
    case 'recipe':
      return (data['name'] ?? AppStrings.noNameLabel).toString();
    case 'extra':
    case 'drink':
    case 'blend':
    case 'product_single':
    case 'inventory_row':
      final name = (data['name'] ?? AppStrings.noNameLabel).toString();
      final variant = (data['variant'] ?? '').toString();
      return variant.isEmpty ? name : '$name - $variant';
    default:
      return (data['name'] ?? AppStrings.noNameLabel).toString();
  }
}
