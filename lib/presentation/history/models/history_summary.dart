import 'package:elfouad_admin/core/utils/app_strings.dart';

import '../utils/sale_utils.dart';
import 'sale_record.dart';

class HistorySummary {
  const HistorySummary({
    required this.sales,
    required this.cost,
    required this.profit,
    required this.drinks,
    required this.snacks,
    required this.grams,
  });

  final double sales;
  final double cost;
  final double profit;
  final int drinks;
  final int snacks;
  final double grams;

  factory HistorySummary.empty() => const HistorySummary(
    sales: 0,
    cost: 0,
    profit: 0,
    drinks: 0,
    snacks: 0,
    grams: 0,
  );

  HistorySummary copyWith({
    double? sales,
    double? cost,
    double? profit,
    int? drinks,
    int? snacks,
    double? grams,
  }) {
    return HistorySummary(
      sales: sales ?? this.sales,
      cost: cost ?? this.cost,
      profit: profit ?? this.profit,
      drinks: drinks ?? this.drinks,
      snacks: snacks ?? this.snacks,
      grams: grams ?? this.grams,
    );
  }

  factory HistorySummary.fromRecords(Iterable<SaleRecord> records) {
    double sales = 0;
    double cost = 0;
    double profit = 0;
    double grams = 0;
    int drinks = 0;
    int snacks = 0;

    for (final record in records) {
      final isComplimentary = record.isComplimentary;
      final totalPrice = isComplimentary ? 0.0 : record.totalPrice;
      final totalCost = record.totalCost;
      final rawProfit = isComplimentary
          ? 0.0
          : parseDouble(record.data['profit_total']);
      final resolvedProfit = isComplimentary
          ? 0.0
          : (rawProfit != 0 ? rawProfit : (totalPrice - totalCost));

      sales += totalPrice;
      cost += totalCost;
      profit += resolvedProfit;

      switch (record.type) {
        case 'drink':
          drinks += _recordQuantity(record);
          break;
        case 'extra':
          snacks += _recordQuantity(record);
          break;
        case 'single':
        case 'ready_blend':
          grams += _recordGrams(record, fallbackKey: 'grams');
          break;
        case 'custom_blend':
          grams += _recordGrams(record, fallbackKey: 'total_grams');
          break;
        default:
          final components = record.components;
          if (components.isNotEmpty) {
            for (final component in components) {
              if (component.grams > 0) {
                grams += component.grams;
                continue;
              }
              final qty = _roundQty(component.quantity);
              final unit = component.unit.trim().toLowerCase();
              if (_isSnackUnit(unit)) {
                snacks += qty;
              } else {
                drinks += qty;
              }
            }
          }
          break;
      }
    }

    return HistorySummary(
      sales: sales,
      cost: cost,
      profit: profit,
      drinks: drinks,
      snacks: snacks,
      grams: grams,
    );
  }
}

int _roundQty(double qty) => qty > 0 ? qty.round() : 1;

int _recordQuantity(SaleRecord record) {
  final byComponents = record.components.fold<double>(
    0.0,
    (total, component) => total + component.quantity,
  );
  final fallback = parseDouble(record.data['quantity'] ?? record.data['qty']);
  final qty = byComponents > 0 ? byComponents : fallback;
  return _roundQty(qty);
}

double _recordGrams(SaleRecord record, {String? fallbackKey}) {
  final byComponents = record.components.fold<double>(
    0.0,
    (total, component) => total + component.grams,
  );
  if (byComponents > 0) return byComponents;
  if (fallbackKey != null) {
    final fallback = parseDouble(record.data[fallbackKey]);
    if (fallback > 0) return fallback;
  }
  return parseDouble(record.data['grams']);
}

bool _isSnackUnit(String unit) {
  if (unit.isEmpty) return false;
  if (unit == 'piece' || unit == 'pcs' || unit == 'pc') return true;
  return unit == AppStrings.labelPieceUnit;
}
