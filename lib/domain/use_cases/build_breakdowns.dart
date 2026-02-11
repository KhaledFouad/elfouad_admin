import '../entities/sale.dart';
import '../entities/aggregates.dart';
import '../../services/classifiers/drink_classifier.dart';
import '../../services/classifiers/blend_family_classifier.dart';

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
  const Breakdowns({
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
      final priceEffective = s.isComplimentary ? 0.0 : s.totalPrice;
      final cost = s.totalCost;
      salesSum += priceEffective;
      costSum += cost;
      if (s.isComplimentary) {
        complimentaryValue += s.totalPrice;
        complimentaryCount += 1;
      }

      if (s.type == 'drink') {
        final inferredType =
            s.drinkType ??
            DrinkClassifier.classify(
              (s.drinkName?.isNotEmpty ?? false) ? s.drinkName! : s.name,
            );
        final addCups = (s.quantity ?? 1).round();
        cups += addCups;
        final cur =
            drinksMap[inferredType] ??
            DrinkAgg(type: inferredType, cups: 0, sales: 0, cost: 0);
        drinksMap[inferredType] = DrinkAgg(
          type: inferredType,
          cups: cur.cups + addCups,
          sales: cur.sales + priceEffective,
          cost: cur.cost + cost,
        );
      } else {
        final g = s.type == 'custom_blend'
            ? (s.totalGramsForCustom ?? 0)
            : (s.grams ?? 0);
        grams += g;
        final inferred =
            s.blendFamily ??
            s.singleOrigin ??
            BlendFamilyClassifier.classify(s.name);
        final cur =
            beansMap[inferred] ??
            BeansAgg(family: inferred, grams: 0, sales: 0, cost: 0);
        beansMap[inferred] = BeansAgg(
          family: inferred,
          grams: cur.grams + g,
          sales: cur.sales + priceEffective,
          cost: cur.cost + cost,
        );
      }
    }
    final valuePct = (salesSum + complimentaryValue) > 0
        ? (complimentaryValue / (salesSum + complimentaryValue)) * 100.0
        : 0.0;
    return Breakdowns(
      drinks: drinksMap.values.toList()
        ..sort((a, b) => b.sales.compareTo(a.sales)),
      beans: beansMap.values.toList()
        ..sort((a, b) => b.grams.compareTo(a.grams)),
      cups: cups,
      grams: grams,
      sales: salesSum,
      cost: costSum,
      complimentaryCount: complimentaryCount,
      complimentaryValuePct: valuePct,
    );
  }
}
