part of '../stats_data_provider.dart';

/// KPI and grouped-metrics calculators operating on normalized rows.
Kpis _buildKpis(
  List<Map<String, dynamic>> data,
  List<Map<String, dynamic>> expensesList, {
  required DateTime startUtc,
  required DateTime endUtc,
}) {
  double sales = 0, cost = 0, profit = 0, grams = 0;
  int cups = 0;
  int units = 0;

  for (final m in data) {
    final prodInRange = _inProductionRange(m, startUtc, endUtc);
    final includeProduction = prodInRange && !_isUnpaidDeferred(m);
    final moneyFactor = _financialFactorForRange(m, startUtc, endUtc);
    if (!includeProduction && moneyFactor <= 0) continue;

    final type = '${m['type'] ?? ''}';
    final fullPrice = _resolvedSalePrice(m);
    final fullCost = _resolvedSaleCost(m);
    final fullProfit = _resolvedSaleProfit(
      m,
      resolvedPrice: fullPrice,
      resolvedCost: fullCost,
    );
    sales += fullPrice * moneyFactor;
    cost += fullCost * moneyFactor;
    profit += fullProfit * moneyFactor;

    if (includeProduction) {
      if (type == 'drink') {
        final q = (m['quantity'] is num)
            ? (m['quantity'] as num).toDouble()
            : _d(m['quantity']);
        cups += (q > 0 ? q.round() : 1);
      } else if (type == 'single' || type == 'ready_blend') {
        grams += (m['grams'] is num)
            ? (m['grams'] as num).toDouble()
            : _d(m['grams']);
      } else if (type == 'custom_blend') {
        grams += (m['total_grams'] is num)
            ? (m['total_grams'] as num).toDouble()
            : _d(m['total_grams']);
      } else if (type == 'extra') {
        final q = (m['quantity'] is num)
            ? (m['quantity'] as num).toDouble()
            : _d(m['quantity']);
        units += (q > 0 ? q.round() : 1);
      }
    }
  }

  final expensesSum = expensesList.fold<double>(
    0.0,
    (s, e) => s + _d(e['amount']),
  );

  return Kpis(
    sales: sales,
    cost: cost,
    profit: profit,
    cups: cups,
    grams: grams,
    expenses: expensesSum,
    units: units,
  );
}

/// ============ Extras (Snacks: U.O1U.U^U,/O?U.O?) by name ============
List<GroupRow> _buildExtrasRows(
  List<Map<String, dynamic>> data, {
  required DateTime startUtc,
  required DateTime endUtc,
}) {
  final map = <String, GroupRow>{};
  for (final m in data) {
    if (_isUnpaidDeferred(m)) continue;
    final prodInRange = _inProductionRange(m, startUtc, endUtc);
    final moneyFactor = _financialFactorForRange(m, startUtc, endUtc);
    if (!prodInRange && moneyFactor <= 0) continue;

    final type = '${m['type'] ?? ''}';
    final isExtra = type == 'extra' || m.containsKey('extra_id');
    if (!isExtra) continue;

    final name = ('${m['name'] ?? m['extra_name'] ?? AppStrings.noNameLabel}')
        .trim();
    final variant = ('${m['variant'] ?? ''}').trim();
    final key = variant.isEmpty ? name : '$name - $variant';

    final price = _resolvedSalePrice(m);
    final cost = _resolvedSaleCost(m);
    final profit = _resolvedSaleProfit(
      m,
      resolvedPrice: price,
      resolvedCost: cost,
    );
    final qRaw = (m['quantity'] as num?)?.toDouble() ?? _d(m['quantity']);
    final pieces = (qRaw > 0 ? qRaw.round() : 1);

    final prev = map[key] ?? const GroupRow(key: '');
    final base = prev.key.isEmpty ? GroupRow(key: key) : prev;
    map[key] = base.add(
      s: price * moneyFactor,
      c: cost * moneyFactor,
      p: profit * moneyFactor,
      cu: prodInRange ? pieces : 0,
    );
  }
  final list = map.values.toList()..sort((a, b) => b.sales.compareTo(a.sales));
  return list;
}

