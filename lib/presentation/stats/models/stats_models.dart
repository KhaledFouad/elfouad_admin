class Kpis {
  final double sales, cost, profit, grams;
  final int cups, units;
  final double expenses;
  const Kpis({
    required this.sales,
    required this.cost,
    required this.profit,
    required this.cups,
    required this.grams,
    required this.expenses,
    required this.units,
  });
}

class MonthlyKpi {
  final DateTime month;
  final Kpis kpis;
  const MonthlyKpi({required this.month, required this.kpis});
}

class GroupRow {
  final String key;
  final double sales, cost, profit, grams;
  final double plainGrams;
  final double spicedGrams;
  final int cups;
  const GroupRow({
    required this.key,
    this.sales = 0,
    this.cost = 0,
    this.profit = 0,
    this.grams = 0,
    this.plainGrams = 0,
    this.spicedGrams = 0,
    this.cups = 0,
  });

  String get name => key;

  GroupRow add({
    double s = 0,
    double c = 0,
    double p = 0,
    double g = 0,
    double gPlain = 0,
    double gSpiced = 0,
    int cu = 0,
  }) => GroupRow(
    key: key,
    sales: sales + s,
    cost: cost + c,
    profit: profit + p,
    grams: grams + g,
    plainGrams: plainGrams + gPlain,
    spicedGrams: spicedGrams + gSpiced,
    cups: cups + cu,
  );
}

class DayVal {
  final DateTime day;
  final double v;
  const DayVal(this.day, this.v);
}

class DayHighlight {
  final DateTime day;
  final double sales;
  final double profit;
  final int servings;
  final int orders;
  const DayHighlight({
    required this.day,
    required this.sales,
    required this.profit,
    required this.servings,
    required this.orders,
  });
}

class StatsHighlights {
  final DayHighlight? topSalesDay;
  final DayHighlight? topProfitDay;
  final DayHighlight? busiestDay;
  final double averageDailySales;
  final double averageDrinksPerDay;
  final double averageSnacksPerDay;
  final double averageBeansGramsPerDay;
  final double averageOrdersPerDay;
  final int totalOrders;
  final int activeDays;
  const StatsHighlights({
    required this.topSalesDay,
    required this.topProfitDay,
    required this.busiestDay,
    required this.averageDailySales,
    required this.averageDrinksPerDay,
    required this.averageSnacksPerDay,
    required this.averageBeansGramsPerDay,
    required this.averageOrdersPerDay,
    required this.totalOrders,
    required this.activeDays,
  });
}

class StatsOverview {
  final Kpis kpis;
  final List<GroupRow> drinks;
  final List<GroupRow> beans;
  final List<GroupRow> turkish;
  final List<GroupRow> extras;
  final TrendsBundle trends;
  final StatsHighlights highlights;
  const StatsOverview({
    required this.kpis,
    required this.drinks,
    required this.beans,
    required this.turkish,
    required this.extras,
    required this.trends,
    required this.highlights,
  });
}

class TrendsBundle {
  final List<DayVal> totalSales;
  final List<DayVal> totalProfit;
  final List<DayVal> drinksSales;
  final List<DayVal> drinksProfit;
  final List<DayVal> beansSales;
  final List<DayVal> beansProfit;
  const TrendsBundle({
    required this.totalSales,
    required this.totalProfit,
    required this.drinksSales,
    required this.drinksProfit,
    required this.beansSales,
    required this.beansProfit,
  });
}

class ThirdsPreview {
  final Kpis firstThird;
  final Kpis secondThird;
  final Kpis thirdThird;
  final Kpis month;
  const ThirdsPreview({
    required this.firstThird,
    required this.secondThird,
    required this.thirdThird,
    required this.month,
  });
}
