import '../entities/sale.dart';
import '../entities/aggregates.dart';

class Breakdowns {
  final List<DrinkAgg> drinks;
  final List<BeansAgg> beans;
  final int cups;
  final double grams;
  final double sales;
  final double cost;
  double get profit => sales - cost;
  final int complimentaryCount;
  final double complimentaryValuePct;
  Breakdowns({
    required this.drinks,
    required this.beans,
    required this.cups,
    required this.grams,
    required this.sales,
    required this.cost,
    required this.complimentaryCount,
    required this.complimentaryValuePct,
  });
}

class BuildBreakdowns {
  Breakdowns call(List<Sale> sales) {
    final drinksMap = <String, DrinkAgg>{};
    final beansMap = <String, BeansAgg>{};

    int cups = 0;
    double grams = 0;
    double salesSum = 0;
    double costSum = 0;
    double complimentaryValue = 0;
    int complimentaryCount = 0;

    for (final s in sales) {
      final price = s.isComplimentary ? 0.0 : s.totalPrice;
      final cost = s.totalCost;
      salesSum += price;
      costSum += cost;

      if (s.isComplimentary) {
        complimentaryValue += s.totalPrice;
        complimentaryCount += 1;
      }

      if (s.type == 'drink') {
        final t = s.drinkType ?? 'Other';
        final cupsInc = (s.quantity ?? 1).round();
        cups += cupsInc;
        final agg = drinksMap[t] ?? DrinkAgg(type: t, cups: 0, sales: 0, cost: 0);
        drinksMap[t] = DrinkAgg(
          type: t,
          cups: agg.cups + cupsInc,
          sales: agg.sales + price,
          cost: agg.cost + cost,
        );
      } else {
        final double g = s.type == 'custom_blend'
            ? (s.totalGramsForCustom ?? 0)
            : (s.grams ?? 0);
        grams += g;
        final fam = s.blendFamily ?? s.singleOrigin ?? 'Other';
        final agg = beansMap[fam] ?? BeansAgg(family: fam, grams: 0, sales: 0, cost: 0);
        beansMap[fam] = BeansAgg(
          family: fam,
          grams: agg.grams + g,
          sales: agg.sales + price,
          cost: agg.cost + cost,
        );
      }
    }

    final valuePct = (salesSum + complimentaryValue) > 0
        ? (complimentaryValue / (salesSum + complimentaryValue)) * 100.0
        : 0.0;

    return Breakdowns(
      drinks: drinksMap.values.toList()..sort((a,b)=>b.sales.compareTo(a.sales)),
      beans: beansMap.values.toList()..sort((a,b)=>b.grams.compareTo(a.grams)),
      cups: cups,
      grams: grams,
      sales: salesSum,
      cost: costSum,
      complimentaryCount: complimentaryCount,
      complimentaryValuePct: valuePct,
    );
  }
}