StatsHighlights _buildHighlights(
  List<Map<String, dynamic>> data, {
  required DateTime startUtc,
  required DateTime endUtc,
}) {
  final Map<DateTime, double> salesByDay = {};
  final Map<DateTime, double> profitByDay = {};
  final Map<DateTime, int> servingsByDay = {};
  final Map<DateTime, double> gramsByDay = {};
  final Map<DateTime, Set<String>> ordersByDay = {};

  double totalSales = 0;
  int totalDrinkServings = 0;
  int totalSnackServings = 0;
  double totalBeansGrams = 0;
  final uniqueOrders = <String>{};

  for (final m in data) {
    if (_isUnpaidDeferred(m)) continue;
    final prodInRange = _inProductionRange(m, startUtc, endUtc);
    final moneyFactor = _financialFactorForRange(m, startUtc, endUtc);
    if (!prodInRange && moneyFactor <= 0) continue;

    final finDay = opDayKeyUtc(_financialUtc(m));
    final prodDay = opDayKeyUtc(_productionUtc(m));

    if (moneyFactor > 0) {
      final price = _resolvedSalePrice(m) * moneyFactor;
      final profit = _resolvedSaleProfit(m) * moneyFactor;

      final saleId = '${m['sale_id'] ?? m['id'] ?? ''}'.trim();
      if (saleId.isNotEmpty) {
        uniqueOrders.add(saleId);
        final set = ordersByDay.putIfAbsent(finDay, () => <String>{});
        set.add(saleId);
      }

      salesByDay[finDay] = (salesByDay[finDay] ?? 0) + price;
      profitByDay[finDay] = (profitByDay[finDay] ?? 0) + profit;
      totalSales += price;
    }

    if (prodInRange) {
      final type = '${m['type'] ?? ''}';
      int servings = 0;
      double grams = 0;
      if (type == 'drink') {
        final q = (m['quantity'] as num?)?.toDouble() ?? _d(m['quantity']);
        servings = (q > 0 ? q.round() : 1);
        totalDrinkServings += servings;
      } else if (type == 'single' || type == 'ready_blend') {
        grams = (m['grams'] as num?)?.toDouble() ?? _d(m['grams']);
      } else if (type == 'custom_blend') {
        grams = (m['total_grams'] as num?)?.toDouble() ?? _d(m['total_grams']);
      } else {
        final isExtra = type == 'extra' || m.containsKey('extra_id');
        if (isExtra) {
          final q = (m['quantity'] as num?)?.toDouble() ?? _d(m['quantity']);
          servings = (q > 0 ? q.round() : 1);
          totalSnackServings += servings;
        }
      }

      if (servings > 0) {
        servingsByDay[prodDay] = (servingsByDay[prodDay] ?? 0) + servings;
      }
      if (grams > 0) {
        gramsByDay[prodDay] = (gramsByDay[prodDay] ?? 0) + grams;
        totalBeansGrams += grams;
      }
    }
  }

  DateTime? maxDayBySales;
  double maxSales = -1;
  salesByDay.forEach((day, value) {
    if (value > maxSales) {
      maxSales = value;
      maxDayBySales = day;
    }
  });

  DateTime? maxDayByProfit;
  double maxProfit = -1;
  profitByDay.forEach((day, value) {
    if (value > maxProfit) {
      maxProfit = value;
      maxDayByProfit = day;
    }
  });

  DateTime? maxDayByServings;
  int maxServings = -1;
  servingsByDay.forEach((day, value) {
    if (value > maxServings) {
      maxServings = value;
      maxDayByServings = day;
    }
  });

  DayHighlight? highlightFor(
    DateTime? day, {
    required Map<DateTime, double> bySales,
    required Map<DateTime, double> byProfit,
    required Map<DateTime, int> byServings,
    required Map<DateTime, Set<String>> byOrders,
  }) {
    if (day == null) return null;
    return DayHighlight(
      day: day,
      sales: bySales[day] ?? 0,
      profit: byProfit[day] ?? 0,
      servings: byServings[day] ?? 0,
      orders: byOrders[day]?.length ?? 0,
    );
  }

  final activeSalesDays = salesByDay.keys.length;
  final activeProdDays = servingsByDay.keys.length;
  final activeBeansDays = gramsByDay.keys.length;
  final totalOrders = uniqueOrders.length;

  final avgDailySales = activeSalesDays > 0
      ? (totalSales / activeSalesDays)
      : 0.0;
  final avgDrinksPerDay = activeProdDays > 0
      ? (totalDrinkServings / activeProdDays)
      : 0.0;
  final avgSnacksPerDay = activeProdDays > 0
      ? (totalSnackServings / activeProdDays)
      : 0.0;
  final avgBeansGramsPerDay = activeBeansDays > 0
      ? (totalBeansGrams / activeBeansDays)
      : 0.0;
  final avgOrdersPerDay = activeSalesDays > 0
      ? (totalOrders / activeSalesDays)
      : 0.0;

  return StatsHighlights(
    topSalesDay: highlightFor(
      maxDayBySales,
      bySales: salesByDay,
      byProfit: profitByDay,
      byServings: servingsByDay,
      byOrders: ordersByDay,
    ),
    topProfitDay: highlightFor(
      maxDayByProfit,
      bySales: salesByDay,
      byProfit: profitByDay,
      byServings: servingsByDay,
      byOrders: ordersByDay,
    ),
    busiestDay: highlightFor(
      maxDayByServings,
      bySales: salesByDay,
      byProfit: profitByDay,
      byServings: servingsByDay,
      byOrders: ordersByDay,
    ),
    averageDailySales: avgDailySales,
    averageDrinksPerDay: avgDrinksPerDay,
    averageSnacksPerDay: avgSnacksPerDay,
    averageBeansGramsPerDay: avgBeansGramsPerDay,
    averageOrdersPerDay: avgOrdersPerDay,
    totalOrders: totalOrders,
    activeDays: activeSalesDays,
  );
}

