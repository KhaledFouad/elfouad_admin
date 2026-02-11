import 'dart:math';

class ArchiveSummary {
  final double? sales;
  final double? profit;
  final double? cost;
  final double? expenses;
  final double? grams;
  final int? drinks;
  final int? snacks;

  const ArchiveSummary({
    this.sales,
    this.profit,
    this.cost,
    this.expenses,
    this.grams,
    this.drinks,
    this.snacks,
  });

  bool get isEmpty =>
      (sales ?? 0) == 0 &&
      (profit ?? 0) == 0 &&
      (cost ?? 0) == 0 &&
      (expenses ?? 0) == 0 &&
      (grams ?? 0) == 0 &&
      (drinks ?? 0) == 0 &&
      (snacks ?? 0) == 0;
}

class ArchiveMonth {
  final String id;
  final Map<String, dynamic> data;

  const ArchiveMonth({required this.id, required this.data});

  factory ArchiveMonth.fromCache(Map<String, dynamic> json) {
    final rawData = json['data'];
    return ArchiveMonth(
      id: json['id']?.toString() ?? '',
      data: rawData is Map
          ? rawData.cast<String, dynamic>()
          : <String, dynamic>{},
    );
  }

  Map<String, dynamic> toCache() => {'id': id, 'data': data};

  DateTime? get monthDate => _extractMonthDate();

  String get rawLabel => _extractLabel();

  ArchiveSummary get summary => _extractSummary();

  String _extractLabel() {
    final explicit = _pickStr(data, [
      'label',
      'month_label',
      'monthLabel',
      'title',
      'name',
    ]);
    if (explicit.isNotEmpty) return explicit;

    final monthRaw =
        data['month'] ??
        data['month_key'] ??
        data['monthKey'] ??
        data['month_start'] ??
        data['monthStart'] ??
        data['date'];
    final parsed = _parseDate(monthRaw);
    if (parsed != null) {
      return _monthKey(parsed);
    }

    if (id.trim().isNotEmpty) return id.trim();
    return '---';
  }

  DateTime? _extractMonthDate() {
    final monthRaw =
        data['month'] ??
        data['month_key'] ??
        data['monthKey'] ??
        data['month_start'] ??
        data['monthStart'] ??
        data['date'] ??
        data['start'];
    final parsed = _parseDate(monthRaw);
    if (parsed != null) return DateTime(parsed.year, parsed.month, 1);

    final year = _numFrom(data['year']);
    final month = _numFrom(data['monthNumber'] ?? data['month']);
    if (year != null && month != null) {
      return DateTime(year.toInt(), max(1, min(12, month.toInt())), 1);
    }

    final idParsed = _parseMonthKey(id);
    if (idParsed != null) return idParsed;

    return null;
  }

  ArchiveSummary _extractSummary() {
    final summarySource = _pickMap(data, ['summary', 'kpis', 'totals']) ?? data;

    final sales = _numFromAny(summarySource, [
      'sales',
      'total_sales',
      'sales_total',
      'totalSales',
      'salesTotal',
    ]);
    final profit = _numFromAny(summarySource, [
      'profit',
      'profit_total',
      'total_profit',
      'profitTotal',
    ]);
    final cost = _numFromAny(summarySource, [
      'cost',
      'total_cost',
      'cost_total',
      'totalCost',
    ]);
    final expenses = _numFromAny(summarySource, [
      'expenses',
      'total_expenses',
      'expenses_total',
    ]);
    final grams = _numFromAny(summarySource, [
      'grams',
      'total_grams',
      'grams_total',
      'beans_grams',
      'coffee_grams',
    ]);
    final drinks = _numFromAny(summarySource, [
      'drinks',
      'cups',
      'drinks_count',
      'cups_count',
    ]);
    final snacks = _numFromAny(summarySource, [
      'snacks',
      'units',
      'snacks_count',
      'extras',
    ]);

    return ArchiveSummary(
      sales: sales,
      profit: profit,
      cost: cost,
      expenses: expenses,
      grams: grams,
      drinks: drinks?.round(),
      snacks: snacks?.round(),
    );
  }
}

Map<String, dynamic>? _pickMap(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value is Map) return value.cast<String, dynamic>();
  }
  return null;
}

String _pickStr(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value == null) continue;
    final str = value.toString().trim();
    if (str.isNotEmpty) return str;
  }
  return '';
}

String _monthKey(DateTime date) {
  final m = date.month.toString().padLeft(2, '0');
  return '${date.year}-$m';
}

DateTime? _parseMonthKey(String value) {
  final trimmed = value.trim();
  final match = RegExp(r'^(\d{4})-(\d{2})').firstMatch(trimmed);
  if (match == null) return null;
  final year = int.tryParse(match.group(1) ?? '');
  final month = int.tryParse(match.group(2) ?? '');
  if (year == null || month == null) return null;
  return DateTime(year, month, 1);
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final parsed = DateTime.tryParse(trimmed);
    if (parsed != null) return parsed;
    final monthKey = _parseMonthKey(trimmed);
    if (monthKey != null) return monthKey;
    return null;
  }
  if (value is num) {
    final ms = value.toInt();
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: false);
  }
  try {
    // Firestore Timestamp has toDate
    // ignore: avoid_dynamic_calls
    if (value.toDate != null) {
      // ignore: avoid_dynamic_calls
      final dt = value.toDate();
      if (dt is DateTime) return dt;
    }
  } catch (_) {}
  return null;
}

double? _numFromAny(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    if (!data.containsKey(key)) continue;
    final val = _numFrom(data[key]);
    if (val != null) return val;
  }
  return null;
}

double? _numFrom(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  final str = value.toString().trim().replaceAll(',', '.');
  if (str.isEmpty) return null;
  return double.tryParse(str);
}