/// ============ Drinks/Beans by name ============

List<GroupRow> _buildDrinksRows(
  List<Map<String, dynamic>> data, {
  required DateTime startUtc,
  required DateTime endUtc,
}) {
  final map = <String, GroupRow>{};
  for (final m in data) {
    if (_isUnpaidDeferred(m)) continue;
    final prodInRange = _inProductionRange(m, startUtc, endUtc);
    final moneyFactor = _financialFactorForRange(m, startUtc, endUtc);
    if (!prodInRange && moneyFactor <= 0) continue;
    if ('${m['type'] ?? ''}' != 'drink') continue;

    final name =
        ('${m['drink_name'] ?? m['name'] ?? 'U.O'
                    'O?U^O"'}')
            .trim();
    final variant = ('${m['variant'] ?? m['roast'] ?? ''}').trim();
    final key = variant.isEmpty ? name : '$name - $variant';

    final price = _resolvedSalePrice(m);
    final cost = _resolvedSaleCost(m);
    final profit = _resolvedSaleProfit(
      m,
      resolvedPrice: price,
      resolvedCost: cost,
    );
    final qRaw = (m['quantity'] as num?)?.toDouble() ?? _d(m['quantity']);
    final cups = (qRaw > 0 ? qRaw.round() : 1);

    final prev = map[key] ?? const GroupRow(key: '');
    final base = prev.key.isEmpty ? GroupRow(key: key) : prev;
    map[key] = base.add(
      s: price * moneyFactor,
      c: cost * moneyFactor,
      p: profit * moneyFactor,
      cu: prodInRange ? cups : 0,
    );
  }

  final list = map.values.toList()..sort((a, b) => b.sales.compareTo(a.sales));
  return list;
}

/// USU?U?U`U? "O?U^U,USU?Oc OU,O1U.USU," U^USO?U.O1 U?U, U.U?U^U`U+ O"OO3U.U?U? (name - variant)
List<GroupRow> _buildBeansRows(
  List<Map<String, dynamic>> data, {
  required DateTime startUtc,
  required DateTime endUtc,
}) {
  final map = <String, GroupRow>{};

  List<Map<String, dynamic>> asListMap(dynamic v) {
    if (v is List) {
      return v
          .map(
            (e) => (e is Map) ? e.cast<String, dynamic>() : <String, dynamic>{},
          )
          .toList();
    }
    return const [];
  }

  Map<String, dynamic> normRow(
    Map<String, dynamic> c, {
    required bool fallbackSpiced,
  }) {
    String name = (c['name'] ?? c['item_name'] ?? c['product_name'] ?? '')
        .toString();
    String variant = (c['variant'] ?? c['roast'] ?? '').toString();
    double grams = _pickNum(c, ['grams', 'weight', 'gram', 'total_grams']);
    double linePrice = _pickNum(c, [
      'line_total_price',
      'total_price',
      'price',
      'line_price',
      'amount',
      'total',
      'subtotal',
    ]);
    double lineCost = _pickNum(c, [
      'line_total_cost',
      'total_cost',
      'cost',
      'line_cost',
      'cost_amount',
    ]);
    final meta = _metaOf(c);
    final hasMetaSpiced =
        meta.containsKey('spiced') || meta.containsKey('spicedEnabled');
    final hasTopSpiced =
        c.containsKey('spiced') ||
        c.containsKey('spicedEnabled') ||
        c.containsKey('is_spiced');
    bool? spicedEnabled;
    if (hasMetaSpiced && meta.containsKey('spicedEnabled')) {
      spicedEnabled = _readBool(meta['spicedEnabled']);
    } else if (c.containsKey('spicedEnabled')) {
      spicedEnabled = _readBool(c['spicedEnabled']);
    }
    bool? spicedVal;
    if (hasMetaSpiced && meta.containsKey('spiced')) {
      spicedVal = _readBool(meta['spiced']);
    } else if (c.containsKey('spiced')) {
      spicedVal = _readBool(c['spiced']);
    } else if (c.containsKey('is_spiced')) {
      spicedVal = _readBool(c['is_spiced']);
    }
    if (spicedEnabled == null && spicedVal == true) {
      spicedEnabled = true;
    }
    final isSpiced = (hasMetaSpiced || hasTopSpiced)
        ? (spicedEnabled == true ? (spicedVal ?? false) : false)
        : fallbackSpiced;
    return {
      'name': name.trim(),
      'variant': variant.trim(),
      'grams': grams,
      'line_total_price': linePrice,
      'line_total_cost': lineCost,
      'is_spiced': isSpiced,
    };
  }

  void addToMap({
    required String key,
    double grams = 0,
    double sales = 0,
    double cost = 0,
    bool isSpiced = false,
  }) {
    final prev = map[key] ?? const GroupRow(key: '');
    final base = prev.key.isEmpty ? GroupRow(key: key) : prev;
    map[key] = base.add(
      g: grams,
      gPlain: isSpiced ? 0 : grams,
      gSpiced: isSpiced ? grams : 0,
      s: sales,
      c: cost,
      p: (sales - cost),
      cu: 0,
    );
  }

  for (final m in data) {
    if (_isUnpaidDeferred(m)) continue;
    final prodInRange = _inProductionRange(m, startUtc, endUtc);
    final moneyFactor = _financialFactorForRange(m, startUtc, endUtc);
    if (!prodInRange && moneyFactor <= 0) continue;
    final includeGrams = prodInRange;
    final includeMoney = moneyFactor > 0;

    final type = '${m['type'] ?? ''}';
    final saleIsSpiced = (m['is_spiced'] ?? false) == true;

    if (type == 'single' || type == 'ready_blend') {
      final name = ('${m['name'] ?? m['single_name'] ?? m['blend_name'] ?? ''}')
          .trim();
      final variant = ('${m['variant'] ?? m['roast'] ?? ''}').trim();
      final key = name.isEmpty
          ? 'O"O_U^U+ OO3U.'
          : (variant.isEmpty ? name : '$name - $variant');

      final grams = (m['grams'] as num?)?.toDouble() ?? _d(m['grams']);
      final price =
          (m['total_price'] as num?)?.toDouble() ?? _d(m['total_price']);
      final cost = (m['total_cost'] as num?)?.toDouble() ?? _d(m['total_cost']);

      addToMap(
        key: key,
        grams: includeGrams ? grams : 0,
        sales: includeMoney ? (price * moneyFactor) : 0,
        cost: includeMoney ? (cost * moneyFactor) : 0,
        isSpiced: saleIsSpiced,
      );
      continue;
    }

    if (type == 'custom_blend') {
      final comps = asListMap(m['components']);
      final items = asListMap(m['items']);
      final lines = asListMap(m['lines']);
      final rowsRaw = comps.isNotEmpty
          ? comps
          : (items.isNotEmpty ? items : lines);

      if (rowsRaw.isEmpty) {
        final gramsAll =
            (m['total_grams'] as num?)?.toDouble() ?? _d(m['total_grams']);
        final price =
            (m['lines_amount'] as num?)?.toDouble() ??
            (m['beans_amount'] as num?)?.toDouble() ??
            0.0;
        final cost = (m['total_cost'] as num?)?.toDouble() ?? 0.0;
        addToMap(
          key: 'U.OrO?O?',
          grams: includeGrams ? gramsAll : 0,
          sales: includeMoney ? (price * moneyFactor) : 0,
          cost: includeMoney ? (cost * moneyFactor) : 0,
          isSpiced: saleIsSpiced,
        );
        continue;
      }

      final rows = rowsRaw
          .map((r) => normRow(r, fallbackSpiced: saleIsSpiced))
          .toList();
      final totalGrams = rows.fold<double>(
        0,
        (s, r) => s + (r['grams'] as double),
      );
      final beansAmount =
          (m['lines_amount'] as num?)?.toDouble() ??
          (m['beans_amount'] as num?)?.toDouble() ??
          0.0;

      for (final r in rows) {
        final name = r['name'] as String;
        final variant = r['variant'] as String;
        final grams = r['grams'] as double;
        final isRowSpiced = (r['is_spiced'] as bool?) ?? saleIsSpiced;
        if (name.isEmpty && grams <= 0) continue;

        final key = (variant.isEmpty ? name : '$name - $variant').trim().isEmpty
            ? 'U.U?U^U`U+'
            : (variant.isEmpty ? name : '$name - $variant');

        double linePrice = r['line_total_price'] as double;
        double lineCost = r['line_total_cost'] as double;

        if (linePrice <= 0 && beansAmount > 0 && totalGrams > 0) {
          linePrice = beansAmount * (grams / totalGrams);
        }

        addToMap(
          key: key,
          grams: includeGrams ? grams : 0,
          sales: includeMoney ? (linePrice * moneyFactor) : 0,
          cost: includeMoney ? (lineCost * moneyFactor) : 0,
          isSpiced: isRowSpiced,
        );
      }
    }
  }

  final list = map.values.toList()..sort((a, b) => b.sales.compareTo(a.sales));
  return list;
}

List<GroupRow> _buildTurkishRows(
  List<Map<String, dynamic>> data, {
  required DateTime startUtc,
  required DateTime endUtc,
}) {
  final map = <String, GroupRow>{};

  for (final m in data) {
    if (_isUnpaidDeferred(m)) continue;
    final prodInRange = _inProductionRange(m, startUtc, endUtc);
    final moneyFactor = _financialFactorForRange(m, startUtc, endUtc);
    if (!prodInRange && moneyFactor <= 0) continue;

    final type = '${m['type'] ?? ''}';
    if (type != 'drink') continue;

    final name = ('${m['drink_name'] ?? m['name'] ?? ''}').trim();
    if (name.isEmpty || !_isTurkishCoffeeName(name)) continue;

    final variant = ('${m['variant'] ?? m['roast'] ?? ''}').trim();
    final key = variant.isEmpty ? name : '$name - $variant';

    final includeGrams = prodInRange;
    final includeMoney = moneyFactor > 0;

    final qRaw = (m['quantity'] as num?)?.toDouble() ?? _d(m['quantity']);
    final cups = qRaw > 0 ? qRaw.round() : 1;
    final price = _resolvedSalePrice(m);
    final cost = _resolvedSaleCost(m);
    final isSpiced = _isSpicedFrom(m);

    final cupsValue = includeGrams ? cups : 0;
    final salesValue = includeMoney ? (price * moneyFactor) : 0.0;
    final costValue = includeMoney ? (cost * moneyFactor) : 0.0;

    final prev = map[key] ?? const GroupRow(key: '');
    final base = prev.key.isEmpty ? GroupRow(key: key) : prev;
    map[key] = base.add(
      g: 0,
      gPlain: isSpiced ? 0 : cupsValue.toDouble(),
      gSpiced: isSpiced ? cupsValue.toDouble() : 0,
      s: salesValue,
      c: costValue,
      p: salesValue - costValue,
      cu: cupsValue,
    );
  }

  final list = map.values.toList()..sort((a, b) => b.sales.compareTo(a.sales));
  return list;
}

/// ============ Trends (مدفوع فقط + الربح من الداتا) ============

TrendsBundle _buildTrends(
  List<Map<String, dynamic>> data, {
  required DateTime startUtc,
  required DateTime endUtc,
}) {
  final Map<DateTime, double> salesM = {};
  final Map<DateTime, double> profitM = {};
  final Map<DateTime, double> beansGramsM = {};
  final Map<DateTime, double> beansSalesM = {};
  final Map<DateTime, double> beansProfitM = {};
  final Map<DateTime, double> turkishCupsM = {};
  final Map<DateTime, double> turkishSalesM = {};
  final Map<DateTime, double> turkishProfitM = {};

  for (final m in data) {
    if (_isUnpaidDeferred(m)) continue;
    final prodInRange = _inProductionRange(m, startUtc, endUtc);
    final moneyFactor = _financialFactorForRange(m, startUtc, endUtc);
    if (!prodInRange && moneyFactor <= 0) continue;

    final k = opDayKeyUtc(_financialUtc(m));
    final prodKey = opDayKeyUtc(_productionUtc(m));
    final type = '${m['type'] ?? ''}';

    if (moneyFactor > 0) {
      final price = _resolvedSalePrice(m) * moneyFactor;
      final profit = _resolvedSaleProfit(m) * moneyFactor;

      salesM[k] = (salesM[k] ?? 0) + price;
      profitM[k] = (profitM[k] ?? 0) + profit;

      if (type == 'single' || type == 'ready_blend' || type == 'custom_blend') {
        beansSalesM[k] = (beansSalesM[k] ?? 0) + price;
        beansProfitM[k] = (beansProfitM[k] ?? 0) + profit;
      }
      if (type == 'drink' &&
          _isTurkishCoffeeName(_pickStr(m, ['drink_name', 'name']))) {
        turkishSalesM[k] = (turkishSalesM[k] ?? 0) + price;
        turkishProfitM[k] = (turkishProfitM[k] ?? 0) + profit;
      }
    }

    if (prodInRange &&
        (type == 'single' || type == 'ready_blend' || type == 'custom_blend')) {
      final gramsValue = type == 'custom_blend'
          ? _d(m['total_grams'])
          : _d(m['grams']);
      beansGramsM[prodKey] = (beansGramsM[prodKey] ?? 0) + gramsValue;
    }
    if (prodInRange &&
        type == 'drink' &&
        _isTurkishCoffeeName(_pickStr(m, ['drink_name', 'name']))) {
      final q = (m['quantity'] as num?)?.toDouble() ?? _d(m['quantity']);
      final cups = q > 0 ? q : 1.0;
      turkishCupsM[prodKey] = (turkishCupsM[prodKey] ?? 0) + cups;
    }
  }

  List<DayVal> toList(Map<DateTime, double> mp) {
    final ks = mp.keys.toList()..sort();
    return ks.map((d) => DayVal(d, mp[d] ?? 0)).toList();
  }

  return TrendsBundle(
    totalSales: toList(salesM),
    totalProfit: toList(profitM),
    beansGrams: toList(beansGramsM),
    beansSales: toList(beansSalesM),
    beansProfit: toList(beansProfitM),
    turkishCups: toList(turkishCupsM),
    turkishSales: toList(turkishSalesM),
    turkishProfit: toList(turkishProfitM),
  );
}
